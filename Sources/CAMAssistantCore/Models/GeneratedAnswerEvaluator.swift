import CryptoKit
import Foundation

public struct GeneratedAnswerEvaluationRequest: Equatable, Sendable {
    public let manifestURL: URL
    public let outputURL: URL
    public let assignment: ModelAssignment
    public let benchmark: GeneratedAnswerBenchmarkConfiguration

    public static func parse(arguments: [String]) throws -> Self {
        guard arguments.count >= 5,
              arguments.first == "evaluate-generated" else {
            throw GeneratedAnswerEvaluationRequestError.invalidArguments
        }
        var warmup = GeneratedAnswerBenchmarkConfiguration.localDefault
            .warmupRunsPerCase
        var measured = GeneratedAnswerBenchmarkConfiguration.localDefault
            .measuredRunsPerCase
        var index = 5
        while index < arguments.count {
            guard index + 1 < arguments.count,
                  let value = Int(arguments[index + 1]) else {
                throw GeneratedAnswerEvaluationRequestError.invalidArguments
            }
            switch arguments[index] {
            case "--warmup":
                guard value >= 0 else {
                    throw GeneratedAnswerEvaluationRequestError
                        .invalidArguments
                }
                warmup = value
            case "--measured":
                guard value > 0 else {
                    throw GeneratedAnswerEvaluationRequestError
                        .invalidArguments
                }
                measured = value
            default:
                throw GeneratedAnswerEvaluationRequestError.invalidArguments
            }
            index += 2
        }
        return Self(
            manifestURL: URL(filePath: arguments[1]),
            outputURL: URL(filePath: arguments[2]),
            assignment: try ModelAssignment(
                provider: .local,
                modelID: arguments[3],
                localEndpoint: arguments[4]
            ),
            benchmark: GeneratedAnswerBenchmarkConfiguration(
                warmupRunsPerCase: warmup,
                measuredRunsPerCase: measured
            )
        )
    }
}

public enum GeneratedAnswerEvaluationRequestError: Error, Equatable {
    case invalidArguments
}

public enum GeneratedAnswerExpectedOutcome: String, Codable, Equatable, Sendable {
    case answer
    case abstain
}

/// Latency gate shape for a frozen generated-answer corpus.
public enum GeneratedAnswerLatencyContract: String, Codable, Equatable, Sendable {
    /// v1: single warm end-to-end p95 gate (retrieve + generate).
    case endToEndV1 = "end-to-end-v1"
    /// v2: separate warm retrieval p95 and warm generation p95 gates.
    case splitV2 = "split-v2"
}

public struct GeneratedAnswerEvaluationThresholds:
    Codable, Equatable, Sendable {
    public let recallAt10: Double
    public let meanReciprocalRank: Double
    public let citedClaimSupport: Double
    public let abstentionAccuracy: Double
    /// Required for `end-to-end-v1`. Optional informational field for `split-v2`.
    public let warmEndToEndP95Milliseconds: Double?
    /// Required for `split-v2`.
    public let warmRetrievalP95Milliseconds: Double?
    /// Required for `split-v2`.
    public let warmGenerationP95Milliseconds: Double?

    public var latencyContract: GeneratedAnswerLatencyContract {
        if warmRetrievalP95Milliseconds != nil,
           warmGenerationP95Milliseconds != nil {
            return .splitV2
        }
        return .endToEndV1
    }
}

public struct GeneratedAnswerEvaluationPassage:
    Codable, Equatable, Sendable {
    public let id: String
    public let text: String
}

public struct GeneratedAnswerEvaluationSource:
    Codable, Equatable, Sendable {
    public let id: String
    public let modality: String
    public let authority: Double
    public let capturedAt: Double
    public let passages: [GeneratedAnswerEvaluationPassage]
}

public struct GeneratedAnswerEvaluationCase:
    Codable, Equatable, Sendable {
    public let id: String
    public let question: String
    public let expectedOutcome: GeneratedAnswerExpectedOutcome
    public let relevantPassageIDs: [String]
    public let expectedClaims: [CitedClaim]
}

