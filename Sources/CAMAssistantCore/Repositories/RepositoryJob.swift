import Foundation
import Darwin

public enum RepositoryJobStatus: String, Codable, Equatable, Sendable {
    case pending
    case running
    case cancelled
    case failed
    case completed
}

public struct RepositoryJobRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let sourceID: UUID?
    public let canonicalPath: String
    public let status: RepositoryJobStatus
    public let attempts: Int
    public let maxAttempts: Int
    public let snapshotCommit: String?
    public let capturedSourceCount: Int?
    public let errorCode: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        sourceID: UUID?,
        canonicalPath: String,
        status: RepositoryJobStatus,
        attempts: Int,
        maxAttempts: Int,
        snapshotCommit: String?,
        capturedSourceCount: Int?,
        errorCode: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.sourceID = sourceID
        self.canonicalPath = canonicalPath
        self.status = status
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.snapshotCommit = snapshotCommit
        self.capturedSourceCount = capturedSourceCount
        self.errorCode = errorCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum RepositoryJobAvailableAction: Equatable, Sendable {
    case cancel
    case resume
}

/// A status-only native display projection. Raw errors and source text remain
/// outside the UI contract.
public struct RepositoryJobPresentation: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let canonicalPath: String
    public let statusLabel: String
    public let attemptLabel: String
    public let resultLabel: String?
    public let failureLabel: String?
    public let availableAction: RepositoryJobAvailableAction?

    public init(record: RepositoryJobRecord) {
        id = record.id
        canonicalPath = record.canonicalPath
        statusLabel = switch record.status {
        case .pending:
            "Pending local indexing"
        case .running:
            "Indexing locally"
        case .cancelled:
            "Cancelled"
        case .failed:
            "Failed"
        case .completed:
            "Completed"
        }
        attemptLabel =
            "\(record.attempts) of \(record.maxAttempts) "
            + (record.maxAttempts == 1 ? "attempt" : "attempts")
        if record.status == .completed,
           let commit = record.snapshotCommit,
           let count = record.capturedSourceCount {
            resultLabel =
                "Commit \(commit.prefix(12)) · \(count) local "
                + (count == 1 ? "source" : "sources")
        } else {
            resultLabel = nil
        }
        failureLabel = record.status == .failed
            ? Self.failureLabel(for: record.errorCode)
            : nil
        availableAction = switch record.status {
        case .pending, .running:
            .cancel
        case .cancelled, .failed:
            record.attempts < record.maxAttempts ? .resume : nil
        case .completed:
            nil
        }
    }

    private static func failureLabel(for code: String?) -> String {
        switch code {
        case "interrupted":
            "Interrupted by app restart"
        case "ingestion_failed":
            "Local source extraction failed"
        case "not_git_repository":
            "The selected path is not a Git repository"
        case "git_read_failed":
            "Committed Git evidence could not be read"
        case "invalid_snapshot_path":
            "The recorded repository path was invalid"
        default:
            "Local repository indexing failed"
        }
    }
}

public enum RepositoryJobTransitionError: Error, Equatable {
    case invalidCanonicalPath
    case invalidAttemptLimit
    case invalidErrorCode
    case invalidCapturedSourceCount
    case jobNotFound(UUID)
    case corruptRecord
    case invalidTransition(
        from: RepositoryJobStatus,
        to: RepositoryJobStatus
    )
    case attemptLimitReached(UUID)
}

public enum RepositoryJobLeaseError: Error, Equatable {
    case directoryCreationFailed
    case openFailed
    case lockFailed
}

