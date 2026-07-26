import Foundation

/// Explicit local retention for unresolved contradiction candidates. Both
/// cited positions remain independently readable; this store never selects a
/// winner or rewrites either claim.
public final class ContradictionStore {
    private let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> [ContradictionCandidate] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([ContradictionCandidate].self, from: Data(contentsOf: url))
    }

    public func keep(_ candidate: ContradictionCandidate) throws {
        var candidates = try load()
        candidates.removeAll { $0.id == candidate.id }
        candidates.append(candidate)
        candidates.sort { $0.id < $1.id }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(candidates).write(to: url, options: .atomic)
    }
}
