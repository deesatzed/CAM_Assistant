import Foundation

public enum ResearchAcquisitionJobStatus:
    String,
    Codable,
    Equatable,
    Sendable
{
    case pending
    case running
    case cancelled
    case failed
    case completed
}

public struct ResearchAcquisitionJobRecord:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let schemaVersion: Int
    public let id: UUID
    public let request: ResearchAcquisitionRequest
    public let status: ResearchAcquisitionJobStatus
    public let attempts: Int
    public let maxAttempts: Int
    public let cardID: UUID?
    public let approvalID: UUID?
    public let approvalConsumedAt: Date?
    public let startedAt: Date?
    public let completedAt: Date?
    public let receipt: ResearchSourceReceipt?
    public let errorCode: String?
    public let createdAt: Date
    public let updatedAt: Date

    init(
        id: UUID,
        request: ResearchAcquisitionRequest,
        status: ResearchAcquisitionJobStatus,
        attempts: Int,
        maxAttempts: Int,
        cardID: UUID?,
        approvalID: UUID?,
        approvalConsumedAt: Date?,
        startedAt: Date?,
        completedAt: Date?,
        receipt: ResearchSourceReceipt?,
        errorCode: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        schemaVersion = 1
        self.id = id
        self.request = request
        self.status = status
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.cardID = cardID
        self.approvalID = approvalID
        self.approvalConsumedAt = approvalConsumedAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.receipt = receipt
        self.errorCode = errorCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ResearchAcquisitionJobStoreError: Error, Equatable {
    case jobAlreadyExists(UUID)
    case jobNotFound(UUID)
    case invalidAttemptLimit
    case invalidErrorCode
    case corruptRecord
    case requestBindingMismatch
    case receiptBindingMismatch
    case invalidTransition(
        from: ResearchAcquisitionJobStatus,
        to: ResearchAcquisitionJobStatus
    )
    case attemptLimitReached(UUID)
}

/// Durable, status-bounded acquisition state. Source bytes and response text
/// remain in the content-addressed vault, never in this job table.
public final class ResearchAcquisitionJobStore {
    private let store: SQLiteStore
    private let lock = NSRecursiveLock()

    public init(databaseURL: URL) throws {
        store = try SQLiteStore(databaseURL: databaseURL)
    }

    public func create(
        id: UUID = UUID(),
        request: ResearchAcquisitionRequest,
        maxAttempts: Int = 3,
        createdAt: Date = Date()
    ) throws -> ResearchAcquisitionJobRecord {
        lock.lock()
        defer { lock.unlock() }
        guard maxAttempts > 0 else {
            throw ResearchAcquisitionJobStoreError.invalidAttemptLimit
        }
        guard try record(id: id) == nil else {
            throw ResearchAcquisitionJobStoreError.jobAlreadyExists(id)
        }
        let record = ResearchAcquisitionJobRecord(
            id: id,
            request: request,
            status: .pending,
            attempts: 0,
            maxAttempts: maxAttempts,
            cardID: nil,
            approvalID: nil,
            approvalConsumedAt: nil,
            startedAt: nil,
            completedAt: nil,
            receipt: nil,
            errorCode: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        try insert(record)
        return record
    }

    public func record(id: UUID) throws -> ResearchAcquisitionJobRecord? {
        lock.lock()
        defer { lock.unlock() }
        let rows = try store.query(
            """
            SELECT job_id, status, record_json, updated_at
            FROM research_acquisition_jobs
            WHERE job_id = ?
            LIMIT 1
            """,
            bindings: [id.uuidString]
        )
        return try rows.first.map(Self.decode)
    }

    public func all() throws -> [ResearchAcquisitionJobRecord] {
        lock.lock()
        defer { lock.unlock() }
        return try store.query(
            """
            SELECT job_id, status, record_json, updated_at
            FROM research_acquisition_jobs
            ORDER BY created_at ASC, job_id ASC
            """
        ).map(Self.decode)
    }

    public func requestForResume(
        _ id: UUID
    ) throws -> ResearchAcquisitionRequest {
        lock.lock()
        defer { lock.unlock() }
        let current = try requiredRecord(id)
        guard current.status == .cancelled || current.status == .failed else {
            throw ResearchAcquisitionJobStoreError.invalidTransition(
                from: current.status,
                to: .pending
            )
        }
        guard current.attempts < current.maxAttempts else {
            throw ResearchAcquisitionJobStoreError.attemptLimitReached(id)
        }
        return try ResearchAcquisitionRequest(
            runID: current.request.runID,
            query: current.request.query,
            target: current.request.target,
            stateVersion: current.request.stateVersion + 1,
            maxBytes: current.request.maxBytes
        )
    }

    @discardableResult
    public func start(
        _ id: UUID,
        approvedRequest: ResearchAcquisitionRequest,
        cardID: UUID,
        approvalID: UUID,
        approvalConsumedAt: Date,
        at updatedAt: Date = Date()
    ) throws -> ResearchAcquisitionJobRecord {
        lock.lock()
        defer { lock.unlock() }
        return try store.transaction {
            let current = try requiredRecord(id)
            guard current.status == .pending
                    || current.status == .cancelled
                    || current.status == .failed else {
                throw ResearchAcquisitionJobStoreError.invalidTransition(
                    from: current.status,
                    to: .running
                )
            }
            guard current.attempts < current.maxAttempts else {
                throw ResearchAcquisitionJobStoreError.attemptLimitReached(id)
            }
            try validateBinding(
                current: current,
                approved: approvedRequest
            )
            let candidate = ResearchAcquisitionJobRecord(
                id: current.id,
                request: approvedRequest,
                status: .running,
                attempts: current.attempts + 1,
                maxAttempts: current.maxAttempts,
                cardID: cardID,
                approvalID: approvalID,
                approvalConsumedAt: approvalConsumedAt,
                startedAt: updatedAt,
                completedAt: nil,
                receipt: nil,
                errorCode: nil,
                createdAt: current.createdAt,
                updatedAt: updatedAt
            )
            try update(candidate)
            return candidate
        }
    }

    @discardableResult
    public func cancel(
        _ id: UUID,
        at updatedAt: Date = Date()
    ) throws -> ResearchAcquisitionJobRecord {
        try transition(
            id,
            allowed: [.pending, .running, .cancelled],
            to: .cancelled,
            errorCode: nil,
            at: updatedAt
        )
    }

    @discardableResult
    public func fail(
        _ id: UUID,
        errorCode: String,
        at updatedAt: Date = Date()
    ) throws -> ResearchAcquisitionJobRecord {
        guard Self.isSafeErrorCode(errorCode) else {
            throw ResearchAcquisitionJobStoreError.invalidErrorCode
        }
        return try transition(
            id,
            allowed: [.running],
            to: .failed,
            errorCode: errorCode,
            at: updatedAt
        )
    }

    @discardableResult
    public func complete(
        _ id: UUID,
        receipt: ResearchSourceReceipt,
        at updatedAt: Date = Date()
    ) throws -> ResearchAcquisitionJobRecord {
        lock.lock()
        defer { lock.unlock() }
        return try store.transaction {
            let current = try requiredRecord(id)
            guard current.status == .running else {
                throw ResearchAcquisitionJobStoreError.invalidTransition(
                    from: current.status,
                    to: .completed
                )
            }
            guard receipt.acquisitionID == id,
                  receipt.requestedURL
                    == current.request.target.absoluteString,
                  receipt.route == current.request.route,
                  receipt.toolID == current.request.toolID,
                  receipt.maximumCostUSD
                    == current.request.maximumCostUSD,
                  receipt.byteCount <= current.request.maxBytes else {
                throw ResearchAcquisitionJobStoreError.receiptBindingMismatch
            }
            let candidate = ResearchAcquisitionJobRecord(
                id: current.id,
                request: current.request,
                status: .completed,
                attempts: current.attempts,
                maxAttempts: current.maxAttempts,
                cardID: current.cardID,
                approvalID: current.approvalID,
                approvalConsumedAt: current.approvalConsumedAt,
                startedAt: current.startedAt,
                completedAt: receipt.completedAt,
                receipt: receipt,
                errorCode: nil,
                createdAt: current.createdAt,
                updatedAt: updatedAt
            )
            try update(candidate)
            return candidate
        }
    }

    @discardableResult
    public func recoverInterrupted(
        at updatedAt: Date = Date()
    ) throws -> [ResearchAcquisitionJobRecord] {
        lock.lock()
        defer { lock.unlock() }
        return try store.transaction {
            let interrupted = try all().filter { $0.status == .running }
            var recovered: [ResearchAcquisitionJobRecord] = []
            for current in interrupted {
                let candidate = ResearchAcquisitionJobRecord(
                    id: current.id,
                    request: current.request,
                    status: .failed,
                    attempts: current.attempts,
                    maxAttempts: current.maxAttempts,
                    cardID: current.cardID,
                    approvalID: current.approvalID,
                    approvalConsumedAt: current.approvalConsumedAt,
                    startedAt: current.startedAt,
                    completedAt: nil,
                    receipt: nil,
                    errorCode: "interrupted",
                    createdAt: current.createdAt,
                    updatedAt: updatedAt
                )
                try update(candidate)
                recovered.append(candidate)
            }
            return recovered
        }
    }

    private func transition(
        _ id: UUID,
        allowed: Set<ResearchAcquisitionJobStatus>,
        to status: ResearchAcquisitionJobStatus,
        errorCode: String?,
        at updatedAt: Date
    ) throws -> ResearchAcquisitionJobRecord {
        lock.lock()
        defer { lock.unlock() }
        return try store.transaction {
            let current = try requiredRecord(id)
            guard allowed.contains(current.status) else {
                throw ResearchAcquisitionJobStoreError.invalidTransition(
                    from: current.status,
                    to: status
                )
            }
            let candidate = ResearchAcquisitionJobRecord(
                id: current.id,
                request: current.request,
                status: status,
                attempts: current.attempts,
                maxAttempts: current.maxAttempts,
                cardID: current.cardID,
                approvalID: current.approvalID,
                approvalConsumedAt: current.approvalConsumedAt,
                startedAt: current.startedAt,
                completedAt: nil,
                receipt: nil,
                errorCode: errorCode,
                createdAt: current.createdAt,
                updatedAt: updatedAt
            )
            try update(candidate)
            return candidate
        }
    }

    private func validateBinding(
        current: ResearchAcquisitionJobRecord,
        approved: ResearchAcquisitionRequest
    ) throws {
        let expectedStateVersion: Int
        switch current.status {
        case .pending:
            expectedStateVersion = current.request.stateVersion
        case .cancelled, .failed:
            expectedStateVersion = current.request.stateVersion + 1
        case .running, .completed:
            throw ResearchAcquisitionJobStoreError.invalidTransition(
                from: current.status,
                to: .running
            )
        }
        guard approved.runID == current.request.runID,
              approved.query == current.request.query,
              approved.target == current.request.target,
              approved.maxBytes == current.request.maxBytes,
              approved.maximumCostUSD
                == current.request.maximumCostUSD,
              approved.route == current.request.route,
              approved.toolID == current.request.toolID,
              approved.stateVersion == expectedStateVersion else {
            throw ResearchAcquisitionJobStoreError.requestBindingMismatch
        }
    }

    private func requiredRecord(
        _ id: UUID
    ) throws -> ResearchAcquisitionJobRecord {
        guard let record = try record(id: id) else {
            throw ResearchAcquisitionJobStoreError.jobNotFound(id)
        }
        return record
    }

    private func insert(_ record: ResearchAcquisitionJobRecord) throws {
        try store.execute(
            """
            INSERT INTO research_acquisition_jobs(
                job_id, status, record_json, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                record.id.uuidString,
                record.status.rawValue,
                try encode(record),
                String(record.createdAt.timeIntervalSince1970),
                String(record.updatedAt.timeIntervalSince1970),
            ]
        )
    }

    private func update(_ record: ResearchAcquisitionJobRecord) throws {
        try store.execute(
            """
            UPDATE research_acquisition_jobs
            SET status = ?, record_json = ?, updated_at = ?
            WHERE job_id = ?
            """,
            bindings: [
                record.status.rawValue,
                try encode(record),
                String(record.updatedAt.timeIntervalSince1970),
                record.id.uuidString,
            ]
        )
    }

    private func encode(_ record: ResearchAcquisitionJobRecord) throws
        -> String
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(
            decoding: try encoder.encode(record),
            as: UTF8.self
        )
    }

    private static func decode(
        _ row: [String?]
    ) throws -> ResearchAcquisitionJobRecord {
        guard row.count == 4,
              let idText = row[0],
              let id = UUID(uuidString: idText),
              let statusText = row[1],
              let status = ResearchAcquisitionJobStatus(
                rawValue: statusText
              ),
              let recordText = row[2],
              let updatedText = row[3],
              let updatedInterval = TimeInterval(updatedText),
              let record = try? JSONDecoder().decode(
                ResearchAcquisitionJobRecord.self,
                from: Data(recordText.utf8)
              ),
              record.schemaVersion == 1,
              record.id == id,
              record.status == status,
              record.updatedAt.timeIntervalSince1970 == updatedInterval,
              record.maxAttempts > 0,
              record.attempts >= 0,
              record.attempts <= record.maxAttempts,
              Self.validRequest(record.request),
              Self.validShape(record) else {
            throw ResearchAcquisitionJobStoreError.corruptRecord
        }
        return record
    }

    private static func validRequest(
        _ request: ResearchAcquisitionRequest
    ) -> Bool {
        guard let rebuilt = try? ResearchAcquisitionRequest(
            runID: request.runID,
            query: request.query,
            target: request.target,
            stateVersion: request.stateVersion,
            maxBytes: request.maxBytes
        ) else {
            return false
        }
        return rebuilt == request
    }

    private static func validShape(
        _ record: ResearchAcquisitionJobRecord
    ) -> Bool {
        switch record.status {
        case .pending:
            return record.attempts == 0
                && record.cardID == nil
                && record.approvalID == nil
                && record.receipt == nil
                && record.errorCode == nil
        case .running:
            return record.attempts > 0
                && record.cardID != nil
                && record.approvalID != nil
                && record.approvalConsumedAt != nil
                && record.startedAt != nil
                && record.receipt == nil
                && record.errorCode == nil
        case .cancelled:
            return record.receipt == nil && record.errorCode == nil
        case .failed:
            return record.receipt == nil
                && record.errorCode.map(Self.isSafeErrorCode) == true
        case .completed:
            return record.receipt != nil
                && record.completedAt != nil
                && record.errorCode == nil
        }
    }

    private static func isSafeErrorCode(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 64
            && value.unicodeScalars.allSatisfy {
                (48...57).contains($0.value)
                    || (97...122).contains($0.value)
                    || $0 == "_"
            }
    }
}