/// An operating-system lease for one repository job. `flock` is released by
/// the kernel when a process exits, so restart recovery cannot invalidate work
/// still owned by another live app process.
public final class RepositoryJobLease: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32?

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    public static func acquire(
        databaseURL: URL,
        jobID: UUID
    ) throws -> RepositoryJobLease? {
        let directory = databaseURL.deletingLastPathComponent()
            .appending(path: "repository-job-leases", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw RepositoryJobLeaseError.directoryCreationFailed
        }
        let url = directory.appending(path: "\(jobID.uuidString).lock")
        let descriptor = Darwin.open(
            url.path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else {
            throw RepositoryJobLeaseError.openFailed
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            Darwin.close(descriptor)
            if lockError == EWOULDBLOCK {
                return nil
            }
            throw RepositoryJobLeaseError.lockFailed
        }
        return RepositoryJobLease(descriptor: descriptor)
    }

    public func release() {
        lock.lock()
        defer { lock.unlock() }
        guard let descriptor else { return }
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
        self.descriptor = nil
    }

    deinit {
        release()
    }
}

/// Persists status-only repository operation state. Repository source bytes,
/// exception descriptions, prompts, and model output never enter this table.
public final class RepositoryJobStore {
    private let store: SQLiteStore
    private let databaseURL: URL

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        store = try SQLiteStore(databaseURL: databaseURL)
    }

    public func create(
        id: UUID = UUID(),
        sourceID: UUID?,
        canonicalPath: String,
        maxAttempts: Int = 3,
        createdAt: Date = Date()
    ) throws -> RepositoryJobRecord {
        let trimmed = canonicalPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            throw RepositoryJobTransitionError.invalidCanonicalPath
        }
        guard maxAttempts > 0 else {
            throw RepositoryJobTransitionError.invalidAttemptLimit
        }
        let canonical = URL(filePath: trimmed).standardizedFileURL.path
        try store.execute(
            """
            INSERT INTO repository_jobs(
                job_id, source_id, canonical_path, status, attempts,
                max_attempts, snapshot_commit, captured_source_count,
                error_code, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?)
            """,
            bindings: [
                id.uuidString,
                sourceID?.uuidString,
                canonical,
                RepositoryJobStatus.pending.rawValue,
                "0",
                String(maxAttempts),
                String(createdAt.timeIntervalSince1970),
                String(createdAt.timeIntervalSince1970),
            ]
        )
        return try requiredRecord(id)
    }

    public func record(id: UUID) throws -> RepositoryJobRecord? {
        let rows = try store.query(
            """
            SELECT job_id, source_id, canonical_path, status, attempts,
                   max_attempts, snapshot_commit, captured_source_count,
                   error_code, created_at, updated_at
            FROM repository_jobs
            WHERE job_id = ?
            LIMIT 1
            """,
            bindings: [id.uuidString]
        )
        return try rows.first.map(Self.decode)
    }

    public func all() throws -> [RepositoryJobRecord] {
        try store.query(
            """
            SELECT job_id, source_id, canonical_path, status, attempts,
                   max_attempts, snapshot_commit, captured_source_count,
                   error_code, created_at, updated_at
            FROM repository_jobs
            ORDER BY created_at ASC, job_id ASC
            """
        ).map(Self.decode)
    }

    @discardableResult
    public func start(
        _ id: UUID,
        at updatedAt: Date = Date()
    ) throws -> RepositoryJobRecord {
        try store.transaction {
            let current = try requiredRecord(id)
            guard [.pending, .cancelled, .failed].contains(current.status) else {
                throw RepositoryJobTransitionError.invalidTransition(
                    from: current.status,
                    to: .running
                )
            }
            guard current.attempts < current.maxAttempts else {
                throw RepositoryJobTransitionError.attemptLimitReached(id)
            }
            try store.execute(
                """
                UPDATE repository_jobs
                SET status = ?, attempts = ?, snapshot_commit = NULL,
                    captured_source_count = NULL, error_code = NULL,
                    updated_at = ?
                WHERE job_id = ?
                """,
                bindings: [
                    RepositoryJobStatus.running.rawValue,
                    String(current.attempts + 1),
                    String(updatedAt.timeIntervalSince1970),
                    id.uuidString,
                ]
            )
            return try requiredRecord(id)
        }
    }

    @discardableResult
    public func cancel(
        _ id: UUID,
        at updatedAt: Date = Date()
    ) throws -> RepositoryJobRecord {
        try transition(
            id,
            allowed: [.pending, .running],
            to: .cancelled,
            errorCode: nil,
            updatedAt: updatedAt
        )
    }

    @discardableResult
    public func fail(
        _ id: UUID,
        errorCode: String,
        at updatedAt: Date = Date()
    ) throws -> RepositoryJobRecord {
        let code = errorCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            throw RepositoryJobTransitionError.invalidErrorCode
        }
        return try transition(
            id,
            allowed: [.running],
            to: .failed,
            errorCode: code,
            updatedAt: updatedAt
        )
    }

    @discardableResult
    public func complete(
        _ id: UUID,
        snapshotCommit: String,
        capturedSourceCount: Int,
        at updatedAt: Date = Date()
    ) throws -> RepositoryJobRecord {
        guard capturedSourceCount >= 0 else {
            throw RepositoryJobTransitionError.invalidCapturedSourceCount
        }
        return try store.transaction {
            let current = try requiredRecord(id)
            guard current.status == .running else {
                throw RepositoryJobTransitionError.invalidTransition(
                    from: current.status,
                    to: .completed
                )
            }
            try store.execute(
                """
                UPDATE repository_jobs
                SET status = ?, snapshot_commit = ?,
                    captured_source_count = ?, error_code = NULL,
                    updated_at = ?
                WHERE job_id = ?
                """,
                bindings: [
                    RepositoryJobStatus.completed.rawValue,
                    snapshotCommit,
                    String(capturedSourceCount),
                    String(updatedAt.timeIntervalSince1970),
                    id.uuidString,
                ]
            )
            return try requiredRecord(id)
        }
    }

    @discardableResult
    public func recoverInterrupted(
        at updatedAt: Date = Date()
    ) throws -> [RepositoryJobRecord] {
        try store.transaction {
            let interrupted = try all().filter { $0.status == .running }
            var recovered: [RepositoryJobRecord] = []
            for record in interrupted {
                guard let lease = try RepositoryJobLease.acquire(
                    databaseURL: databaseURL,
                    jobID: record.id
                ) else {
                    continue
                }
                defer { lease.release() }
                try store.execute(
                    """
                    UPDATE repository_jobs
                    SET status = ?, error_code = ?, updated_at = ?
                    WHERE job_id = ?
                    """,
                    bindings: [
                        RepositoryJobStatus.failed.rawValue,
                        "interrupted",
                        String(updatedAt.timeIntervalSince1970),
                        record.id.uuidString,
                    ]
                )
                recovered.append(try requiredRecord(record.id))
            }
            return recovered
        }
    }

    public func close() throws {
        try store.close()
    }

    private func transition(
        _ id: UUID,
        allowed: Set<RepositoryJobStatus>,
        to next: RepositoryJobStatus,
        errorCode: String?,
        updatedAt: Date
    ) throws -> RepositoryJobRecord {
        try store.transaction {
            let current = try requiredRecord(id)
            guard allowed.contains(current.status) else {
                throw RepositoryJobTransitionError.invalidTransition(
                    from: current.status,
                    to: next
                )
            }
            try store.execute(
                """
                UPDATE repository_jobs
                SET status = ?, error_code = ?, updated_at = ?
                WHERE job_id = ?
                """,
                bindings: [
                    next.rawValue,
                    errorCode,
                    String(updatedAt.timeIntervalSince1970),
                    id.uuidString,
                ]
            )
            return try requiredRecord(id)
        }
    }

    private func requiredRecord(_ id: UUID) throws -> RepositoryJobRecord {
        guard let record = try record(id: id) else {
            throw RepositoryJobTransitionError.jobNotFound(id)
        }
        return record
    }

    private static func decode(
        _ row: [String?]
    ) throws -> RepositoryJobRecord {
        guard row.count == 11,
              let idText = row[0],
              let id = UUID(uuidString: idText),
              let canonicalPath = row[2],
              let statusText = row[3],
              let status = RepositoryJobStatus(rawValue: statusText),
              let attemptsText = row[4],
              let attempts = Int(attemptsText),
              let maxAttemptsText = row[5],
              let maxAttempts = Int(maxAttemptsText),
              let createdText = row[9],
              let createdSeconds = Double(createdText),
              let updatedText = row[10],
              let updatedSeconds = Double(updatedText) else {
            throw RepositoryJobTransitionError.corruptRecord
        }
        let sourceID: UUID?
        if let sourceText = row[1] {
            guard let decoded = UUID(uuidString: sourceText) else {
                throw RepositoryJobTransitionError.corruptRecord
            }
            sourceID = decoded
        } else {
            sourceID = nil
        }
        let capturedSourceCount: Int?
        if let countText = row[7] {
            guard let decoded = Int(countText) else {
                throw RepositoryJobTransitionError.corruptRecord
            }
            capturedSourceCount = decoded
        } else {
            capturedSourceCount = nil
        }
        return RepositoryJobRecord(
            id: id,
            sourceID: sourceID,
            canonicalPath: canonicalPath,
            status: status,
            attempts: attempts,
            maxAttempts: maxAttempts,
            snapshotCommit: row[6],
            capturedSourceCount: capturedSourceCount,
            errorCode: row[8],
            createdAt: Date(timeIntervalSince1970: createdSeconds),
            updatedAt: Date(timeIntervalSince1970: updatedSeconds)
        )
    }
}

