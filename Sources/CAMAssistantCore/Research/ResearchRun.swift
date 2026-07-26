import Foundation

public enum ResearchRetention: String, Codable, Equatable, Sendable {
    /// Results remain in the current in-memory run until a later explicit keep action.
    case ephemeral
    case explicitlyKept
}

public enum ResearchPhase: String, Codable, Equatable, Sendable {
    case planned
    case collecting
    case readyForReview
}

/// The explicit origin of a retained research plan. This is plan metadata,
/// not acquired research output or a grant to read the cited source again.
public enum ResearchPlanProvenanceKind: String, Codable, Equatable, Sendable {
    case repositoryIdea
}

/// Evidence carried into a research plan at an explicit promotion boundary.
/// Repository promotion records citations and the user's uncertainty/validation
/// criteria, but deliberately does not copy source bytes into the plan.
public struct ResearchPlanProvenance: Codable, Equatable, Sendable {
    public let kind: ResearchPlanProvenanceKind
    public let canonicalSourcePath: String
    public let sourceCommit: String
    public let citations: [Citation]
    public let counterevidence: [String]
    public let confidence: Double
    public let validationExperiment: String

    public init(
        kind: ResearchPlanProvenanceKind,
        canonicalSourcePath: String,
        sourceCommit: String,
        citations: [Citation],
        counterevidence: [String],
        confidence: Double,
        validationExperiment: String
    ) {
        self.kind = kind
        self.canonicalSourcePath = canonicalSourcePath
        self.sourceCommit = sourceCommit
        self.citations = citations
        self.counterevidence = counterevidence
        self.confidence = confidence
        self.validationExperiment = validationExperiment
    }
}

public struct ResearchCheckpoint: Codable, Equatable, Sendable {
    public let phase: ResearchPhase
    public let stateVersion: Int

    public init(phase: ResearchPhase, stateVersion: Int) {
        self.phase = phase
        self.stateVersion = stateVersion
    }
}

public struct ResearchRun: Codable, Equatable, Sendable {
    public let id: String
    public let queries: [String]
    public let checkpoint: ResearchCheckpoint
    public let retention: ResearchRetention
    public let provenance: ResearchPlanProvenance?

    public init(
        id: String,
        queries: [String],
        checkpoint: ResearchCheckpoint,
        retention: ResearchRetention = .ephemeral,
        provenance: ResearchPlanProvenance? = nil
    ) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              checkpoint.stateVersion >= 0,
              Self.hasValidQueries(queries) else {
            throw ResearchRunError.invalidQueries
        }
        if let provenance,
           (provenance.canonicalSourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || provenance.sourceCommit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || provenance.citations.isEmpty
                || provenance.counterevidence.isEmpty
                || !(0...1).contains(provenance.confidence)
                || provenance.validationExperiment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            throw ResearchRunError.invalidProvenance
        }
        self.id = id
        self.queries = queries
        self.checkpoint = checkpoint
        self.retention = retention
        self.provenance = provenance
    }

    private static func hasValidQueries(_ queries: [String]) -> Bool {
        let normalized = queries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return !normalized.isEmpty
            && normalized.allSatisfy { !$0.isEmpty }
            && Set(normalized).count == normalized.count
    }
}

public enum ResearchRunError: Error, Equatable {
    case invalidQueries
    case invalidProvenance
}

public enum ResearchFinding: Codable, Equatable, Sendable {
    case fact(id: String, statement: String, citations: [Citation])
    case inference(id: String, statement: String, basedOnFindingIDs: [String])

    public var id: String {
        switch self {
        case let .fact(id, _, _), let .inference(id, _, _): id
        }
    }
}

public struct ResearchPacket: Codable, Equatable, Sendable {
    public let runID: String
    public let verifiedFacts: [ResearchFinding]
    public let inferences: [ResearchFinding]
    public let retention: ResearchRetention
}

/// Read-only native presentation state. Starting an external research run and
/// keeping a packet are intentionally separate, future approved actions.
public struct ResearchPresentation: Equatable, Sendable {
    public let retention: ResearchRetention
    public let executionEnabled: Bool
    public let statusMessage: String

    public init(run: ResearchRun) {
        retention = run.retention
        executionEnabled = false
        statusMessage = "Local research packet is ready to resume; nothing is retained automatically."
    }

    public static let notStarted = Self(
        retention: .ephemeral,
        executionEnabled: false,
        statusMessage: "Research is local-only and idle; nothing is retained automatically."
    )

    private init(retention: ResearchRetention, executionEnabled: Bool, statusMessage: String) {
        self.retention = retention
        self.executionEnabled = executionEnabled
        self.statusMessage = statusMessage
    }
}
