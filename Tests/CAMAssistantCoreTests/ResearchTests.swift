import Foundation
import Testing
@testable import CAMAssistantCore

@Test("research runs checkpoint and resume without retaining output")
func researchRunsCheckpointAndResumeWithoutRetention() throws {
    let coordinator = ResearchCoordinator()
    let provenance = ResearchPlanProvenance(
        kind: .repositoryIdea,
        canonicalSourcePath: "/tmp/example",
        sourceCommit: String(repeating: "a", count: 40),
        citations: [Citation(sourceID: "/tmp/example", passageID: "source.swift:1", quote: "Evidence")],
        counterevidence: ["Counterevidence"],
        confidence: 0.5,
        validationExperiment: "Run a focused test."
    )
    let run = try ResearchRun(
        id: "research-1",
        queries: ["local-first assistant", "citation requirements"],
        checkpoint: ResearchCheckpoint(phase: .planned, stateVersion: 3),
        provenance: provenance
    )

    #expect(run.retention == .ephemeral)
    #expect(run.checkpoint.phase == .planned)
    #expect(run.checkpoint.stateVersion == 3)

    let resumed = try coordinator.resume(run, expectedStateVersion: 3)
    #expect(resumed.checkpoint.phase == .collecting)
    #expect(resumed.checkpoint.stateVersion == 4)
    #expect(resumed.retention == .ephemeral)
    #expect(resumed.provenance == provenance)
    #expect(
        throws: ResearchCoordinatorError.staleCheckpoint(expected: 3, actual: 4)
    ) {
        _ = try coordinator.resume(resumed, expectedStateVersion: 3)
    }
}

@Test("research runs reject blank and duplicate queries")
func researchRunsRejectInvalidQueries() {
    let coordinator = ResearchCoordinator()

    #expect(throws: ResearchRunError.invalidQueries) {
        _ = try coordinator.begin(id: "research-2", queries: ["same", "same"], stateVersion: 0)
    }
    #expect(throws: ResearchRunError.invalidQueries) {
        _ = try coordinator.begin(id: "research-3", queries: ["   "], stateVersion: 0)
    }
}

@Test("research packets preserve verified facts separately from inferences")
func researchPacketsPreserveFactsAndInferences() throws {
    let coordinator = ResearchCoordinator()
    let run = try coordinator.begin(id: "research-4", queries: ["local evidence"], stateVersion: 0)
    let context = researchContext()
    let fact = ResearchFinding.fact(
        id: "fact-1",
        statement: "The vault remains local.",
        citations: [Citation(sourceID: "source-1", passageID: "passage-1", quote: "vault remains local")]
    )
    let inference = ResearchFinding.inference(
        id: "inference-1",
        statement: "A local vault can reduce outbound exposure.",
        basedOnFindingIDs: ["fact-1"]
    )

    let packet = try coordinator.packet(for: run, findings: [fact, inference], context: context)

    #expect(packet.verifiedFacts.map(\.id) == ["fact-1"])
    #expect(packet.inferences.map(\.id) == ["inference-1"])
    #expect(packet.retention == .ephemeral)
}

@Test("research packets reject forged citations and unsupported inferences")
func researchPacketsRejectUnsupportedEvidence() throws {
    let coordinator = ResearchCoordinator()
    let run = try coordinator.begin(id: "research-5", queries: ["local evidence"], stateVersion: 0)
    let forged = ResearchFinding.fact(
        id: "fact-forged",
        statement: "Incorrect evidence.",
        citations: [Citation(sourceID: "source-1", passageID: "passage-1", quote: "not present")]
    )
    let unsupportedInference = ResearchFinding.inference(
        id: "inference-orphan",
        statement: "Unsupported inference.",
        basedOnFindingIDs: ["missing-fact"]
    )

    #expect(throws: ResearchCoordinatorError.unsupportedFact("fact-forged")) {
        _ = try coordinator.packet(for: run, findings: [forged], context: researchContext())
    }
    #expect(throws: ResearchCoordinatorError.unsupportedInference("inference-orphan")) {
        _ = try coordinator.packet(for: run, findings: [unsupportedInference], context: researchContext())
    }
}

@Test("research presentation keeps external execution and auto-retention disabled")
func researchPresentationKeepsExecutionAndRetentionDisabled() throws {
    let run = try ResearchCoordinator().begin(id: "research-6", queries: ["local evidence"], stateVersion: 0)
    let presentation = ResearchPresentation(run: run)

    #expect(presentation.retention == .ephemeral)
    #expect(presentation.executionEnabled == false)
    #expect(presentation.statusMessage == "Local research packet is ready to resume; nothing is retained automatically.")
}

@Test("explicitly kept local research plans persist across restart without research output")
func explicitlyKeptResearchPlansPersistAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let run = try ResearchCoordinator().begin(
        id: "research-kept",
        queries: ["local evidence"],
        stateVersion: 2
    )
    let storeURL = root.appending(path: "research-plans.json")

    try ResearchPlanStore(url: storeURL).keep(run, retainedAt: .distantPast)
    let records = try ResearchPlanStore(url: storeURL).load()

    #expect(records == [StoredResearchPlan(run: run, retainedAt: .distantPast)])
    #expect(records[0].run.retention == .ephemeral)
}

@Test("explicitly kept verified research packets persist across restart")
func explicitlyKeptResearchPacketsPersistAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let run = try ResearchCoordinator().begin(id: "research-packet-kept", queries: ["local evidence"], stateVersion: 0)
    let fact = ResearchFinding.fact(id: "fact", statement: "The vault remains local.", citations: [Citation(sourceID: "source-1", passageID: "passage-1", quote: "vault remains local")])
    let packet = try ResearchCoordinator().packet(for: run, findings: [fact], context: researchContext())

    try ResearchPacketStore(url: root.appending(path: "research-packets.json")).keep(packet)

    #expect(try ResearchPacketStore(url: root.appending(path: "research-packets.json")).load() == [packet])
}

private func researchContext() -> ContextBundle {
    ContextBundle(
        formatVersion: "context-v1",
        passages: [ContextPassage(sourceID: "source-1", passageID: "passage-1", modality: "text", text: "The personal vault remains local by default.")],
        serializedContext: "",
        totalCharacters: 0,
        estimatedTokens: 0,
        droppedPassages: 0,
        thrashRate: 0
    )
}