public enum RepositoryJobRunnerError: Error, Equatable {
    case rootMismatch
    case alreadyRunning
}

/// Runs one explicit local repository indexing attempt under a durable job.
/// The operation remains read-only with respect to the selected repository;
/// only local vault, derived-index, snapshot, and status records may change.
public struct RepositoryJobRunner: Sendable {
    public static func run(
        jobID: UUID,
        root: URL,
        databaseURL: URL,
        contentRootURL: URL,
        cancellation: RepositoryIndexCancellation,
        capturedAt: Date = Date(),
        beforeSnapshotSave: @Sendable () -> Void = {}
    ) throws -> RepositoryIncrementalIndexResult {
        let jobStore = try RepositoryJobStore(databaseURL: databaseURL)
        let current = try jobStore.record(id: jobID)
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard current?.canonicalPath == canonicalRoot.path else {
            throw RepositoryJobRunnerError.rootMismatch
        }
        guard let lease = try RepositoryJobLease.acquire(
            databaseURL: databaseURL,
            jobID: jobID
        ) else {
            throw RepositoryJobRunnerError.alreadyRunning
        }
        defer { lease.release() }
        _ = try jobStore.start(jobID, at: capturedAt)

        do {
            let result = try RepositoryLocalIndexOperation.index(
                root: canonicalRoot,
                databaseURL: databaseURL,
                contentRootURL: contentRootURL,
                capturedAt: capturedAt,
                shouldCancel: { cancellation.isCancelled },
                beforeSnapshotCommit: cancellation.beginTerminalCommit,
                beforeSnapshotSave: beforeSnapshotSave
            )
            _ = try jobStore.complete(
                jobID,
                snapshotCommit: result.snapshot.commit,
                capturedSourceCount: result.capturedSourceIDs.count
            )
            return result
        } catch RepositoryIncrementalIndexError.cancelled {
            _ = try jobStore.cancel(jobID)
            throw RepositoryIncrementalIndexError.cancelled
        } catch {
            _ = try jobStore.fail(
                jobID,
                errorCode: Self.errorCode(for: error)
            )
            throw error
        }
    }

