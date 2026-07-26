import Foundation

/// Pure local lifecycle transitions for a research packet. Collection and
/// retention are intentionally separate adapters/actions.
public struct ResearchCoordinator: Sendable {
    public init() {}

    public func begin(
        id: String,
        queries: [String],
        stateVersion: Int
    ) throws -> ResearchRun {
        try ResearchRun(
            id: id,
            queries: queries,
            checkpoint: ResearchCheckpoint(phase: .planned, stateVersion: stateVersion)
        )
    }

    public func resume(
        _ run: ResearchRun,
        expectedStateVersion: Int
    ) throws -> ResearchRun {
        guard run.checkpoint.stateVersion == expectedStateVersion else {
            throw ResearchCoordinatorError.staleCheckpoint(
                expected: expectedStateVersion,
                actual: run.checkpoint.stateVersion
            )
        }
        return try ResearchRun(
            id: run.id,
            queries: run.queries,
            checkpoint: ResearchCheckpoint(
                phase: .collecting,
                stateVersion: run.checkpoint.stateVersion + 1
            ),
            retention: run.retention,
            provenance: run.provenance
        )
    }

    public func packet(
        for run: ResearchRun,
        findings: [ResearchFinding],
        context: ContextBundle
    ) throws -> ResearchPacket {
        let facts = findings.filter {
            if case .fact = $0 { return true }
            return false
        }
        let factClaims = facts.compactMap { finding -> CitedClaim? in
            guard case let .fact(_, statement, citations) = finding else { return nil }
            return CitedClaim(statement: statement, citations: citations)
        }
        let verification = CitationVerifier().verify(factClaims, against: context)
        if let unsupportedIndex = verification.unsupportedClaimIndexes.first {
            throw ResearchCoordinatorError.unsupportedFact(facts[unsupportedIndex].id)
        }

        let verifiedIDs = Set(facts.map(\.id))
        let inferences = findings.filter {
            if case .inference = $0 { return true }
            return false
        }
        for inference in inferences {
            guard case let .inference(_, _, basedOnFindingIDs) = inference,
                  !basedOnFindingIDs.isEmpty,
                  Set(basedOnFindingIDs).isSubset(of: verifiedIDs) else {
                throw ResearchCoordinatorError.unsupportedInference(inference.id)
            }
        }
        return ResearchPacket(
            runID: run.id,
            verifiedFacts: facts,
            inferences: inferences,
            retention: run.retention
        )
    }
}

public enum ResearchCoordinatorError: Error, Equatable {
    case staleCheckpoint(expected: Int, actual: Int)
    case unsupportedFact(String)
    case unsupportedInference(String)
}
