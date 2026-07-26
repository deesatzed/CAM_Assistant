import Foundation

public struct Citation: Codable, Equatable, Sendable {
    public let sourceID: String
    public let passageID: String
    public let quote: String

    public init(sourceID: String, passageID: String, quote: String) {
        self.sourceID = sourceID
        self.passageID = passageID
        self.quote = quote
    }
}

public struct CitedClaim: Codable, Equatable, Sendable {
    public let statement: String
    public let citations: [Citation]

    public init(statement: String, citations: [Citation]) {
        self.statement = statement
        self.citations = citations
    }
}

public struct CitationVerificationReport: Codable, Equatable, Sendable {
    public let supportRate: Double
    public let unsupportedClaimIndexes: [Int]
}

public struct CitationVerifier {
    public init() {}

    public func verify(
        _ claims: [CitedClaim],
        against bundle: ContextBundle
    ) -> CitationVerificationReport {
        guard !claims.isEmpty else {
            return CitationVerificationReport(
                supportRate: 1,
                unsupportedClaimIndexes: []
            )
        }

        let unsupported = claims.indices.filter { index in
            let claim = claims[index]
            guard !claim.citations.isEmpty else { return true }
            return !claim.citations.allSatisfy { citation in
                guard !citation.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let passage = bundle.passages.first(where: {
                          $0.sourceID == citation.sourceID
                              && $0.passageID == citation.passageID
                      }) else {
                    return false
                }
                return passage.text.localizedCaseInsensitiveContains(citation.quote)
            }
        }
        return CitationVerificationReport(
            supportRate: Double(claims.count - unsupported.count) / Double(claims.count),
            unsupportedClaimIndexes: unsupported
        )
    }
}

public struct RetrievalQueryResult: Codable, Equatable, Sendable {
    public let queryID: String
    public let retrievedSourceIDs: [String]
    public let retrievedPassageIDs: [String]
    public let recallAt10: Double
    public let reciprocalRank: Double
    public let citedClaimQuoteSupport: Double
    public let latencyMilliseconds: Double
}

public struct RetrievalBenchmarkConfiguration: Codable, Equatable, Sendable {
    public let warmupRunsPerQuery: Int
    public let measuredRunsPerQuery: Int

    public init(warmupRunsPerQuery: Int, measuredRunsPerQuery: Int) {
        self.warmupRunsPerQuery = max(0, warmupRunsPerQuery)
        self.measuredRunsPerQuery = max(1, measuredRunsPerQuery)
    }

    public static let localDefault = Self(
        warmupRunsPerQuery: 3,
        measuredRunsPerQuery: 5
    )
}

public struct RetrievalLatencyDistribution: Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let minimumMilliseconds: Double
    public let medianMilliseconds: Double
    public let p95Milliseconds: Double
    public let maximumMilliseconds: Double
}

public struct RetrievalEvaluationReport: Codable, Equatable, Sendable {
    public let evaluatorVersion: String
    public let manifestHash: String
    public let indexFingerprint: String
    public let runtimeIdentity: String
    public let corpusPassageCount: Int
    public let queryCount: Int
    public let warmupRunsPerQuery: Int
    public let measuredRunsPerQuery: Int
    public let operation: String
    public let recallAt10: Double
    public let meanReciprocalRank: Double
    public let citedClaimQuoteSupport: Double
    public let latencyP95Milliseconds: Double
    public let latencyDistribution: RetrievalLatencyDistribution
    public let unansweredQueryIDs: [String]
    public let emptyResultQueryIDs: [String]
    public let perModalityFailures: [String: [String]]
    public let queryResults: [RetrievalQueryResult]

    // Compatibility for callers that still use the old, misleading report name.
    // This is claim-and-quote support, not a tautological source-provenance rate.
    public var citedSourceSupport: Double { citedClaimQuoteSupport }
}

public struct RetrievalEvaluator {
    public init() {}

