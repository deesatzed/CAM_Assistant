import Foundation

public enum IngestJobStatus: String, Codable, Sendable {
    case pending
    case retrying
    case completed
    case failed
    case cancelled
}

public struct IngestResult: Equatable, Sendable {
    public let sourceID: ContentID
    public let status: IngestJobStatus
}

public struct IngestJobRecord: Equatable, Sendable, Identifiable {
    public var id: String { sourceID.rawValue }
    public let sourceID: ContentID
    public let status: IngestJobStatus
    public let attempts: Int
    public let maxAttempts: Int
    public let sourceName: String
    public let contentType: String
    public let createdAt: Date
    public let updatedAt: Date
}

public enum SourceLifecycle: String, Codable, Equatable, Sendable {
    case active
    case hidden
}

public enum RawSourcePreviewAvailability: String, Equatable, Sendable {
    case text
    case binaryUnavailable
}

public struct RawSourceInspection: Equatable, Sendable {
    public let sourceID: ContentID
    public let verifiedSHA256: String
    public let byteCount: Int
    public let sourceName: String
    public let contentType: String
    public let lifecycle: SourceLifecycle
    public let previewAvailability: RawSourcePreviewAvailability
    public let preview: String?
    public let isPreviewTruncated: Bool
}

public struct DerivedDocument: Equatable, Sendable {
    public let sourceID: ContentID
    public let text: String
    public let modality: DocumentModality
    public let extractorID: String
    public let capturedAt: Date

    public init(
        sourceID: ContentID,
        text: String,
        modality: DocumentModality,
        extractorID: String,
        capturedAt: Date
    ) {
        self.sourceID = sourceID
        self.text = text
        self.modality = modality
        self.extractorID = extractorID
        self.capturedAt = capturedAt
    }
}

/// Read-only summary for the native Library surface. It contains no source
/// bytes and does not alter ingestion or retention state.
public struct LibraryCaptureRow: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let capturedAt: Date
    public let sourceName: String
    public let contentType: String
    public let originLabel: String

    init(provenance: CaptureProvenance) {
        id = provenance.captureID
        capturedAt = provenance.capturedAt
        sourceName = provenance.sourceName
        contentType = provenance.contentType
        originLabel = switch provenance.origin {
        case .clipboard:
            "Clipboard"
        case let .watchedFolder(path):
            "Watched folder: \(path)"
        case let .repository(canonicalPath, commit):
            "Repository: \(canonicalPath) @ \(commit)"
        case let .research(runID, canonicalURL):
            "Research: \(canonicalURL) · run \(runID)"
        }
    }
}

public struct LibrarySourceRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let passageID: String
    public let preview: String
    public let modalityLabel: String
    public let extractorID: String
    public let capturedAt: Date
    public let captures: [LibraryCaptureRow]
    public let lifecycle: SourceLifecycle

    public var lifecycleActionLabel: String {
        switch lifecycle {
        case .active:
            "Hide from Library & Chat"
        case .hidden:
            "Restore to Library & Chat"
        }
    }

    init(
        document: DerivedDocument,
        provenance: [CaptureProvenance],
        lifecycle: SourceLifecycle = .active
    ) {
        id = document.sourceID.rawValue
        passageID = "\(document.sourceID.rawValue)#0"
        preview = String(document.text.prefix(500))
        modalityLabel = document.modality.rawValue.capitalized
        extractorID = document.extractorID
        capturedAt = document.capturedAt
        captures = provenance.map(LibraryCaptureRow.init)
        self.lifecycle = lifecycle
    }
}

public struct LibraryPresentation: Equatable, Sendable {
    public let documentCount: Int
    public let hiddenCount: Int
    public let modalityCounts: [DocumentModality: Int]
    public let rows: [LibrarySourceRow]
    public let hiddenRows: [LibrarySourceRow]

    public init(documents: [DerivedDocument]) {
        self.init(
            documents: documents,
            hiddenDocuments: [],
            provenanceBySource: [:]
        )
    }

