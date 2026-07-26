import Foundation
import Testing
@testable import CAMAssistantCore

@Test("knowledge claims are citation-bound and assumptions are explicit")
func knowledgeClaimsAreCitationBoundAndAssumptionsAreExplicit() throws {
    let citation = Citation(sourceID: "source-1", passageID: "passage-1", quote: "vault remains local")
    let fact = try KnowledgeClaim(
        id: "claim-1",
        statement: "The vault remains local.",
        kind: .fact,
        citations: [citation]
    )
    let assumption = try KnowledgeClaim(
        id: "assumption-1",
        statement: "Local storage is available.",
        kind: .assumption,
        citations: [citation]
    )

    #expect(fact.kind == .fact)
    #expect(assumption.kind == .assumption)
    #expect(throws: KnowledgeClaimError.missingCitation) {
        _ = try KnowledgeClaim(id: "claim-2", statement: "Uncited", kind: .fact, citations: [])
    }
}

@Test("manual contradiction preserves cited positions without merging them")
func manualContradictionPreservesCitedPositionsWithoutMerging() throws {
    let citation = Citation(sourceID: "source-1", passageID: "passage-1", quote: "vault remains local")
    let left = try KnowledgeClaim(id: "left", statement: "Prefer local processing.", kind: .fact, citations: [citation])
    let right = try KnowledgeClaim(id: "right", statement: "Use external research with approval.", kind: .fact, citations: [citation])
    let record = try ContradictionCandidate(
        id: "contra-1",
        left: left,
        right: right,
        steelman: "Each position protects a different operational need.",
        bridgeSuggestion: nil
    )

    #expect(record.left.id == "left")
    #expect(record.right.id == "right")
    #expect(record.bridgeSuggestion == nil)
    #expect(throws: ContradictionError.samePosition) {
        _ = try ContradictionCandidate(id: "contra-2", left: left, right: left, steelman: "Same", bridgeSuggestion: nil)
    }
}

@Test("explicitly kept citation-bound knowledge persists across restart")
func explicitlyKeptKnowledgePersistsAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let claim = try KnowledgeClaim(
        id: "kept-claim",
        statement: "The vault remains local.",
        kind: .fact,
        citations: [Citation(sourceID: "source", passageID: "passage", quote: "remains local")]
    )

    try KnowledgeStore(url: root.appending(path: "knowledge.json")).keep(claim)

    #expect(try KnowledgeStore(url: root.appending(path: "knowledge.json")).load() == [claim])
}

@Test("explicitly kept contradiction candidates persist without merging positions")
func explicitlyKeptContradictionsPersistWithoutMergingPositions() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let citation = Citation(sourceID: "source", passageID: "passage", quote: "evidence")
    let left = try KnowledgeClaim(id: "left", statement: "Prefer local work.", kind: .fact, citations: [citation])
    let right = try KnowledgeClaim(id: "right", statement: "Use web research with approval.", kind: .fact, citations: [citation])
    let candidate = try ContradictionCandidate(id: "candidate", left: left, right: right, steelman: "Each boundary protects a distinct need.", bridgeSuggestion: "Use an explicit approval boundary.")

    try ContradictionStore(url: root.appending(path: "contradictions.json")).keep(candidate)

    #expect(try ContradictionStore(url: root.appending(path: "contradictions.json")).load() == [candidate])
}