public struct GeneratedAnswerEvaluationManifest:
    Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let frozenAt: String
    public let corpusPurpose: String
    public let thresholds: GeneratedAnswerEvaluationThresholds
    public let sources: [GeneratedAnswerEvaluationSource]
    public let cases: [GeneratedAnswerEvaluationCase]

    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate() throws {
        guard manifestVersion == 1 || manifestVersion == 2 else {
            throw GeneratedAnswerEvaluationManifestError.unsupportedVersion(
                manifestVersion
            )
        }
        guard !corpusPurpose.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw GeneratedAnswerEvaluationManifestError.blankCorpusPurpose
        }
        try Self.validate(thresholds, forManifestVersion: manifestVersion)

        let sourceIDs = sources.map(\.id)
        guard Set(sourceIDs).count == sourceIDs.count else {
            throw GeneratedAnswerEvaluationManifestError.duplicateSourceID
        }
        var passageByID: [String: (sourceID: String, text: String)] = [:]
        for source in sources {
            guard !source.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty, source.authority.isFinite,
                  (0...1).contains(source.authority),
                  source.capturedAt.isFinite, source.capturedAt >= 0,
                  !source.passages.isEmpty else {
                throw GeneratedAnswerEvaluationManifestError.invalidSource(
                    source.id
                )
            }
            for passage in source.passages {
                guard !passage.id.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                passage.id.hasPrefix("\(source.id)#"),
                !passage.text.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                passageByID[passage.id] == nil else {
                    throw GeneratedAnswerEvaluationManifestError.invalidPassage(
                        passage.id
                    )
                }
                passageByID[passage.id] = (source.id, passage.text)
            }
        }

        let caseIDs = cases.map(\.id)
        guard !cases.isEmpty, Set(caseIDs).count == caseIDs.count else {
            throw GeneratedAnswerEvaluationManifestError.duplicateCaseID
        }
        for evaluationCase in cases {
            guard !evaluationCase.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            !evaluationCase.question.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                throw GeneratedAnswerEvaluationManifestError.invalidCase(
                    evaluationCase.id
                )
            }
            switch evaluationCase.expectedOutcome {
            case .answer:
                guard !evaluationCase.relevantPassageIDs.isEmpty,
                      !evaluationCase.expectedClaims.isEmpty else {
                    throw GeneratedAnswerEvaluationManifestError.invalidCase(
                        evaluationCase.id
                    )
                }
            case .abstain:
                guard evaluationCase.relevantPassageIDs.isEmpty,
                      evaluationCase.expectedClaims.isEmpty else {
                    throw GeneratedAnswerEvaluationManifestError.invalidCase(
                        evaluationCase.id
                    )
                }
            }
            for passageID in evaluationCase.relevantPassageIDs
                where passageByID[passageID] == nil {
                throw GeneratedAnswerEvaluationManifestError
                    .unknownRelevantPassage(
                        caseID: evaluationCase.id,
                        passageID: passageID
                    )
            }
            for claim in evaluationCase.expectedClaims {
                guard !claim.statement.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty, !claim.citations.isEmpty else {
                    throw GeneratedAnswerEvaluationManifestError
                        .invalidExpectedClaim(evaluationCase.id)
                }
                for citation in claim.citations {
                    guard let passage = passageByID[citation.passageID],
                          passage.sourceID == citation.sourceID,
                          !citation.quote.trimmingCharacters(
                            in: .whitespacesAndNewlines
                          ).isEmpty,
                          passage.text.localizedCaseInsensitiveContains(
                            citation.quote
                          ) else {
                        throw GeneratedAnswerEvaluationManifestError
                            .invalidExpectedCitation(
                                caseID: evaluationCase.id,
                                passageID: citation.passageID
                            )
                    }
                }
            }
        }
    }

    public var indexedPassages: [IndexedPassage] {
        sources.flatMap { source in
            source.passages.map { passage in
                IndexedPassage(
                    id: passage.id,
                    sourceID: source.id,
                    modality: source.modality,
                    authority: source.authority,
                    capturedAt: source.capturedAt,
                    text: passage.text
                )
            }
        }
    }

    private static func validate(
        _ thresholds: GeneratedAnswerEvaluationThresholds,
        forManifestVersion version: Int
    ) throws {
        let rates = [
            thresholds.recallAt10,
            thresholds.meanReciprocalRank,
            thresholds.citedClaimSupport,
            thresholds.abstentionAccuracy,
        ]
        guard rates.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw GeneratedAnswerEvaluationManifestError.invalidThresholds
        }
        switch version {
        case 1:
            guard let endToEnd = thresholds.warmEndToEndP95Milliseconds,
                  endToEnd.isFinite, endToEnd > 0,
                  thresholds.warmRetrievalP95Milliseconds == nil,
                  thresholds.warmGenerationP95Milliseconds == nil else {
                throw GeneratedAnswerEvaluationManifestError.invalidThresholds
            }
        case 2:
            guard let retrieval = thresholds.warmRetrievalP95Milliseconds,
                  let generation = thresholds.warmGenerationP95Milliseconds,
                  retrieval.isFinite, retrieval > 0,
                  generation.isFinite, generation > 0 else {
                throw GeneratedAnswerEvaluationManifestError.invalidThresholds
            }
            if let endToEnd = thresholds.warmEndToEndP95Milliseconds {
                guard endToEnd.isFinite, endToEnd > 0 else {
                    throw GeneratedAnswerEvaluationManifestError.invalidThresholds
                }
            }
        default:
            throw GeneratedAnswerEvaluationManifestError.unsupportedVersion(
                version
            )
        }
    }
}

