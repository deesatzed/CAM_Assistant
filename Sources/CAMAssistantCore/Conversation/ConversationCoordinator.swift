import Foundation

public enum ConversationRoute: String, Codable, Equatable, Sendable {
    case localRetrieval
    case localModel
}

public enum ConversationConfidence: Int, Codable, Comparable, Sendable {
    case low = 0
    case supported = 1

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ConversationResponse: Equatable, Sendable {
    public let id: String
    public let text: String
    public let route: ConversationRoute
    public let confidence: ConversationConfidence
    public let citations: [Citation]
    public let retention: ResearchRetention
    public let modelIdentity: String?
    public let endpointIdentity: String?
    /// Present only for a low-confidence local result; it must not imply a
    /// provider, web, CAM, or automatic retry path.
    public let followUp: String?
}

public enum ConversationDisposition: Equatable, Sendable {
    case kept
    case discarded
}

public struct ConversationRecord: Equatable, Sendable {
    public let response: ConversationResponse
    public let disposition: ConversationDisposition
}

/// Deterministic local response construction. It intentionally has no model,
/// transport, provider, or CAM dependency.
public struct ConversationCoordinator: Sendable {
    private static let maximumEvidencePassages = 3
    private static let maximumExcerptCharacters = 500

    public init() {}

    public func respond(question: String, context: ContextBundle) throws -> ConversationResponse {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ConversationError.blankQuestion }
        let passages = Array(
            context.passages
                .filter { !Self.excerpt(from: $0.text).isEmpty }
                .prefix(Self.maximumEvidencePassages)
        )
        let citations = passages.map { passage in
            Citation(
                sourceID: passage.sourceID,
                passageID: passage.passageID,
                quote: Self.excerpt(from: passage.text)
            )
        }
        let text: String
        let confidence: ConversationConfidence
        let followUp: String?
        if !passages.isEmpty {
            text = "Local evidence (extractive):\n" + citations
                .map { "• \($0.quote)" }
                .joined(separator: "\n")
            confidence = .supported
            followUp = nil
        } else {
            text = "I do not have local source context for that question yet."
            confidence = .low
            followUp = "Capture or index one relevant local source, then ask again."
        }
        let identity = GoldenRetrievalManifest.sha256(of: Data((normalized + "|" + passages.map(\.passageID).joined(separator: "|")).utf8))
        return ConversationResponse(
            id: identity,
            text: text,
            route: .localRetrieval,
            confidence: confidence,
            citations: citations,
            retention: .ephemeral,
            modelIdentity: nil,
            endpointIdentity: nil,
            followUp: followUp
        )
    }

    public func respond(
        question: String,
        generated: LocalModelGeneratedAnswer
    ) throws -> ConversationResponse {
        let normalized = question.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalized.isEmpty else { throw ConversationError.blankQuestion }
        guard !generated.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty, !generated.citations.isEmpty else {
            throw ConversationError.ungroundedGeneratedResponse
        }
        let identity = GoldenRetrievalManifest.sha256(
            of: Data(
                (
                    normalized + "|" + generated.modelID + "|"
                        + generated.citations.map(\.passageID)
                            .joined(separator: "|")
                ).utf8
            )
        )
        return ConversationResponse(
            id: identity,
            text: generated.text,
            route: .localModel,
            confidence: .supported,
            citations: generated.citations,
            retention: generated.retention,
            modelIdentity: generated.modelID,
            endpointIdentity: generated.endpointIdentity,
            followUp: nil
        )
    }

