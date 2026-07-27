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

    init(document: DerivedDocument, provenance: [CaptureProvenance]) {
        id = document.sourceID.rawValue
        passageID = "\(document.sourceID.rawValue)#0"
        preview = String(document.text.prefix(500))
        modalityLabel = document.modality.rawValue.capitalized
        extractorID = document.extractorID
        capturedAt = document.capturedAt
        captures = provenance.map(LibraryCaptureRow.init)
    }
}

public struct LibraryPresentation: Equatable, Sendable {
    public let documentCount: Int
    public let modalityCounts: [DocumentModality: Int]
    public let rows: [LibrarySourceRow]

    public init(documents: [DerivedDocument]) {
        self.init(documents: documents, provenanceBySource: [:])
    }

    public init(
        documents: [DerivedDocument],
        provenanceBySource: [ContentID: [CaptureProvenance]]
    ) {
        documentCount = documents.count
        modalityCounts = Dictionary(grouping: documents, by: \.modality)
            .mapValues(\.count)
        rows = documents
            .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
            .map {
                LibrarySourceRow(
                    document: $0,
                    provenance: provenanceBySource[$0.sourceID] ?? []
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
}

public final class IngestQueue {
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
        let rows = try database.query(
            """
            SELECT j.source_id, j.attempts, j.max_attempts, s.source_name, s.content_type
            FROM ingest_jobs j
            JOIN sources s ON s.source_id = j.source_id
            WHERE j.status = ?
            ORDER BY j.created_at ASC, j.source_id ASC
            LIMIT 1
            """,
            bindings: [IngestJobStatus.pending.rawValue]
        )
        guard let row = rows.first,
              row.count == 5,
              let sourceIDText = row[0],
              let attemptsText = row[1],
              let attempts = Int(attemptsText),
              let maxAttemptsText = row[2],
              let maxAttempts = Int(maxAttemptsText),
              let sourceName = row[3],
              let contentType = row[4] else {
            if rows.isEmpty { return nil }
            throw IngestQueueError.invalidStoredRecord
        }
        let sourceID = ContentID(rawValue: sourceIDText)

        if isCancelled() {
            try updateStatus(.cancelled, for: sourceID, attempts: attempts)
            return IngestResult(sourceID: sourceID, status: .cancelled)
        }

        let data = try contentStore.data(for: sourceID)
        do {
            let payload = try extractors.extract(
                data: data,
                sourceName: sourceName,
                contentType: contentType
            )
            try database.transaction {
                try database.execute(
                    """
                    INSERT OR REPLACE INTO derived_documents(
                        source_id, text, modality, extractor_id, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        sourceID.rawValue,
                        payload.text,
                        payload.modality.rawValue,
                        payload.extractorID,
                        String(Date().timeIntervalSince1970),
                    ]
                )
                try updateStatus(.completed, for: sourceID, attempts: attempts + 1)
            }
            return IngestResult(sourceID: sourceID, status: .completed)
        } catch let error as ExtractorError {
            let nextAttempt = attempts + 1
            let status: IngestJobStatus = nextAttempt >= maxAttempts ? .failed : .pending
            try database.transaction {
                try database.execute(
                    """
                    INSERT INTO ingest_warnings(
                        source_id, attempt, code, message, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    bindings: [
                        sourceID.rawValue,
                        String(nextAttempt),
                        error.warningCode,
                        error.safeMessage,
                        String(Date().timeIntervalSince1970),
                    ]
                )
                try updateStatus(status, for: sourceID, attempts: nextAttempt)
            }
            return IngestResult(
                sourceID: sourceID,
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

    public func documents() throws -> [DerivedDocument] {
        try database.query(
            """
            SELECT d.source_id, d.text, d.modality, d.extractor_id, s.created_at
            FROM derived_documents d
            JOIN sources s ON s.source_id = d.source_id
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
}