    public init(
        documents: [DerivedDocument],
        hiddenDocuments: [DerivedDocument] = [],
        provenanceBySource: [ContentID: [CaptureProvenance]]
    ) {
        documentCount = documents.count
        hiddenCount = hiddenDocuments.count
        modalityCounts = Dictionary(grouping: documents, by: \.modality)
            .mapValues(\.count)
        rows = documents
            .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
            .map {
                LibrarySourceRow(
                    document: $0,
                    provenance: provenanceBySource[$0.sourceID] ?? [],
                    lifecycle: .active
                )
            }
        hiddenRows = hiddenDocuments
            .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
            .map {
                LibrarySourceRow(
                    document: $0,
                    provenance: provenanceBySource[$0.sourceID] ?? [],
                    lifecycle: .hidden
                )
            }
    }

    public func row(for citation: Citation) -> LibrarySourceRow? {
        rows.first {
            $0.id == citation.sourceID && $0.passageID == citation.passageID
        }
    }
}

public struct CaptureProvenance: Equatable, Sendable {
    public let captureID: UUID
    public let sourceID: ContentID
    public let capturedAt: Date
    public let sourceName: String
    public let contentType: String
    public let origin: CaptureOrigin
}

public struct IngestWarning: Equatable, Sendable {
    public let sourceID: ContentID
    public let attempt: Int
    public let code: String
    public let message: String
}

public enum IngestQueueError: Error, Equatable {
    case sourceNotFound(ContentID)
    case invalidStoredRecord
    case invalidPreviewCharacterLimit(Int)
    case invalidJobTransition(
        sourceID: ContentID,
        from: IngestJobStatus,
        to: IngestJobStatus
    )
}

public final class IngestQueue {
    private struct PendingJob {
        let sourceID: ContentID
        let attempts: Int
        let maxAttempts: Int
        let sourceName: String
        let contentType: String
    }

    private let database: SQLiteStore
    private let contentStore: ContentStore
    private let extractors: ExtractorRegistry
    private let lock = NSRecursiveLock()
    private let maxAttempts = 2

    public init(
        databaseURL: URL,
        contentStore: ContentStore,
        extractors: ExtractorRegistry
    ) throws {
        self.database = try SQLiteStore(databaseURL: databaseURL)
        self.contentStore = contentStore
        self.extractors = extractors
    }

    public func enqueue(_ envelope: CaptureEnvelope) throws -> CaptureReceipt {
        lock.lock()
        defer { lock.unlock() }
        let stored = try contentStore.put(envelope.data)
        let duplicate = !(try database.query(
            "SELECT source_id FROM sources WHERE source_id = ?",
            bindings: [stored.id.rawValue]
        ).isEmpty)

        try database.transaction {
            try database.execute(
                """
                INSERT OR IGNORE INTO sources(
                    source_id, byte_count, created_at, source_name, content_type
                ) VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    stored.id.rawValue,
                    String(stored.byteCount),
                    String(envelope.capturedAt.timeIntervalSince1970),
                    envelope.sourceName,
                    envelope.contentType,
                ]
            )
            try database.execute(
                """
                INSERT OR IGNORE INTO capture_events(
                    capture_id, source_id, captured_at, origin_kind,
                    origin_detail, source_name, content_type
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    envelope.id.uuidString,
                    stored.id.rawValue,
                    String(envelope.capturedAt.timeIntervalSince1970),
                    envelope.origin.storedKind,
                    envelope.origin.storedDetail,
                    envelope.sourceName,
                    envelope.contentType,
                ]
            )
            try database.execute(
                """
                INSERT OR IGNORE INTO ingest_jobs(
                    source_id, status, attempts, max_attempts, created_at, updated_at
                ) VALUES (?, ?, 0, ?, ?, ?)
                """,
                bindings: [
                    stored.id.rawValue,
                    IngestJobStatus.pending.rawValue,
                    String(maxAttempts),
                    String(envelope.capturedAt.timeIntervalSince1970),
                    String(envelope.capturedAt.timeIntervalSince1970),
                ]
            )
        }

        return CaptureReceipt(
            captureID: envelope.id,
            sourceID: stored.id,
            wasDuplicateSource: duplicate
        )
    }