    private static func excerpt(from text: String) -> String {
        String(text.prefix(maximumExcerptCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func keep(_ response: ConversationResponse) -> ConversationRecord {
        ConversationRecord(response: response, disposition: .kept)
    }

    public func discard(_ response: ConversationResponse) -> ConversationRecord {
        ConversationRecord(response: response, disposition: .discarded)
    }

    public func promoteToTask(
        _ record: ConversationRecord,
        title: String,
        acceptanceCriteria: [String],
        authority: TaskAuthority
    ) throws -> TaskProposal {
        guard record.disposition == .kept else { throw ConversationTransitionError.discardedResponse }
        guard !record.response.citations.isEmpty else { throw ConversationTransitionError.uncitedResponse }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let criteria = acceptanceCriteria.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !trimmedTitle.isEmpty, !criteria.isEmpty, criteria.allSatisfy({ !$0.isEmpty }) else {
            throw ConversationTransitionError.invalidTask
        }
        return TaskProposal(
            id: GoldenRetrievalManifest.sha256(of: Data((record.response.id + "|" + trimmedTitle).utf8)),
            title: trimmedTitle,
            acceptanceCriteria: criteria,
            authority: authority,
            citations: record.response.citations
        )
    }
}

public enum ConversationError: Error, Equatable {
    case blankQuestion
    case ungroundedGeneratedResponse
}

public enum ConversationTransitionError: Error, Equatable {
    case discardedResponse
    case uncitedResponse
    case invalidTask
}

/// Deterministic local context selection from completed derived documents.
/// The SQLite initializer reads only the local vault's derived-document rows.
public final class LocalConversationContextProvider {
    private let suppliedDocuments: [DerivedDocument]?
    private let databaseURL: URL?

    public init(documents: [DerivedDocument]) {
        suppliedDocuments = documents
        databaseURL = nil
    }

    public init(databaseURL: URL) {
        suppliedDocuments = nil
        self.databaseURL = databaseURL
    }

    public static func defaultDatabaseURL(fileManager: FileManager = .default) throws -> URL {
        try LocalVaultPaths.databaseURL(fileManager: fileManager)
    }

    public func context(for question: String, limit: Int = 5) throws -> ContextBundle {
        let documents = try suppliedDocuments ?? loadDocuments()
        let terms = question.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let matches = documents.filter { document in
            !terms.isEmpty && terms.allSatisfy { document.text.localizedCaseInsensitiveContains($0) }
        }
        .sorted { $0.sourceID.rawValue < $1.sourceID.rawValue }
        .prefix(max(0, limit))
        let passages = matches.map { document in
            ContextPassage(
                sourceID: document.sourceID.rawValue,
                passageID: "\(document.sourceID.rawValue)#0",
                modality: document.modality.rawValue,
                text: document.text
            )
        }
        return ContextBundle(
            formatVersion: "context-v1",
            passages: Array(passages),
            serializedContext: passages.map { "[source=\($0.sourceID); passage=\($0.passageID)]\n\($0.text)\n" }.joined(),
            totalCharacters: passages.map(\.text.count).reduce(0, +),
            estimatedTokens: passages.map { ($0.text.count + 3) / 4 }.reduce(0, +),
            droppedPassages: max(0, matches.count - passages.count),
            thrashRate: 0
        )
    }

    private func loadDocuments() throws -> [DerivedDocument] {
        guard let databaseURL else { return [] }
        let store = try SQLiteStore(databaseURL: databaseURL)
        let rows = try store.query(
            """
            SELECT d.source_id, d.text, d.modality, d.extractor_id, d.created_at
            FROM derived_documents d
            LEFT JOIN source_lifecycle l ON l.source_id = d.source_id
            WHERE COALESCE(l.status, 'active') = 'active'
            ORDER BY d.created_at DESC
            """
        )
        return rows.compactMap { row in
            guard row.count == 5,
                  let sourceID = row[0], let text = row[1], let modalityText = row[2],
                  let modality = DocumentModality(rawValue: modalityText), let extractorID = row[3],
                  let created = row[4].flatMap(Double.init) else { return nil }
            return DerivedDocument(
                sourceID: ContentID(rawValue: sourceID), text: text, modality: modality,
                extractorID: extractorID, capturedAt: Date(timeIntervalSince1970: created)
            )
        }
    }
}