    public func evaluate(
        manifestURL: URL,
        indexURL: URL,
        benchmark: RetrievalBenchmarkConfiguration = .localDefault
    ) throws -> RetrievalEvaluationReport {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try GoldenRetrievalManifest.decode(data)
        try manifest.validate()
        let manifestHash = GoldenRetrievalManifest.sha256(of: data)
        let fingerprint = IndexFingerprint(
            schemaVersion: 1,
            sourceManifestHash: manifestHash,
            tokenizer: "unicode61",
            preprocessing: "lowercase-stopwords-v1",
            chunking: "explicit-fixture-chunks-v2",
            semanticProvider: "none",
            semanticModel: "none",
            semanticDimensions: 0,
            fusionVersion: "hybrid-v1"
        )
        let index = try FullTextIndex(
            databaseURL: indexURL,
            fingerprint: fingerprint
        )
        defer { try? index.close() }
        try index.replace(with: manifest.indexedPassages)
        let retriever = HybridRetriever(fullTextIndex: index)

        var queryResults: [RetrievalQueryResult] = []
        var unanswered: [String] = []
        var emptyResults: [String] = []
        var measuredLatencies: [Double] = []
        var modalityFailures = Dictionary(
            uniqueKeysWithValues: Set(manifest.sources.map(\.modality))
                .map { ($0, [String]()) }
        )
        let sourcesByID = Dictionary(
            uniqueKeysWithValues: manifest.sources.map { ($0.id, $0) }
        )
        let passagesByID = Dictionary(
            uniqueKeysWithValues: manifest.indexedPassages.map { ($0.id, $0) }
        )
        var supportedClaims = 0
        var expectedClaims = 0

        for query in manifest.queries {
            for _ in 0..<benchmark.warmupRunsPerQuery {
                _ = try Self.runOperation(query: query, retriever: retriever)
            }
            let runs = try (0..<benchmark.measuredRunsPerQuery).map { _ in
                try Self.runOperation(query: query, retriever: retriever)
            }
            let run = runs[0]
            measuredLatencies.append(contentsOf: runs.map(\.latencyMilliseconds))
            let results = run.results
            let latency = Self.percentile(runs.map(\.latencyMilliseconds), percentile: 0.95)
            let retrievedIDs = results.map(\.sourceID)
            let retrievedPassageIDs = results.map(\.passageID)
            let relevant = manifest.manifestVersion == 1
                ? Set(query.relevantSourceIDs)
                : Set(query.relevantPassageIDs)
            let returnedRelevantIDs = manifest.manifestVersion == 1
                ? Set(retrievedIDs)
                : Set(retrievedPassageIDs)
            let found = returnedRelevantIDs.intersection(relevant)
            let recall = Double(found.count) / Double(relevant.count)
            let rankedIDs = manifest.manifestVersion == 1
                ? retrievedIDs
                : retrievedPassageIDs
            let firstRelevant = rankedIDs.firstIndex(where: relevant.contains)
            let reciprocalRank = firstRelevant.map { 1 / Double($0 + 1) } ?? 0

            if found.isEmpty {
                unanswered.append(query.id)
            }
            if results.isEmpty {
                emptyResults.append(query.id)
            }
            for missingID in relevant.subtracting(found) {
                let modality = manifest.manifestVersion == 1
                    ? sourcesByID[missingID]?.modality
                    : passagesByID[missingID]?.modality
                if let modality, !modalityFailures[modality, default: []].contains(query.id) {
                    modalityFailures[modality, default: []].append(query.id)
                }
            }

            let queryExpectedClaims = query.expectedClaims.count
            let querySupportedClaims = queryExpectedClaims
                - run.citationReport.unsupportedClaimIndexes.count
            expectedClaims += queryExpectedClaims
            supportedClaims += querySupportedClaims
            queryResults.append(
                RetrievalQueryResult(
                    queryID: query.id,
                    retrievedSourceIDs: retrievedIDs,
                    retrievedPassageIDs: retrievedPassageIDs,
                    recallAt10: recall,
                    reciprocalRank: reciprocalRank,
                    citedClaimQuoteSupport: queryExpectedClaims == 0
                        ? 0
                        : Double(querySupportedClaims) / Double(queryExpectedClaims),
                    latencyMilliseconds: latency
                )
            )
        }

        return RetrievalEvaluationReport(
            evaluatorVersion: "retrieval-evaluator-v2",
            manifestHash: manifestHash,
            indexFingerprint: fingerprint.identifier,
            runtimeIdentity: "\(BuildIdentity.bundleIdentifier)|\(ProcessInfo.processInfo.operatingSystemVersionString)",
            corpusPassageCount: manifest.indexedPassages.count,
            queryCount: manifest.queries.count,
            warmupRunsPerQuery: benchmark.warmupRunsPerQuery,
            measuredRunsPerQuery: benchmark.measuredRunsPerQuery,
            operation: "retrieve+context+exact-citation-availability",
            recallAt10: Self.mean(queryResults.map(\.recallAt10)),
            meanReciprocalRank: Self.mean(queryResults.map(\.reciprocalRank)),
            citedClaimQuoteSupport: expectedClaims == 0
                ? 0
                : Double(supportedClaims) / Double(expectedClaims),
            latencyP95Milliseconds: Self.percentile(measuredLatencies, percentile: 0.95),
            latencyDistribution: Self.distribution(measuredLatencies),
            unansweredQueryIDs: unanswered,
            emptyResultQueryIDs: emptyResults,
            perModalityFailures: modalityFailures,
            queryResults: queryResults
        )
    }

    private static func runOperation(
        query: GoldenRetrievalQuery,
        retriever: HybridRetriever
    ) throws -> RetrievalOperationRun {
        let start = ContinuousClock.now
        let results = try retriever.retrieve(query: query.text, limit: 10)
        let bundle = ContextAssembler().assemble(
            results,
            budget: ContextBudget(
                maxCharacters: 64_000,
                maxEstimatedTokens: 16_000,
                maxPassages: 10
            )
        )
        let citationReport = CitationVerifier().verify(
            query.expectedClaims,
            against: bundle
        )
        return RetrievalOperationRun(
            results: results,
            citationReport: citationReport,
            latencyMilliseconds: milliseconds(start.duration(to: .now))
        )
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = max(0, Int(ceil(Double(sorted.count) * percentile)) - 1)
        return sorted[index]
    }

    private static func distribution(_ values: [Double]) -> RetrievalLatencyDistribution {
        guard !values.isEmpty else {
            return RetrievalLatencyDistribution(
                sampleCount: 0,
                minimumMilliseconds: 0,
                medianMilliseconds: 0,
                p95Milliseconds: 0,
                maximumMilliseconds: 0
            )
        }
        let sorted = values.sorted()
        return RetrievalLatencyDistribution(
            sampleCount: sorted.count,
            minimumMilliseconds: sorted[0],
            medianMilliseconds: percentile(sorted, percentile: 0.5),
            p95Milliseconds: percentile(sorted, percentile: 0.95),
            maximumMilliseconds: sorted[sorted.count - 1]
        )
    }
}

private struct RetrievalOperationRun {
    let results: [RetrievalResult]
    let citationReport: CitationVerificationReport
    let latencyMilliseconds: Double
}
