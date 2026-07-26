import Foundation

public enum KnowledgeClaimKind: String, Codable, Equatable, Sendable {
    case fact
    case assumption
}

/// A candidate knowledge record. It is not an edit to a source or a claim of
/// universal truth; citations remain attached for later review.
public struct KnowledgeClaim: Codable, Equatable, Sendable {
    public let id: String
    public let statement: String
    public let kind: KnowledgeClaimKind
    public let citations: [Citation]

    public init(
        id: String,
        statement: String,
        kind: KnowledgeClaimKind,
        citations: [Citation]
    ) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KnowledgeClaimError.invalidContent
        }
        guard !citations.isEmpty else {
            throw KnowledgeClaimError.missingCitation
        }
        self.id = id
        self.statement = statement
        self.kind = kind
        self.citations = citations
    }
}

public enum KnowledgeClaimError: Error, Equatable {
    case invalidContent
    case missingCitation
}
