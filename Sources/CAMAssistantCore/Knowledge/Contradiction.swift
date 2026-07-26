import Foundation

/// A manual review candidate. Both positions remain intact, even when a
/// steelman or bridge suggestion is supplied.
public struct ContradictionCandidate: Codable, Equatable, Sendable {
    public let id: String
    public let left: KnowledgeClaim
    public let right: KnowledgeClaim
    public let steelman: String
    public let bridgeSuggestion: String?

    public init(
        id: String,
        left: KnowledgeClaim,
        right: KnowledgeClaim,
        steelman: String,
        bridgeSuggestion: String?
    ) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !steelman.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContradictionError.invalidContent
        }
        guard left.id != right.id else {
            throw ContradictionError.samePosition
        }
        self.id = id
        self.left = left
        self.right = right
        self.steelman = steelman
        self.bridgeSuggestion = bridgeSuggestion
    }
}

public enum ContradictionError: Error, Equatable {
    case invalidContent
    case samePosition
}
