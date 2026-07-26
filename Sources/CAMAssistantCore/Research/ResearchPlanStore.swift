import Foundation

/// An explicitly retained local planning checkpoint. It contains only the
/// user's research questions, lifecycle state, and (when explicitly promoted)
/// citation metadata. Findings, source bytes, web output, and model output
/// remain outside this store.
public struct StoredResearchPlan: Codable, Equatable, Sendable {
    public let run: ResearchRun
    public let retainedAt: Date

    public init(run: ResearchRun, retainedAt: Date) {
        self.run = run
        self.retainedAt = retainedAt
    }
}

/// Atomic local persistence for research plans that the user explicitly keeps.
/// Beginning a run never calls this store, preserving the no-auto-retention
/// contract.
public final class ResearchPlanStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> [StoredResearchPlan] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([StoredResearchPlan].self, from: Data(contentsOf: url))
    }

    public func keep(_ run: ResearchRun, retainedAt: Date = Date()) throws {
        var records = try load()
        records.removeAll { $0.run.id == run.id }
        records.append(StoredResearchPlan(run: run, retainedAt: retainedAt))
        records.sort {
            $0.retainedAt == $1.retainedAt
                ? $0.run.id < $1.run.id
                : $0.retainedAt < $1.retainedAt
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(records).write(to: url, options: .atomic)
    }
}