public enum GeneratedAnswerEvaluationManifestError: Error, Equatable {
    case unsupportedVersion(Int)
    case blankCorpusPurpose
    case invalidThresholds
    case duplicateSourceID
    case invalidSource(String)
    case invalidPassage(String)
    case duplicateCaseID
    case invalidCase(String)
    case unknownRelevantPassage(caseID: String, passageID: String)
    case invalidExpectedClaim(String)
    case invalidExpectedCitation(caseID: String, passageID: String)
}

public struct GeneratedAnswerBenchmarkConfiguration:
    Codable, Equatable, Sendable {
    public let warmupRunsPerCase: Int
    public let measuredRunsPerCase: Int

    public init(warmupRunsPerCase: Int, measuredRunsPerCase: Int) {
        self.warmupRunsPerCase = max(0, warmupRunsPerCase)
        self.measuredRunsPerCase = max(1, measuredRunsPerCase)
    }

    public static let localDefault = Self(
        warmupRunsPerCase: 1,
        measuredRunsPerCase: 3
    )
}

public struct GeneratedAnswerLatencyDistribution:
    Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let minimumMilliseconds: Double
    public let medianMilliseconds: Double
    public let p95Milliseconds: Double
    public let maximumMilliseconds: Double
}

public struct GeneratedAnswerCaseResult: Codable, Equatable, Sendable {
    public let caseID: String
    public let expectedOutcome: GeneratedAnswerExpectedOutcome
    public let retrievedPassageIDs: [String]
    public let generatedText: String?
    public let generatedPassageIDs: [String]
    public let claimSupport: Double
    public let abstained: Bool
    public let passed: Bool
    public let errorCode: String?
}

public struct GeneratedAnswerEvaluationReport:
    Codable, Equatable, Sendable {
    public let evaluatorVersion: String
    public let latencyContract: GeneratedAnswerLatencyContract
    public let environmentClass: String
    public let manifestHash: String
    public let indexFingerprint: String
    public let runtimeIdentity: String
    public let modelID: String
    public let endpointIdentity: String
    public let corpusPassageCount: Int
    public let caseCount: Int
    public let answerCaseCount: Int
    public let abstentionCaseCount: Int
    public let warmupRunsPerCase: Int
    public let measuredRunsPerCase: Int
    public let operation: String
    public let recallAt10: Double
    public let meanReciprocalRank: Double
    public let citedClaimSupport: Double
    public let abstentionAccuracy: Double
    public let warmEndToEndP95Milliseconds: Double
    public let warmRetrievalP95Milliseconds: Double
    public let warmGenerationP95Milliseconds: Double
    public let latencyDistribution: GeneratedAnswerLatencyDistribution
    public let retrievalLatencyDistribution: GeneratedAnswerLatencyDistribution
    public let generationLatencyDistribution: GeneratedAnswerLatencyDistribution
    public let unansweredCaseIDs: [String]
    public let failedCaseIDs: [String]
    public let caseResults: [GeneratedAnswerCaseResult]
    public let thresholds: GeneratedAnswerEvaluationThresholds
    public let meetsFrozenThresholds: Bool
    public let meetsQualityThresholds: Bool
    public let meetsLatencyThresholds: Bool
}

