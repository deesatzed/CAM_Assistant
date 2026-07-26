import Foundation
import Testing
@testable import CAMAssistantCore

@Test("v2 retrieval manifest labels are frozen by content hash")
func retrievalManifestIsFrozen() throws {
    let url = retrievalV2ManifestURL()
    let data = try Data(contentsOf: url)
    let manifest = try GoldenRetrievalManifest.decode(data)

    #expect(
        GoldenRetrievalManifest.sha256(of: data)
            == "3172ab92fd1f2122de14f00bfb604d76eeaf11a04319b020c05c69ee5a32ffcb"
    )
    #expect(manifest.manifestVersion == 2)
    #expect(Set(manifest.sources.map(\.id)).count == manifest.sources.count)
    #expect(Set(manifest.queries.map(\.id)).count == manifest.queries.count)
    #expect(manifest.queries.allSatisfy { !$0.relevantPassageIDs.isEmpty })
    #expect(manifest.queries.allSatisfy { !$0.expectedClaims.isEmpty })
    try manifest.validate()
}

@Test("approved project-contract corpus is frozen and retrieves its cited policy evidence")
func projectContractRetrievalCorpusIsFrozenAndEvaluated() throws {
    let manifestURL = projectContractManifestURL()
    let data = try Data(contentsOf: manifestURL)
    let manifest = try GoldenRetrievalManifest.decode(data)
    try manifest.validate()

    #expect(
        GoldenRetrievalManifest.sha256(of: data)
            == "684a75b25f608a9bf1745bae945a4654969ce78e3ea4cabdabf5c4247caabf26"
    )
    #expect(manifest.manifestVersion == 2)
    #expect(manifest.sources.count == 5)
    #expect(manifest.queries.count == 6)

    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let report = try RetrievalEvaluator().evaluate(
        manifestURL: manifestURL,
        indexURL: root.appending(path: "project-contract.sqlite")
    )
    #expect(report.recallAt10 >= 0.85)
    #expect(report.meanReciprocalRank >= 0.70)
    #expect(report.citedClaimQuoteSupport >= 0.95)
}

@Test("retrieval manifest rejects a query that references an unknown source")
func retrievalManifestRejectsUnknownRelevantSource() throws {
    let data = Data(
        """
        {
          "manifestVersion": 1,
          "frozenAt": "2026-07-25",
          "sources": [
            {
              "id": "known-source",
              "modality": "text",
              "authority": 0.8,
              "capturedAt": 1,
              "text": "Known source text."
            }
          ],
          "queries": [
            {
              "id": "unknown-reference",
              "text": "What is known?",
              "relevantSourceIDs": ["missing-source"]
            }
          ]
        }
        """.utf8
    )
    let manifest = try GoldenRetrievalManifest.decode(data)

    #expect(
        throws: GoldenRetrievalManifestError.unknownRelevantSource(
            queryID: "unknown-reference",
            sourceID: "missing-source"
        )
    ) {
        try manifest.validate()
    }
}

@Test("retrieval manifest rejects duplicate source IDs")
func retrievalManifestRejectsDuplicateSourceID() throws {
    let data = Data(
        """
        {
          "manifestVersion": 1,
          "frozenAt": "2026-07-25",
          "sources": [
            {
              "id": "duplicate-source",
              "modality": "text",
              "authority": 0.8,
              "capturedAt": 1,
              "text": "First source text."
            },
            {
              "id": "duplicate-source",
              "modality": "text",
              "authority": 0.7,
              "capturedAt": 2,
              "text": "Second source text."
            }
          ],
          "queries": [
            {
              "id": "duplicate-source-query",
              "text": "What is present?",
              "relevantSourceIDs": ["duplicate-source"]
            }
          ]
        }
        """.utf8
    )
    let manifest = try GoldenRetrievalManifest.decode(data)

    #expect(
        throws: GoldenRetrievalManifestError.duplicateSourceID("duplicate-source")
    ) {
        try manifest.validate()
    }
}

@Test("retrieval manifest rejects an unsupported schema version")
func retrievalManifestRejectsUnsupportedVersion() throws {
    let data = Data(
        """
        {
          "manifestVersion": 99,
          "frozenAt": "2026-07-25",
          "sources": [
            {
              "id": "known-source",
              "modality": "text",
              "authority": 0.8,
              "capturedAt": 1,
              "text": "Known source text."
            }
          ],
          "queries": [
            {
              "id": "known-query",
              "text": "What is known?",
              "relevantSourceIDs": ["known-source"]
            }
          ]
        }
        """.utf8
    )
    let manifest = try GoldenRetrievalManifest.decode(data)

    #expect(throws: GoldenRetrievalManifestError.unsupportedVersion(99)) {
        try manifest.validate()
    }
}