    public func processNext(
        isCancelled: () -> Bool = { false }
    ) throws -> IngestResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let job = try pendingJob() else { return nil }
        return try process(job, isCancelled: isCancelled)
    }

    public func process(
        sourceID: ContentID,
        isCancelled: () -> Bool = { false }
    ) throws -> IngestResult {
        lock.lock()
        defer { lock.unlock() }
        guard let job = try pendingJob(for: sourceID) else {
            guard let status = try jobStatus(for: sourceID) else {
                throw IngestQueueError.sourceNotFound(sourceID)
            }
            throw IngestQueueError.invalidJobTransition(
                sourceID: sourceID,
                from: status,
                to: .completed
            )
        }
        return try process(job, isCancelled: isCancelled)
    }

    private func pendingJob(
        for requestedSourceID: ContentID? = nil
    ) throws -> PendingJob? {
        var statement = """
            SELECT j.source_id, j.attempts, j.max_attempts,
                   s.source_name, s.content_type
            FROM ingest_jobs j
            JOIN sources s ON s.source_id = j.source_id
            WHERE j.status = ?
            """
        var bindings = [IngestJobStatus.pending.rawValue]
        if let requestedSourceID {
            statement += " AND j.source_id = ?"
            bindings.append(requestedSourceID.rawValue)
        }
        statement += """

            ORDER BY j.created_at ASC, j.source_id ASC
            LIMIT 1
            """

        let rows = try database.query(statement, bindings: bindings)
        guard let row = rows.first else { return nil }
        guard row.count == 5,
              let sourceIDText = row[0],
              let attemptsText = row[1],
              let attempts = Int(attemptsText),
              let maxAttemptsText = row[2],
              let maxAttempts = Int(maxAttemptsText),
              let sourceName = row[3],
              let contentType = row[4] else {
            throw IngestQueueError.invalidStoredRecord
        }
        return PendingJob(
            sourceID: ContentID(rawValue: sourceIDText),
            attempts: attempts,
            maxAttempts: maxAttempts,
            sourceName: sourceName,
            contentType: contentType
        )
    }

    private func process(
        _ job: PendingJob,
        isCancelled: () -> Bool
    ) throws -> IngestResult {
        if isCancelled() {
            try updateStatus(
                .cancelled,
                for: job.sourceID,
                attempts: job.attempts
            )
            return IngestResult(
                sourceID: job.sourceID,
                status: .cancelled
            )
        }

        let data = try contentStore.data(for: job.sourceID)
        do {
            let payload = try extractors.extract(
                data: data,
                sourceName: job.sourceName,
                contentType: job.contentType
            )
            try database.transaction {
                try database.execute(
                    """
                    INSERT OR REPLACE INTO derived_documents(
                        source_id, text, modality, extractor_id, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        job.sourceID.rawValue,
                        payload.text,
                        payload.modality.rawValue,
                        payload.extractorID,
                        String(Date().timeIntervalSince1970),
                    ]
                )
                try updateStatus(
                    .completed,
                    for: job.sourceID,
                    attempts: job.attempts + 1
                )
            }
            return IngestResult(
                sourceID: job.sourceID,
                status: .completed
            )
        } catch let error as ExtractorError {
            let nextAttempt = job.attempts + 1
            let status: IngestJobStatus =
                nextAttempt >= job.maxAttempts ? .failed : .pending
            try database.transaction {
                try database.execute(
                    """
                    INSERT INTO ingest_warnings(
                        source_id, attempt, code, message, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        job.sourceID.rawValue,
                        String(nextAttempt),
                        error.warningCode,
                        error.safeMessage,
                        String(Date().timeIntervalSince1970),
                    ]
                )
                try updateStatus(
                    status,
                    for: job.sourceID,
                    attempts: nextAttempt
                )
            }
            return IngestResult(
                sourceID: job.sourceID,
                status: status == .pending ? .retrying : .failed
            )
        }
    }

    public func processAll() throws -> [IngestResult] {
        lock.lock()
        defer { lock.unlock() }
        var results: [IngestResult] = []
        while let result = try processNext() {
            results.append(result)
        }
        return results
    }

    public func retry(_ sourceID: ContentID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard try jobStatus(for: sourceID) != nil else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        try updateStatus(.pending, for: sourceID, attempts: 0)
    }

    public func jobStatus(for sourceID: ContentID) throws -> IngestJobStatus? {
        let rows = try database.query(
            "SELECT status FROM ingest_jobs WHERE source_id = ?",
            bindings: [sourceID.rawValue]
        )
        return rows.first?.first.flatMap { $0 }.flatMap(IngestJobStatus.init(rawValue:))
    }

    public func jobs() throws -> [IngestJobRecord] {
        lock.lock()
        defer { lock.unlock() }
        return try database.query(
            """
            SELECT j.source_id, j.status, j.attempts, j.max_attempts,
                   s.source_name, s.content_type, j.created_at, j.updated_at
            FROM ingest_jobs j
            JOIN sources s ON s.source_id = j.source_id
            ORDER BY j.updated_at DESC, j.source_id ASC
            """
        ).map { row in
            guard row.count == 8,
                  let sourceIDText = row[0],
                  let statusText = row[1],
                  let status = IngestJobStatus(rawValue: statusText),
                  let attemptsText = row[2],
                  let attempts = Int(attemptsText),
                  let maxAttemptsText = row[3],
                  let maxAttempts = Int(maxAttemptsText),
                  let sourceName = row[4],
                  let contentType = row[5],
                  let createdAtText = row[6],
                  let createdAt = TimeInterval(createdAtText),
                  let updatedAtText = row[7],
                  let updatedAt = TimeInterval(updatedAtText) else {
                throw IngestQueueError.invalidStoredRecord
            }
            return IngestJobRecord(
                sourceID: ContentID(rawValue: sourceIDText),
                status: status,
                attempts: attempts,
                maxAttempts: maxAttempts,
                sourceName: sourceName,
                contentType: contentType,
                createdAt: Date(timeIntervalSince1970: createdAt),
                updatedAt: Date(timeIntervalSince1970: updatedAt)
            )
        }
    }

    public func cancel(_ sourceID: ContentID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let state = try jobState(for: sourceID) else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        guard state.status == .pending else {
            throw IngestQueueError.invalidJobTransition(
                sourceID: sourceID,
                from: state.status,
                to: .cancelled
            )
        }
        try updateStatus(
            .cancelled,
            for: sourceID,
            attempts: state.attempts
        )
    }

    @discardableResult
    public func resume(_ sourceID: ContentID) throws -> IngestResult {
        lock.lock()
        defer { lock.unlock() }
        guard let state = try jobState(for: sourceID) else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        guard state.status == .cancelled || state.status == .failed else {
            throw IngestQueueError.invalidJobTransition(
                sourceID: sourceID,
                from: state.status,
                to: .pending
            )
        }
        try updateStatus(.pending, for: sourceID, attempts: 0)
        guard let job = try pendingJob(for: sourceID) else {
            throw IngestQueueError.invalidStoredRecord
        }
        return try process(job, isCancelled: { false })
    }

    public func documents() throws -> [DerivedDocument] {
        try documents(where: """
            COALESCE(l.status, '\(SourceLifecycle.active.rawValue)')
                = '\(SourceLifecycle.active.rawValue)'
            """)
    }

    public func hiddenDocuments() throws -> [DerivedDocument] {
        try documents(where: "l.status = '\(SourceLifecycle.hidden.rawValue)'")
    }

    public func lifecycle(for sourceID: ContentID) throws -> SourceLifecycle {
        guard try sourceExists(sourceID) else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        let rows = try database.query(
            "SELECT status FROM source_lifecycle WHERE source_id = ?",
            bindings: [sourceID.rawValue]
        )
        guard let value = rows.first?.first.flatMap({ $0 }) else {
            return .active
        }
        guard let lifecycle = SourceLifecycle(rawValue: value) else {
            throw IngestQueueError.invalidStoredRecord
        }
        return lifecycle
    }

    public func setLifecycle(
        _ lifecycle: SourceLifecycle,
        for sourceID: ContentID
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard try sourceExists(sourceID) else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        try database.execute(
            """
            INSERT INTO source_lifecycle(source_id, status, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(source_id) DO UPDATE SET
                status = excluded.status,
                updated_at = excluded.updated_at
            """,
            bindings: [
                sourceID.rawValue,
                lifecycle.rawValue,
                String(Date().timeIntervalSince1970),
            ]
        )
    }

    public func inspectRawSource(
        for sourceID: ContentID,
        previewCharacterLimit: Int = 2_000
    ) throws -> RawSourceInspection {
        lock.lock()
        defer { lock.unlock() }
        guard (1...10_000).contains(previewCharacterLimit) else {
            throw IngestQueueError.invalidPreviewCharacterLimit(
                previewCharacterLimit
            )
        }
        let rows = try database.query(
            """
            SELECT s.byte_count, s.source_name, s.content_type,
                   COALESCE(l.status, ?)
            FROM sources s
            LEFT JOIN source_lifecycle l ON l.source_id = s.source_id
            WHERE s.source_id = ?
            """,
            bindings: [
                SourceLifecycle.active.rawValue,
                sourceID.rawValue,
            ]
        )
        guard let row = rows.first else {
            throw IngestQueueError.sourceNotFound(sourceID)
        }
        guard row.count == 4,
              let byteCountText = row[0],
              let byteCount = Int(byteCountText),
              let sourceName = row[1],
              let contentType = row[2],
              let lifecycleText = row[3],
              let lifecycle = SourceLifecycle(rawValue: lifecycleText) else {
            throw IngestQueueError.invalidStoredRecord
        }

        let data = try contentStore.data(for: sourceID)
        guard data.count == byteCount else {
            throw IngestQueueError.invalidStoredRecord
        }

        let previewResult = Self.textPreview(
            data: data,
            contentType: contentType,
            characterLimit: previewCharacterLimit
        )
        return RawSourceInspection(
            sourceID: sourceID,
            verifiedSHA256: sourceID.rawValue,
            byteCount: byteCount,
            sourceName: sourceName,
            contentType: contentType,
            lifecycle: lifecycle,
            previewAvailability: previewResult.availability,
            preview: previewResult.text,
            isPreviewTruncated: previewResult.isTruncated
        )
    }

    private func documents(where lifecyclePredicate: String) throws
        -> [DerivedDocument] {
        try database.query(
            """
            SELECT d.source_id, d.text, d.modality, d.extractor_id, s.created_at
            FROM derived_documents d
            JOIN sources s ON s.source_id = d.source_id
            LEFT JOIN source_lifecycle l ON l.source_id = d.source_id
            WHERE \(lifecyclePredicate)
            ORDER BY d.source_id ASC
            """
        ).map { row in
            guard row.count == 5,
                  let sourceID = row[0],
                  let text = row[1],
                  let modalityText = row[2],
                  let modality = DocumentModality(rawValue: modalityText),
                  let extractorID = row[3],
                  let capturedAtText = row[4],
                  let capturedAt = TimeInterval(capturedAtText) else {
                throw IngestQueueError.invalidStoredRecord
            }
            return DerivedDocument(
                sourceID: ContentID(rawValue: sourceID),
                text: text,
                modality: modality,
                extractorID: extractorID,
                capturedAt: Date(timeIntervalSince1970: capturedAt)
            )
        }
    }

    private func sourceExists(_ sourceID: ContentID) throws -> Bool {
        !(try database.query(
            "SELECT source_id FROM sources WHERE source_id = ?",
            bindings: [sourceID.rawValue]
        )).isEmpty
    }

    private static func textPreview(
        data: Data,
        contentType: String,
        characterLimit: Int
    ) -> (
        availability: RawSourcePreviewAvailability,
        text: String?,
        isTruncated: Bool
    ) {
        let normalizedType = contentType
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let textualApplicationTypes: Set<String> = [
            "application/json",
            "application/xml",
            "application/yaml",
            "application/x-yaml",
        ]
        guard normalizedType.hasPrefix("text/")
                || textualApplicationTypes.contains(normalizedType),
              let text = String(data: data, encoding: .utf8) else {
            return (.binaryUnavailable, nil, false)
        }
        let preview = String(text.prefix(characterLimit))
        return (.text, preview, preview.count < text.count)
    }

    public func warnings() throws -> [IngestWarning] {
        try database.query(
            """
            SELECT source_id, attempt, code, message
            FROM ingest_warnings
            ORDER BY warning_id ASC
            """
        ).map { row in
            guard row.count == 4,
                  let sourceID = row[0],
                  let attemptText = row[1],
                  let attempt = Int(attemptText),
                  let code = row[2],
                  let message = row[3] else {
                throw IngestQueueError.invalidStoredRecord
            }
            return IngestWarning(
                sourceID: ContentID(rawValue: sourceID),
                attempt: attempt,
                code: code,
                message: message
            )
        }
    }

    public func provenance(for sourceID: ContentID) throws -> [CaptureProvenance] {
        try database.query(
            """
            SELECT capture_id, captured_at, origin_kind, origin_detail,
                   source_name, content_type
            FROM capture_events
            WHERE source_id = ?
            ORDER BY captured_at ASC, capture_id ASC
            """,
            bindings: [sourceID.rawValue]
        ).map { row in
            guard row.count == 6,
                  let captureIDText = row[0],
                  let captureID = UUID(uuidString: captureIDText),
                  let capturedAtText = row[1],
                  let capturedAt = TimeInterval(capturedAtText),
                  let originKind = row[2],
                  let sourceName = row[4],
                  let contentType = row[5] else {
                throw IngestQueueError.invalidStoredRecord
            }
            return CaptureProvenance(
                captureID: captureID,
                sourceID: sourceID,
                capturedAt: Date(timeIntervalSince1970: capturedAt),
                sourceName: sourceName,
                contentType: contentType,
                origin: .stored(kind: originKind, detail: row[3])
            )
        }
    }

    public func sourceCount() throws -> Int {
        try count(table: "sources")
    }

    public func jobCount() throws -> Int {
        try count(table: "ingest_jobs")
    }

    public func close() throws {
        try database.close()
    }

    private func count(table: String) throws -> Int {
        let rows = try database.query("SELECT COUNT(*) FROM \(table)")
        return rows.first?.first.flatMap { $0 }.flatMap(Int.init) ?? 0
    }

    private func updateStatus(
        _ status: IngestJobStatus,
        for sourceID: ContentID,
        attempts: Int
    ) throws {
        try database.execute(
            """
            UPDATE ingest_jobs
            SET status = ?, attempts = ?, updated_at = ?
            WHERE source_id = ?
            """,
            bindings: [
                status.rawValue,
                String(attempts),
                String(Date().timeIntervalSince1970),
                sourceID.rawValue,
            ]
        )
    }

    private func jobState(
        for sourceID: ContentID
    ) throws -> (status: IngestJobStatus, attempts: Int)? {
        let rows = try database.query(
            "SELECT status, attempts FROM ingest_jobs WHERE source_id = ?",
            bindings: [sourceID.rawValue]
        )
        guard let row = rows.first else { return nil }
        guard row.count == 2,
              let statusText = row[0],
              let status = IngestJobStatus(rawValue: statusText),
              let attemptsText = row[1],
              let attempts = Int(attemptsText) else {
            throw IngestQueueError.invalidStoredRecord
        }
        return (status, attempts)
    }
}