    private static func errorCode(for error: Error) -> String {
        switch error {
        case RepositoryIncrementalIndexError.ingestionFailed:
            "ingestion_failed"
        case RepositoryModuleError.notGitRepository:
            "not_git_repository"
        case RepositoryModuleError.gitReadFailed:
            "git_read_failed"
        case RepositoryModuleError.invalidSnapshotPath:
            "invalid_snapshot_path"
        default:
            "operation_failed"
        }
    }
}

public enum RepositorySourceLifecycleStatus:
    String,
    Codable,
    Equatable,
    Sendable
{
    case active
    case removed
}

public struct RepositorySourceLifecycleRecord: Equatable, Sendable {
    public let sourceID: UUID
    public let canonicalPath: String
    public let status: RepositorySourceLifecycleStatus
    public let updatedAt: Date
}

public protocol RepositorySourceLifecycleWriting {
    @discardableResult
    func record(
        _ source: RepositorySource,
        status: RepositorySourceLifecycleStatus,
        at updatedAt: Date
    ) throws -> RepositorySourceLifecycleRecord

    func all() throws -> [RepositorySourceLifecycleRecord]
}

public enum RepositorySourceLifecycleError: Error, Equatable {
    case corruptRecord
}

/// Retains only the saved-selection lifecycle. Removing a selection never
/// cascades into vault bytes, provenance, snapshots, jobs, or idea evidence.
public final class RepositorySourceLifecycleStore:
    RepositorySourceLifecycleWriting
{
    private let store: SQLiteStore

    public init(databaseURL: URL) throws {
        store = try SQLiteStore(databaseURL: databaseURL)
    }

    @discardableResult
    public func record(
        _ source: RepositorySource,
        status: RepositorySourceLifecycleStatus,
        at updatedAt: Date = Date()
    ) throws -> RepositorySourceLifecycleRecord {
        try store.execute(
            """
            INSERT INTO repository_source_lifecycle(
                source_id, canonical_path, status, updated_at
            ) VALUES (?, ?, ?, ?)
            ON CONFLICT(source_id) DO UPDATE SET
                canonical_path = excluded.canonical_path,
                status = excluded.status,
                updated_at = excluded.updated_at
            """,
            bindings: [
                source.id.uuidString,
                source.canonicalPath,
                status.rawValue,
                String(updatedAt.timeIntervalSince1970),
            ]
        )
        guard let saved = try record(sourceID: source.id) else {
            throw RepositorySourceLifecycleError.corruptRecord
        }
        return saved
    }

    public func record(
        sourceID: UUID
    ) throws -> RepositorySourceLifecycleRecord? {
        let rows = try store.query(
            """
            SELECT source_id, canonical_path, status, updated_at
            FROM repository_source_lifecycle
            WHERE source_id = ?
            LIMIT 1
            """,
            bindings: [sourceID.uuidString]
        )
        return try rows.first.map(Self.decode)
    }

    public func all() throws -> [RepositorySourceLifecycleRecord] {
        try store.query(
            """
            SELECT source_id, canonical_path, status, updated_at
            FROM repository_source_lifecycle
            ORDER BY updated_at ASC, source_id ASC
            """
        ).map(Self.decode)
    }

    public func close() throws {
        try store.close()
    }

    private static func decode(
        _ row: [String?]
    ) throws -> RepositorySourceLifecycleRecord {
        guard row.count == 4,
              let sourceIDText = row[0],
              let sourceID = UUID(uuidString: sourceIDText),
              let canonicalPath = row[1],
              let statusText = row[2],
              let status = RepositorySourceLifecycleStatus(
                  rawValue: statusText
              ),
              let updatedText = row[3],
              let updatedSeconds = Double(updatedText) else {
            throw RepositorySourceLifecycleError.corruptRecord
        }
        return RepositorySourceLifecycleRecord(
            sourceID: sourceID,
            canonicalPath: canonicalPath,
            status: status,
            updatedAt: Date(timeIntervalSince1970: updatedSeconds)
        )
    }
}