@Test("v2 retrieval manifest preserves chunks and citation expectations")
func v2RetrievalManifestPreservesChunksAndCitationExpectations() throws {
    let data = Data(
        """
        {
          "manifestVersion": 2,
          "frozenAt": "2026-07-25",
          "sources": [
            {
              "id": "project-plan",
              "modality": "markdown",
              "authority": 0.9,
              "capturedAt": 1,
              "chunks": [
                {
                  "id": "project-plan#scope",
                  "text": "Project Atlas preserves source citations."
                },
                {
                  "id": "project-plan#date",
                  "text": "The Atlas review occurs on September 14."
                }
              ]
            }
          ],
          "queries": [
            {
              "id": "atlas-date",
              "text": "When is the Atlas review?",
              "relevantPassageIDs": ["project-plan#date"],
              "expectedClaims": [
                {
                  "statement": "The Atlas review occurs on September 14.",
                  "citations": [
                    {
                      "sourceID": "project-plan",
                      "passageID": "project-plan#date",
                      "quote": "Atlas review occurs on September 14"
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8
    )
    let manifest = try GoldenRetrievalManifest.decode(data)
    try manifest.validate()

    #expect(manifest.indexedPassages.map(\.id) == [
        "project-plan#scope",
        "project-plan#date",
    ])
    #expect(manifest.queries[0].expectedClaims.count == 1)
}

@Test("v2 retrieval manifest rejects blank chunks before indexing")
func v2RetrievalManifestRejectsBlankChunks() throws {
    let manifest = try GoldenRetrievalManifest.decode(
        Data(
            """
            {
              "manifestVersion": 2,
              "frozenAt": "2026-07-25",
              "sources": [{
                "id": "empty-chunk-source",
                "modality": "text",
                "authority": 0.8,
                "capturedAt": 1,
                "chunks": [{"id": "empty-chunk-source#0", "text": "   "}]
              }],
              "queries": [{
                "id": "empty-chunk-query",
                "text": "What is empty?",
                "relevantPassageIDs": ["empty-chunk-source#0"],
                "expectedClaims": [{
                  "statement": "Nothing is present.",
                  "citations": [{
                    "sourceID": "empty-chunk-source",
                    "passageID": "empty-chunk-source#0",
                    "quote": "nothing"
                  }]
                }]
              }]
            }
            """.utf8
        )
    )

    #expect(
        throws: GoldenRetrievalManifestError.blankChunk(
            sourceID: "empty-chunk-source",
            passageID: "empty-chunk-source#0"
        )
    ) {
        try manifest.validate()
    }
}

@Test("v2 retrieval manifest rejects unsupported modality and authority")
func v2RetrievalManifestRejectsInvalidSourceMetadata() throws {
    let manifest = try GoldenRetrievalManifest.decode(
        Data(
            """
            {
              "manifestVersion": 2,
              "frozenAt": "2026-07-25",
              "sources": [{
                "id": "unknown-modality-source",
                "modality": "spreadsheet",
                "authority": 1.5,
                "capturedAt": 1,
                "chunks": [{"id": "unknown-modality-source#0", "text": "Source text."}]
              }],
              "queries": [{
                "id": "unknown-modality-query",
                "text": "What is the source?",
                "relevantPassageIDs": ["unknown-modality-source#0"],
                "expectedClaims": [{
                  "statement": "Source text.",
                  "citations": [{
                    "sourceID": "unknown-modality-source",
                    "passageID": "unknown-modality-source#0",
                    "quote": "Source text"
                  }]
                }]
              }]
            }
            """.utf8
        )
    )

    #expect(
        throws: GoldenRetrievalManifestError.unsupportedModality(
            sourceID: "unknown-modality-source",
            modality: "spreadsheet"
        )
    ) {
        try manifest.validate()
    }
}

@Test("full-text retrieval is deterministic and returns only stored passages")
func fullTextRetrievalIsDeterministicAndSourced() throws {
    let harness = try RetrievalHarness()
    defer { harness.remove() }
    try harness.index.replace(with: harness.manifest.indexedPassages)

    let first = try harness.index.search("Atlas launch review", limit: 10)
    let second = try harness.index.search("Atlas launch review", limit: 10)

    #expect(first == second)
    #expect(first.first?.sourceID == "atlas-handbook")
    for result in first {
        let passage = try #require(
            harness.manifest.indexedPassages.first { $0.id == result.passageID }
        )
        #expect(result.text == passage.text)
    }
}

@Test("derived index refuses a mismatched generation fingerprint")
func derivedIndexRefusesMismatchedFingerprint() throws {
    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "retrieval.sqlite")
    let first = try FullTextIndex(
        databaseURL: databaseURL,
        fingerprint: "manifest-v1|fts5|unicode61"
    )
    try first.close()

    #expect(
        throws: FullTextIndexError.fingerprintMismatch(
            expected: "manifest-v2|fts5|unicode61",
            actual: "manifest-v1|fts5|unicode61"
        )
    ) {
        try FullTextIndex(
            databaseURL: databaseURL,
            fingerprint: "manifest-v2|fts5|unicode61"
        )
    }
}

@Test("persistent index generations rebuild from derived documents without losing the active generation")
func persistentIndexGenerationsSurviveRestartAndFailedRebuild() throws {
    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fingerprint = IndexFingerprint(
        schemaVersion: 1,
        sourceManifestHash: "pending",
        tokenizer: "unicode61",
        preprocessing: "lowercase-stopwords-v1",
        chunking: "words-200-v1",
        semanticProvider: "none",
        semanticModel: "none",
        semanticDimensions: 0,
        fusionVersion: "hybrid-v1"
    )
    let builder = try RetrievalIndexBuilder(
        rootDirectory: root.appending(path: "index"),
        baseFingerprint: fingerprint
    )
    let validDocument = DerivedDocument(
        sourceID: ContentID(rawValue: "source-alpha"),
        text: "The persistent retrieval generation keeps source provenance.",
        modality: .text,
        extractorID: "fixture.v1",
        capturedAt: Date(timeIntervalSince1970: 1)
    )

    let first = try builder.rebuild(documents: [validDocument])
    let active = try builder.openActive()
    let initialResults = try active.search("persistent provenance", limit: 10)
    try active.close()

    #expect(first.passageCount == 1)
    #expect(initialResults.first?.sourceID == "source-alpha")

    let invalidDocument = DerivedDocument(
        sourceID: ContentID(rawValue: "source-empty"),
        text: "   ",
        modality: .text,
        extractorID: "fixture.v1",
        capturedAt: Date(timeIntervalSince1970: 2)
    )
    #expect(throws: RetrievalIndexBuilderError.emptyDocument("source-empty")) {
        _ = try builder.rebuild(documents: [invalidDocument])
    }

    let restarted = try RetrievalIndexBuilder(
        rootDirectory: root.appending(path: "index"),
        baseFingerprint: fingerprint
    )
    let recovered = try restarted.openActive()
    let recoveredResults = try recovered.search("persistent provenance", limit: 10)
    try recovered.close()

    #expect(recoveredResults.first?.sourceID == "source-alpha")
}

@Test("hybrid fusion explains lexical semantic and authority contributions")
func hybridFusionExplainsContributions() throws {
    let harness = try RetrievalHarness()
    defer { harness.remove() }
    try harness.index.replace(with: harness.manifest.indexedPassages)
    let semantic = StaticSemanticLane(
        values: [
            LaneCandidate(passageID: "answering-interview#advice", score: 0.98),
        ]
    )
    let retriever = HybridRetriever(
        fullTextIndex: harness.index,
        semanticLane: semantic,
        entityLane: EmptyEntityLane()
    )

    let results = try retriever.retrieve(
        query: "audio interview citations",
        limit: 5
    )
    let audio = try #require(
        results.first { $0.sourceID == "answering-interview" }
    )
    let lanes = Set(audio.contributions.map(\.lane))

    #expect(lanes.contains(.fullText))
    #expect(lanes.contains(.semantic))
    #expect(lanes.contains(.authority))
    #expect(audio.score == audio.contributions.map(\.value).reduce(0, +))
}

@Test("hybrid fusion deduplicates a lane and rejects non-finite candidate scores")
func hybridFusionRejectsInvalidOrDuplicatedCandidates() throws {
    let harness = try RetrievalHarness()
    defer { harness.remove() }
    try harness.index.replace(with: harness.manifest.indexedPassages)

    let duplicated = HybridRetriever(
        fullTextIndex: harness.index,
        semanticLane: StaticSemanticLane(values: [
            LaneCandidate(passageID: "answering-interview#advice", score: 0.2),
            LaneCandidate(passageID: "answering-interview#advice", score: 0.8),
        ]),
        entityLane: EmptyEntityLane()
    )
    let result = try #require(
        try duplicated.retrieve(query: "unmatched semantic request", limit: 10)
            .first { $0.passageID == "answering-interview#advice" }
    )
    let semanticContributions = result.contributions.filter { $0.lane == .semantic }

    #expect(semanticContributions.count == 1)
    #expect(abs((semanticContributions.first?.value ?? 0) - 0.16) < 0.000_001)

    let invalid = HybridRetriever(
        fullTextIndex: harness.index,
        semanticLane: StaticSemanticLane(values: [
            LaneCandidate(passageID: "answering-interview#advice", score: .nan),
        ]),
        entityLane: EmptyEntityLane()
    )
    #expect(
        throws: HybridRetrieverError.invalidCandidateScore(
            passageID: "answering-interview#advice"
        )
    ) {
        _ = try invalid.retrieve(query: "unmatched semantic request", limit: 10)
    }
}

@Test("context assembly enforces character token and passage budgets")
func contextAssemblyEnforcesBudgets() throws {
    let harness = try RetrievalHarness()
    defer { harness.remove() }
    try harness.index.replace(with: harness.manifest.indexedPassages)
    let results = try HybridRetriever(fullTextIndex: harness.index)
        .retrieve(query: "capture source local index", limit: 10)
    let budget = ContextBudget(
        maxCharacters: 180,
        maxEstimatedTokens: 45,
        maxPassages: 2
    )

    let bundle = ContextAssembler().assemble(results, budget: budget)

    #expect(bundle.totalCharacters <= budget.maxCharacters)
    #expect(bundle.estimatedTokens <= budget.maxEstimatedTokens)
    #expect(bundle.passages.count <= budget.maxPassages)
    #expect(bundle.droppedPassages > 0)
    #expect(bundle.thrashRate > 0)
}

@Test("context accounting includes citation metadata and serialization overhead")
func contextAccountingIncludesCitationMetadata() {
    let result = RetrievalResult(
        passageID: "source-a#chunk-0",
        sourceID: "source-a",
        modality: "markdown",
        text: "A short retrieved passage.",
        score: 1,
        contributions: [ScoreContribution(lane: .fullText, value: 1)]
    )
    let bundle = ContextAssembler().assemble(
        [result],
        budget: ContextBudget(
            maxCharacters: 1_000,
            maxEstimatedTokens: 250,
            maxPassages: 1
        )
    )

    #expect(bundle.formatVersion == "context-v1")
    #expect(bundle.serializedContext.contains("source=source-a"))
    #expect(bundle.serializedContext.contains("passage=source-a#chunk-0"))
    #expect(bundle.serializedContext.contains("modality=markdown"))
    #expect(bundle.totalCharacters == bundle.serializedContext.count)
    #expect(bundle.estimatedTokens == (bundle.serializedContext.count + 3) / 4)
    #expect(bundle.passages.first?.modality == "markdown")
}

@Test("citation verifier accepts exact support and rejects forged quotes")
func citationVerifierRequiresExactSourceSupport() throws {
    let harness = try RetrievalHarness()
    defer { harness.remove() }
    try harness.index.replace(with: harness.manifest.indexedPassages)
    let results = try HybridRetriever(fullTextIndex: harness.index)
        .retrieve(query: "Atlas launch review", limit: 10)
    let bundle = ContextAssembler().assemble(
        results,
        budget: ContextBudget(
            maxCharacters: 1_000,
            maxEstimatedTokens: 250,
            maxPassages: 10
        )
    )
    let schedule = try #require(
        bundle.passages.first { $0.passageID == "atlas-handbook#schedule" }
    )
    let supported = CitedClaim(
        statement: "The Atlas launch review is scheduled.",
        citations: [
            Citation(
                sourceID: schedule.sourceID,
                passageID: schedule.passageID,
                quote: "launch review is scheduled"
            ),
        ]
    )
    let forged = CitedClaim(
        statement: "The review was cancelled.",
        citations: [
            Citation(
                sourceID: schedule.sourceID,
                passageID: schedule.passageID,
                quote: "the review was cancelled"
            ),
        ]
    )

    let validReport = CitationVerifier().verify([supported], against: bundle)
    let invalidReport = CitationVerifier().verify([forged], against: bundle)

    #expect(validReport.supportRate == 1)
    #expect(validReport.unsupportedClaimIndexes.isEmpty)
    #expect(invalidReport.supportRate == 0)
    #expect(invalidReport.unsupportedClaimIndexes == [0])
}

@Test("v2 evaluator measures cited claims against the retrieved context")
func v2RetrievalEvaluatorMeasuresCitedClaims() throws {
    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let report = try RetrievalEvaluator().evaluate(
        manifestURL: retrievalV2ManifestURL(),
        indexURL: root.appending(path: "evaluation.sqlite")
    )

    #expect(report.citedClaimQuoteSupport == 1)
    #expect(report.unansweredQueryIDs.isEmpty)
}

@Test("retrieval benchmark receipt records its warm policy and local operation identity")
func retrievalBenchmarkReceiptIsAuditable() throws {
    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let configuration = RetrievalBenchmarkConfiguration(
        warmupRunsPerQuery: 1,
        measuredRunsPerQuery: 2
    )

    let report = try RetrievalEvaluator().evaluate(
        manifestURL: retrievalV2ManifestURL(),
        indexURL: root.appending(path: "evaluation.sqlite"),
        benchmark: configuration
    )

    #expect(report.evaluatorVersion == "retrieval-evaluator-v2")
    #expect(report.corpusPassageCount == 30)
    #expect(report.queryCount == 10)
    #expect(report.warmupRunsPerQuery == 1)
    #expect(report.measuredRunsPerQuery == 2)
    #expect(report.operation == "retrieve+context+exact-citation-availability")
    #expect(report.emptyResultQueryIDs.isEmpty)
    #expect(report.latencyDistribution.sampleCount == 20)
    #expect(!report.indexFingerprint.isEmpty)
    #expect(!report.runtimeIdentity.isEmpty)
}

@Test("frozen retrieval suite meets quality support and latency gates")
func frozenRetrievalSuiteMeetsGates() throws {
    let root = try retrievalTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let report = try RetrievalEvaluator().evaluate(
        manifestURL: retrievalV2ManifestURL(),
        indexURL: root.appending(path: "evaluation.sqlite")
    )

    #expect(report.recallAt10 >= 0.85)
    #expect(report.meanReciprocalRank >= 0.70)
    #expect(report.citedSourceSupport >= 0.95)
    #expect(report.latencyP95Milliseconds < 500)
    #expect(report.unansweredQueryIDs.isEmpty)
    #expect(report.queryResults.count == 10)
    #expect(Set(report.perModalityFailures.keys).isSuperset(of: [
        "text",
        "markdown",
        "code",
        "configuration",
        "transcript",
        "pdf",
        "image",
        "audio",
    ]))
}

private struct StaticSemanticLane: SemanticRetrievalLane {
    let values: [LaneCandidate]

    func candidates(for query: String, limit: Int) throws -> [LaneCandidate] {
        Array(values.prefix(limit))
    }
}

private final class RetrievalHarness {
    let root: URL
    let manifest: GoldenRetrievalManifest
    let index: FullTextIndex

    init() throws {
        root = try retrievalTemporaryDirectory()
        let data = try Data(contentsOf: retrievalV2ManifestURL())
        manifest = try GoldenRetrievalManifest.decode(data)
        index = try FullTextIndex(
            databaseURL: root.appending(path: "retrieval.sqlite"),
            fingerprint: GoldenRetrievalManifest.sha256(of: data)
        )
    }

    func remove() {
        try? index.close()
        try? FileManager.default.removeItem(at: root)
    }
}

private func retrievalManifestURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/Retrieval/manifest.json")
}

private func retrievalV2ManifestURL() -> URL {
    retrievalManifestURL()
        .deletingLastPathComponent()
        .appending(path: "v2/manifest.json")
}

private func projectContractManifestURL() -> URL {
    retrievalManifestURL()
        .deletingLastPathComponent()
        .appending(path: "project-contract-v1/manifest.json")
}

private func retrievalTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-retrieval-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