public enum GeneratedAnswerEvaluationExitCode {
    public static func forReport(
        _ report: GeneratedAnswerEvaluationReport
    ) -> Int32 {
        report.meetsFrozenThresholds ? 0 : 2
    }
}

public struct GeneratedAnswerEvaluator: Sendable {
    public init() {}

    public func evaluate(
        manifestURL: URL,
        indexURL: URL,
        assignment: ModelAssignment,
        transport: any LocalModelTransport = URLSessionLocalModelTransport(),
        benchmark: GeneratedAnswerBenchmarkConfiguration = .localDefault
    ) async throws -> GeneratedAnswerEvaluationReport {
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try GeneratedAnswerEvaluationManifest.decode(
            manifestData
        )
        try manifest.validate()
        let manifestHash = GeneratedAnswerEvaluationManifest.sha256(
            of: manifestData
        )
        let fingerprint = IndexFingerprint(
            schemaVersion: 1,
            sourceManifestHash: manifestHash,
            tokenizer: "unicode61",
            preprocessing: "lowercase-stopwords-v1",
            chunking: "explicit-generated-eval-v1",
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
        let client = try LocalModelClient(
            assignment: assignment,
            transport: transport
        )
        let health = try await client.health()

        var reciprocalRanks: [Double] = []
        var recalls: [Double] = []
        var expectedClaimCount = 0
        var supportedClaimCount = 0
        var expectedAbstentions = 0
        var correctAbstentions = 0
        var endToEndLatencies: [Double] = []
        var retrievalLatencies: [Double] = []
        var generationLatencies: [Double] = []
        var caseResults: [GeneratedAnswerCaseResult] = []
        var unanswered: [String] = []
        var failures: Set<String> = []

        for evaluationCase in manifest.cases {
            let initialRetrieval = try retriever.retrieve(
                query: evaluationCase.question,
                limit: 10
            )
            if evaluationCase.expectedOutcome == .answer {
                let relevant = Set(evaluationCase.relevantPassageIDs)
                let retrieved = initialRetrieval.map(\.passageID)
                let found = Set(retrieved).intersection(relevant)
                recalls.append(
                    Double(found.count) / Double(relevant.count)
                )
                reciprocalRanks.append(
                    retrieved.firstIndex(where: relevant.contains).map {
                        1 / Double($0 + 1)
                    } ?? 0
                )
                if found.isEmpty {
                    unanswered.append(evaluationCase.id)
                }
            }

            for _ in 0..<benchmark.warmupRunsPerCase {
                _ = try? await run(
                    evaluationCase,
                    retriever: retriever,
                    client: client
                )
            }

            var firstResult: GeneratedAnswerCaseResult?
            for _ in 0..<benchmark.measuredRunsPerCase {
                let started = ContinuousClock.now
                let timed: TimedGeneratedAnswerCaseResult
                do {
                    timed = try await run(
                        evaluationCase,
                        retriever: retriever,
                        client: client
                    )
                } catch {
                    timed = TimedGeneratedAnswerCaseResult(
                        result: GeneratedAnswerCaseResult(
                            caseID: evaluationCase.id,
                            expectedOutcome: evaluationCase.expectedOutcome,
                            retrievedPassageIDs: initialRetrieval.map(\.passageID),
                            generatedText: nil,
                            generatedPassageIDs: [],
                            claimSupport: 0,
                            abstained: false,
                            passed: false,
                            errorCode: String(describing: error)
                        ),
                        retrievalMilliseconds: 0,
                        generationMilliseconds: 0
                    )
                }
                let result = timed.result
                endToEndLatencies.append(
                    Self.milliseconds(started.duration(to: .now))
                )
                retrievalLatencies.append(timed.retrievalMilliseconds)
                generationLatencies.append(timed.generationMilliseconds)
                firstResult = firstResult ?? result
                if evaluationCase.expectedOutcome == .answer {
                    expectedClaimCount += evaluationCase.expectedClaims.count
                    supportedClaimCount += Int(
                        (
                            result.claimSupport
                                * Double(evaluationCase.expectedClaims.count)
                        ).rounded()
                    )
                } else {
                    expectedAbstentions += 1
                    if result.abstained {
                        correctAbstentions += 1
                    }
                }
                if !result.passed {
                    failures.insert(evaluationCase.id)
                }
            }
            if let firstResult {
                caseResults.append(firstResult)
            }
        }

        let distribution = Self.distribution(endToEndLatencies)
        let retrievalDistribution = Self.distribution(retrievalLatencies)
        let generationDistribution = Self.distribution(generationLatencies)
        let recallAt10 = Self.mean(recalls)
        let meanReciprocalRank = Self.mean(reciprocalRanks)
        let citedClaimSupport = expectedClaimCount == 0
            ? 1
            : Double(supportedClaimCount) / Double(expectedClaimCount)
        let abstentionAccuracy = expectedAbstentions == 0
            ? 1
            : Double(correctAbstentions) / Double(expectedAbstentions)
        let failedCaseIDs = failures.sorted()
        let meetsQualityThresholds =
            recallAt10 >= manifest.thresholds.recallAt10
            && meanReciprocalRank >= manifest.thresholds.meanReciprocalRank
            && citedClaimSupport >= manifest.thresholds.citedClaimSupport
            && abstentionAccuracy >= manifest.thresholds.abstentionAccuracy
            && failedCaseIDs.isEmpty
        let latencyContract = manifest.thresholds.latencyContract
        let meetsLatencyThresholds: Bool
        switch latencyContract {
        case .endToEndV1:
            let limit = manifest.thresholds.warmEndToEndP95Milliseconds ?? 0
            meetsLatencyThresholds = distribution.p95Milliseconds < limit
        case .splitV2:
            let retrievalLimit =
                manifest.thresholds.warmRetrievalP95Milliseconds ?? 0
            let generationLimit =
                manifest.thresholds.warmGenerationP95Milliseconds ?? 0
            meetsLatencyThresholds =
                retrievalDistribution.p95Milliseconds < retrievalLimit
                && generationDistribution.p95Milliseconds < generationLimit
        }
        let meetsFrozenThresholds =
            meetsQualityThresholds && meetsLatencyThresholds
        let evaluatorVersion = switch latencyContract {
        case .endToEndV1: "generated-answer-evaluator-v1"
        case .splitV2: "generated-answer-evaluator-v2"
        }
        return GeneratedAnswerEvaluationReport(
            evaluatorVersion: evaluatorVersion,
            latencyContract: latencyContract,
            environmentClass: Self.environmentClass(),
            manifestHash: manifestHash,
            indexFingerprint: fingerprint.digest,
            runtimeIdentity:
                "\(ProcessInfo.processInfo.operatingSystemVersionString); "
                    + "\(ProcessInfo.processInfo.processorCount) logical CPUs",
            modelID: health.modelID,
            endpointIdentity: health.endpointIdentity,
            corpusPassageCount: manifest.indexedPassages.count,
            caseCount: manifest.cases.count,
            answerCaseCount: recalls.count,
            abstentionCaseCount: manifest.cases.count - recalls.count,
            warmupRunsPerCase: benchmark.warmupRunsPerCase,
            measuredRunsPerCase: benchmark.measuredRunsPerCase,
            operation: "retrieve+context+selected-local-model+claim-citation-check",
            recallAt10: recallAt10,
            meanReciprocalRank: meanReciprocalRank,
            citedClaimSupport: citedClaimSupport,
            abstentionAccuracy: abstentionAccuracy,
            warmEndToEndP95Milliseconds: distribution.p95Milliseconds,
            warmRetrievalP95Milliseconds: retrievalDistribution.p95Milliseconds,
            warmGenerationP95Milliseconds:
                generationDistribution.p95Milliseconds,
            latencyDistribution: distribution,
            retrievalLatencyDistribution: retrievalDistribution,
            generationLatencyDistribution: generationDistribution,
            unansweredCaseIDs: unanswered.sorted(),
            failedCaseIDs: failedCaseIDs,
            caseResults: caseResults,
            thresholds: manifest.thresholds,
            meetsFrozenThresholds: meetsFrozenThresholds,
            meetsQualityThresholds: meetsQualityThresholds,
            meetsLatencyThresholds: meetsLatencyThresholds
        )
    }

    private struct TimedGeneratedAnswerCaseResult: Sendable {
        let result: GeneratedAnswerCaseResult
        let retrievalMilliseconds: Double
        let generationMilliseconds: Double
    }

    private func run(
        _ evaluationCase: GeneratedAnswerEvaluationCase,
        retriever: HybridRetriever,
        client: LocalModelClient
    ) async throws -> TimedGeneratedAnswerCaseResult {
        let retrievalStarted = ContinuousClock.now
        let results = try retriever.retrieve(
            query: evaluationCase.question,
            limit: 10
        )
        let retrievalMilliseconds = Self.milliseconds(
            retrievalStarted.duration(to: .now)
        )
        let context = ContextAssembler().assemble(
            results,
            budget: ContextBudget(
                maxCharacters: 8_000,
                maxEstimatedTokens: 2_000,
                maxPassages: 10
            )
        )
        let generationStarted = ContinuousClock.now
        let answer = try await client.generate(
            question: evaluationCase.question,
            context: context
        )
        let generationMilliseconds = Self.milliseconds(
            generationStarted.duration(to: .now)
        )
        let support = Self.claimSupport(
            expectedClaims: evaluationCase.expectedClaims,
            answer: answer
        )
        let passed: Bool
        switch evaluationCase.expectedOutcome {
        case .answer:
            passed = !answer.didAbstain
                && support == 1
        case .abstain:
            passed = answer.didAbstain
        }
        return TimedGeneratedAnswerCaseResult(
            result: GeneratedAnswerCaseResult(
                caseID: evaluationCase.id,
                expectedOutcome: evaluationCase.expectedOutcome,
                retrievedPassageIDs: results.map(\.passageID),
                generatedText: answer.text,
                generatedPassageIDs: answer.citations.map(\.passageID),
                claimSupport: support,
                abstained: answer.didAbstain,
                passed: passed,
                errorCode: nil
            ),
            retrievalMilliseconds: retrievalMilliseconds,
            generationMilliseconds: generationMilliseconds
        )
    }

    private static func environmentClass() -> String {
        #if arch(arm64)
        "apple-silicon-\(ProcessInfo.processInfo.processorCount)cpu"
        #else
        "non-arm-\(ProcessInfo.processInfo.processorCount)cpu"
        #endif
    }

    private static func claimSupport(
        expectedClaims: [CitedClaim],
        answer: LocalModelGeneratedAnswer
    ) -> Double {
        guard !expectedClaims.isEmpty else {
            return answer.didAbstain ? 1 : 0
        }
        let answerTokens = normalizedTokens(answer.text)
        let citedPassages = Set(answer.citations.map(\.passageID))
        let supported = expectedClaims.filter { claim in
            let expectedTokens = normalizedTokens(claim.statement)
            let tokenCoverage = expectedTokens.isEmpty
                ? 0
                : Double(expectedTokens.intersection(answerTokens).count)
                    / Double(expectedTokens.count)
            let expectedPassages = Set(claim.citations.map(\.passageID))
            return tokenCoverage >= 0.5
                && expectedPassages.isSubset(of: citedPassages)
        }.count
        return Double(supported) / Double(expectedClaims.count)
    }

    private static func normalizedTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "by", "for", "from",
            "in", "is", "it", "of", "on", "or", "the", "to", "with",
        ]
        return Set(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 && !stopwords.contains($0) }
        )
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 1 : values.reduce(0, +) / Double(values.count)
    }

    private static func distribution(
        _ values: [Double]
    ) -> GeneratedAnswerLatencyDistribution {
        let sorted = values.sorted()
        return GeneratedAnswerLatencyDistribution(
            sampleCount: sorted.count,
            minimumMilliseconds: sorted.first ?? 0,
            medianMilliseconds: percentile(sorted, 0.5),
            p95Milliseconds: percentile(sorted, 0.95),
            maximumMilliseconds: sorted.last ?? 0
        )
    }

    private static func percentile(
        _ sortedValues: [Double],
        _ percentile: Double
    ) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let index = Int(
            ceil(percentile * Double(sortedValues.count))
        ) - 1
        return sortedValues[max(0, min(index, sortedValues.count - 1))]
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
