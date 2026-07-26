import Foundation

/// Explicitly retained, citation-bound local knowledge. Saving a record never
/// changes the underlying source and does not infer truth beyond its kind.
public final class KnowledgeStore {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> [KnowledgeClaim] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([KnowledgeClaim].self, from: Data(contentsOf: url))
    }

    public func keep(_ claim: KnowledgeClaim) throws {
        var claims = try load()
        claims.removeAll { $0.id == claim.id }
        claims.append(claim)
        claims.sort { $0.id < $1.id }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(claims).write(to: url, options: .atomic)
    }
}
