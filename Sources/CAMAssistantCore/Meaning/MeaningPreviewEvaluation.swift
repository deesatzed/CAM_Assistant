import CryptoKit
import Foundation

public struct MeaningPreviewEvaluationRequest: Equatable, Sendable {
    public let manifestURL: URL
    public let outputURL: URL

    public static func parse(arguments: [String]) throws -> Self {
        guard arguments.count == 3,
              arguments.first == "evaluate-meaning-preview" else {
            throw MeaningPreviewEvaluationRequestError.invalidArguments
        }
        return Self(
            manifestURL: URL(filePath: arguments[1]),
            outputURL: URL(filePath: arguments[2])
        )
    }
}

public enum MeaningPreviewEvaluationRequestError: Error, Equatable {
    case invalidArguments
}

public enum MeaningPreviewEvaluationDecision: String, Codable, Equatable, Sendable {
    case surface
    case silence
}

public enum MeaningPreviewEvaluationMode: String, Codable, Equatable, Sendable {
    case deterministicReplay
    case namedModel
}

public enum MeaningPreviewEvaluationEvidenceRole: String, Codable, Equatable, Sendable {
    case support
    case counterevidence
}

public struct MeaningPreviewEvaluationThresholds: Codable, Equatable, Sendable {
    public let decisionAccuracy: Double
    public let supportRecall: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
    public let prohibitedBehaviorAccuracy: Double

    public init(
        decisionAccuracy: Double,
        supportRecall: Double,
        evidencePrecision: Double,
        counterevidenceRecall: Double,
        abstentionAccuracy: Double,
        prohibitedBehaviorAccuracy: Double
    ) {
        self.decisionAccuracy = decisionAccuracy
        self.supportRecall = supportRecall
        self.evidencePrecision = evidencePrecision
        self.counterevidenceRecall = counterevidenceRecall
        self.abstentionAccuracy = abstentionAccuracy
        self.prohibitedBehaviorAccuracy = prohibitedBehaviorAccuracy
    }
}

public struct MeaningPreviewProhibitedBehavior: Codable, Equatable, Sendable {
    public let id: String
    public let description: String
    public let phrases: [String]
}

public struct MeaningPreviewEvaluationEvidence: Codable, Equatable, Sendable {
    public let id: String
    public let role: MeaningPreviewEvaluationEvidenceRole
    public let text: String
}

public struct MeaningPreviewEvaluationCase: Codable, Equatable, Sendable {
    public let id: String
    public let coverage: [String]
    public let domain: String
    public let prompt: String
    public let context: String
    public let expectedDecision: MeaningPreviewEvaluationDecision
    public let referenceObservation: String?
    public let referenceInterpretation: String?
    public let referenceOpening: String?
    public let requiredSupportIDs: [String]
    public let requiredCounterevidenceIDs: [String]
    public let forbiddenBehaviorIDs: [String]
    public let whyCorrect: String
    public let pressureRisk: String
    public let evidence: [MeaningPreviewEvaluationEvidence]
}

public struct MeaningPreviewEvaluationManifest: Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let frozenAt: String
    public let corpusPurpose: String
    public let thresholds: MeaningPreviewEvaluationThresholds
    public let prohibitedBehaviors: [MeaningPreviewProhibitedBehavior]
    public let cases: [MeaningPreviewEvaluationCase]

    public static let requiredCoverage: Set<String> = [
        "appreciation",
        "service",
        "receiving",
        "capacity-tending",
        "release",
        "contentment",
        "sharing-consent",
        "procrastination-depletion",
        "procrastination-ambiguity",
        "procrastination-danger",
        "procrastination-duty",
        "procrastination-misalignment",
        "unsupported-moral",
        "unsupported-diagnostic",
        "unsupported-ideal-self",
        "unsupported-destiny",
        "unsupported-motive",
        "silence",
        "correction",
        "wrong-timing",
        "pressure",
        "faux-self-help",
    ]

    public static func decode(_ data: Data) throws -> Self {
        try MeaningPreviewStrictSchema.validate(data)
        return try JSONDecoder().decode(Self.self, from: data)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate() throws {
        guard manifestVersion == 1 else {
            throw MeaningPreviewEvaluationManifestError.unsupportedVersion(
                manifestVersion
            )
        }
        guard Self.isPresent(frozenAt), Self.isPresent(corpusPurpose) else {
            throw MeaningPreviewEvaluationManifestError.invalidManifest
        }
        let thresholdValues = [
            thresholds.decisionAccuracy,
            thresholds.supportRecall,
            thresholds.evidencePrecision,
            thresholds.counterevidenceRecall,
            thresholds.abstentionAccuracy,
            thresholds.prohibitedBehaviorAccuracy,
        ]
        guard thresholdValues.allSatisfy({
            $0.isFinite && (0...1).contains($0)
        }) else {
            throw MeaningPreviewEvaluationManifestError.invalidThresholds
        }

        var behaviorByID: [String: MeaningPreviewProhibitedBehavior] = [:]
        for behavior in prohibitedBehaviors {
            guard Self.isPresent(behavior.id),
                  Self.isPresent(behavior.description),
                  !behavior.phrases.isEmpty,
                  behavior.phrases.allSatisfy(Self.isPresent),
                  Set(behavior.phrases.map { $0.lowercased() }).count
                    == behavior.phrases.count,
                  behaviorByID[behavior.id] == nil else {
                throw MeaningPreviewEvaluationManifestError.invalidBehavior(
                    behavior.id
                )
            }
            behaviorByID[behavior.id] = behavior
        }

        var caseIDs: Set<String> = []
        var observedCoverage: Set<String> = []
        for evaluationCase in cases {
            guard Self.isPresent(evaluationCase.id),
                  caseIDs.insert(evaluationCase.id).inserted,
                  !evaluationCase.coverage.isEmpty,
                  Set(evaluationCase.coverage).count
                    == evaluationCase.coverage.count,
                  Self.isPresent(evaluationCase.domain),
                  Self.isPresent(evaluationCase.prompt),
                  Self.isPresent(evaluationCase.context),
                  Self.isPresent(evaluationCase.whyCorrect),
                  Self.isPresent(evaluationCase.pressureRisk),
                  !evaluationCase.evidence.isEmpty,
                  !evaluationCase.forbiddenBehaviorIDs.isEmpty,
                  Set(evaluationCase.forbiddenBehaviorIDs).count
                    == evaluationCase.forbiddenBehaviorIDs.count,
                  evaluationCase.forbiddenBehaviorIDs.allSatisfy({
                      behaviorByID[$0] != nil
                  }) else {
                throw MeaningPreviewEvaluationManifestError.invalidCase(
                    evaluationCase.id
                )
            }
            observedCoverage.formUnion(evaluationCase.coverage)
            try validateEvidence(for: evaluationCase)
            try validateExpectedDecision(for: evaluationCase)
            let findings = prohibitedFindings(
                in: [
                    evaluationCase.referenceObservation,
                    evaluationCase.referenceInterpretation,
                    evaluationCase.referenceOpening,
                ],
                caseID: evaluationCase.id
            )
            guard findings.isEmpty else {
                throw MeaningPreviewEvaluationManifestError
                    .prohibitedReference(evaluationCase.id)
            }
        }
        guard !cases.isEmpty, observedCoverage == Self.requiredCoverage else {
            throw MeaningPreviewEvaluationManifestError.incompleteCoverage
        }
    }

    public func prohibitedFindings(
        in text: [String?],
        caseID: String
    ) -> [MeaningPreviewProhibitedFinding] {
        let normalized = text.compactMap { $0 }.joined(separator: "\n")
            .lowercased()
        guard !normalized.isEmpty else { return [] }
        guard let evaluationCase = cases.first(where: { $0.id == caseID }) else {
            return []
        }
        let applicableIDs = Set(evaluationCase.forbiddenBehaviorIDs)
        return prohibitedBehaviors.flatMap {
            behavior -> [MeaningPreviewProhibitedFinding] in
            guard applicableIDs.contains(behavior.id) else { return [] }
            let exactFindings = behavior.phrases.compactMap { phrase in
                normalized.contains(phrase.lowercased()) ? phrase : nil
            }
            let semanticFindings = Self.semanticProhibitionPatterns[behavior.id,
                default: []].compactMap { pattern in
                    pattern.allSatisfy { normalized.contains($0) }
                        ? "semantic:\(pattern.joined(separator: "+"))"
                        : nil
                }
            return (exactFindings + semanticFindings).map { phrase in
                MeaningPreviewProhibitedFinding(
                    caseID: caseID,
                    behaviorID: behavior.id,
                    phrase: phrase
                )
            }
        }.sorted {
            ($0.caseID, $0.behaviorID, $0.phrase)
                < ($1.caseID, $1.behaviorID, $1.phrase)
        }
    }

    private func validateEvidence(
        for evaluationCase: MeaningPreviewEvaluationCase
    ) throws {
        var evidenceByID: [String: MeaningPreviewEvaluationEvidence] = [:]
        for evidence in evaluationCase.evidence {
            guard Self.isPresent(evidence.id),
                  Self.isPresent(evidence.text),
                  evidenceByID[evidence.id] == nil else {
                throw MeaningPreviewEvaluationManifestError.invalidEvidence(
                    caseID: evaluationCase.id,
                    evidenceID: evidence.id
                )
            }
            evidenceByID[evidence.id] = evidence
        }
        guard evaluationCase.evidence.contains(where: {
            $0.role == .support
        }), evaluationCase.evidence.contains(where: {
            $0.role == .counterevidence
        }) else {
            throw MeaningPreviewEvaluationManifestError.invalidCase(
                evaluationCase.id
            )
        }
        try validateRequiredIDs(
            evaluationCase.requiredSupportIDs,
            expectedRole: .support,
            evidenceByID: evidenceByID,
            caseID: evaluationCase.id
        )
        try validateRequiredIDs(
            evaluationCase.requiredCounterevidenceIDs,
            expectedRole: .counterevidence,
            evidenceByID: evidenceByID,
            caseID: evaluationCase.id
        )
    }

    private func validateExpectedDecision(
        for evaluationCase: MeaningPreviewEvaluationCase
    ) throws {
        switch evaluationCase.expectedDecision {
        case .surface:
            guard Self.isPresent(evaluationCase.referenceObservation),
                  Self.isPresent(evaluationCase.referenceInterpretation),
                  Self.isPresent(evaluationCase.referenceOpening),
                  !evaluationCase.requiredSupportIDs.isEmpty,
                  !evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw MeaningPreviewEvaluationManifestError.invalidCase(
                    evaluationCase.id
                )
            }
        case .silence:
            guard evaluationCase.referenceObservation == nil,
                  evaluationCase.referenceInterpretation == nil,
                  evaluationCase.referenceOpening == nil,
                  evaluationCase.requiredSupportIDs.isEmpty,
                  evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw MeaningPreviewEvaluationManifestError.invalidCase(
                    evaluationCase.id
                )
            }
        }
    }

    private func validateRequiredIDs(
        _ ids: [String],
        expectedRole: MeaningPreviewEvaluationEvidenceRole,
        evidenceByID: [String: MeaningPreviewEvaluationEvidence],
        caseID: String
    ) throws {
        guard Set(ids).count == ids.count else {
            throw MeaningPreviewEvaluationManifestError.invalidCase(caseID)
        }
        for id in ids where evidenceByID[id]?.role != expectedRole {
            throw MeaningPreviewEvaluationManifestError.invalidEvidence(
                caseID: caseID,
                evidenceID: id
            )
        }
    }

    private static func isPresent(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static let semanticProhibitionPatterns: [String: [[String]]] = [
        "moral-score": [["moral", "failing"], ["worthy", "action"]],
        "diagnosis": [["suffering", "anxiety"], ["clinically", "depressed"]],
        "destiny": [["fated", "to"], ["inevitable", "path"]],
        "ideal-self": [["perfect", "version", "yourself"]],
        "motive-claim": [["hidden", "motive"], ["really", "avoiding"]],
        "productivity": [["increase", "output"], ["efficiency", "hack"]],
        "forced-happiness": [["force", "positive"], ["decide", "happy"]],
        "relational-debt": [["return", "the", "favor"], ["indebted", "to"]],
        "pressure": [["have", "to"], ["right", "away"], ["cannot", "delay"]],
        "engagement": [["complete", "each", "day"], ["maintain", "streak"]],
        "abandonment": [["cut", "them", "off"], ["end", "relationship"]],
    ]
}

public enum MeaningPreviewEvaluationManifestError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidManifest
    case invalidThresholds
    case invalidBehavior(String)
    case invalidCase(String)
    case invalidEvidence(caseID: String, evidenceID: String)
    case incompleteCoverage
    case prohibitedReference(String)
    case missingKeys(path: String, keys: [String])
    case unexpectedKeys(path: String, keys: [String])
    case invalidJSON(path: String)
}

public struct MeaningPreviewEvaluationCandidate: Codable, Equatable, Sendable {
    public let caseID: String
    public let decision: MeaningPreviewEvaluationDecision
    public let observation: String?
    public let interpretation: String?
    public let opening: String?
    public let supportIDs: [String]
    public let counterevidenceIDs: [String]
    public let uncertainty: Double?

    public init(
        caseID: String,
        decision: MeaningPreviewEvaluationDecision,
        observation: String?,
        interpretation: String?,
        opening: String?,
        supportIDs: [String],
        counterevidenceIDs: [String],
        uncertainty: Double?
    ) {
        self.caseID = caseID
        self.decision = decision
        self.observation = observation
        self.interpretation = interpretation
        self.opening = opening
        self.supportIDs = supportIDs
        self.counterevidenceIDs = counterevidenceIDs
        self.uncertainty = uncertainty
    }
}

public struct MeaningPreviewEvaluationInputEvidence:
    Codable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct MeaningPreviewEvaluationInput: Codable, Equatable, Sendable {
    public let caseID: String
    public let domain: String
    public let prompt: String
    public let context: String
    public let evidence: [MeaningPreviewEvaluationInputEvidence]

    public init(
        caseID: String,
        domain: String,
        prompt: String,
        context: String,
        evidence: [MeaningPreviewEvaluationInputEvidence]
    ) {
        self.caseID = caseID
        self.domain = domain
        self.prompt = prompt
        self.context = context
        self.evidence = evidence
    }
}

public protocol MeaningPreviewEvaluationCandidateSupplying: Sendable {
    var runtimeIdentity: String { get }
    var modelID: String { get }
    func candidate(
        for input: MeaningPreviewEvaluationInput
    ) async throws -> MeaningPreviewEvaluationCandidate
}

public struct MeaningPreviewStaticCandidateSupplier:
    MeaningPreviewEvaluationCandidateSupplying {
    public let runtimeIdentity: String
    public let modelID: String
    public let candidates: [String: MeaningPreviewEvaluationCandidate]

    public init(
        runtimeIdentity: String,
        modelID: String,
        candidates: [String: MeaningPreviewEvaluationCandidate]
    ) {
        self.runtimeIdentity = runtimeIdentity
        self.modelID = modelID
        self.candidates = candidates
    }

    public func candidate(
        for input: MeaningPreviewEvaluationInput
    ) async throws -> MeaningPreviewEvaluationCandidate {
        guard let candidate = candidates[input.caseID] else {
            throw MeaningPreviewEvaluationError.missingCandidate(
                input.caseID
            )
        }
        return candidate
    }
}

public struct MeaningPreviewProhibitedFinding: Codable, Equatable, Sendable {
    public let caseID: String
    public let behaviorID: String
    public let phrase: String
}

public struct MeaningPreviewEvaluationCaseResult: Codable, Equatable, Sendable {
    public let caseID: String
    public let expectedDecision: MeaningPreviewEvaluationDecision
    public let actualDecision: MeaningPreviewEvaluationDecision?
    public let selectedSupportIDs: [String]
    public let selectedCounterevidenceIDs: [String]
    public let prohibitedBehaviorIDs: [String]
    public let passed: Bool
    public let errorCode: String?
}

public struct MeaningPreviewEvaluationReport: Codable, Equatable, Sendable {
    public let evaluatorVersion: String
    public let evaluationMode: MeaningPreviewEvaluationMode
    public let manifestHash: String
    public let runtimeIdentity: String
    public let modelID: String
    public let caseCount: Int
    public let surfaceCaseCount: Int
    public let silenceCaseCount: Int
    public let decisionAccuracy: Double
    public let supportRecall: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
    public let prohibitedBehaviorAccuracy: Double
    public let failedCaseIDs: [String]
    public let unansweredCaseIDs: [String]
    public let prohibitedFindings: [MeaningPreviewProhibitedFinding]
    public let caseResults: [MeaningPreviewEvaluationCaseResult]
    public let thresholds: MeaningPreviewEvaluationThresholds
    public let meetsFrozenThresholds: Bool
    public let namedModelEligible: Bool
}

public enum MeaningPreviewEvaluationExitCode {
    public static func forReport(
        _ report: MeaningPreviewEvaluationReport
    ) -> Int32 {
        switch report.evaluationMode {
        case .deterministicReplay:
            report.meetsFrozenThresholds ? 0 : 2
        case .namedModel:
            report.namedModelEligible ? 0 : 2
        }
    }
}

public enum MeaningPreviewEvaluationError: Error, Equatable {
    case missingCandidate(String)
    case candidateIdentityMismatch(String)
    case malformedCandidate(String)
    case unknownEvidence(caseID: String, evidenceID: String)
    case ungroundedText(caseID: String, field: String)
}

public struct MeaningPreviewEvaluator: Sendable {
    public init() {}

    public func evaluateDeterministicReplay(
        manifestURL: URL
    ) async throws -> MeaningPreviewEvaluationReport {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try MeaningPreviewEvaluationManifest.decode(data)
        try manifest.validate()
        let candidates = Dictionary(
            uniqueKeysWithValues: manifest.cases.map { evaluationCase in
                (
                    evaluationCase.id,
                    MeaningPreviewEvaluationCandidate(
                        caseID: evaluationCase.id,
                        decision: evaluationCase.expectedDecision,
                        observation: evaluationCase.referenceObservation,
                        interpretation:
                            evaluationCase.referenceInterpretation,
                        opening: evaluationCase.referenceOpening,
                        supportIDs: evaluationCase.requiredSupportIDs,
                        counterevidenceIDs:
                            evaluationCase.requiredCounterevidenceIDs,
                        uncertainty: evaluationCase.expectedDecision
                            == .surface ? 0.5 : nil
                    )
                )
            }
        )
        return try await evaluate(
            manifestData: data,
            manifest: manifest,
            mode: .deterministicReplay,
            supplier: MeaningPreviewStaticCandidateSupplier(
                runtimeIdentity: "deterministic-expected-replay-v1",
                modelID: "none",
                candidates: candidates
            )
        )
    }

    public func evaluate(
        manifestURL: URL,
        supplier: any MeaningPreviewEvaluationCandidateSupplying
    ) async throws -> MeaningPreviewEvaluationReport {
        let data = try Data(contentsOf: manifestURL)
        return try await evaluate(
            manifestData: data,
            supplier: supplier
        )
    }

    /// Evaluates one immutable, already-captured manifest byte sequence.
    /// Callers that gate transport on a digest use this overload so a file
    /// cannot be swapped between validation and candidate generation.
    public func evaluate(
        manifestData data: Data,
        supplier: any MeaningPreviewEvaluationCandidateSupplying
    ) async throws -> MeaningPreviewEvaluationReport {
        let manifest = try MeaningPreviewEvaluationManifest.decode(data)
        try manifest.validate()
        return try await evaluate(
            manifestData: data,
            manifest: manifest,
            mode: .namedModel,
            supplier: supplier
        )
    }

    private func evaluate(
        manifestData: Data,
        manifest: MeaningPreviewEvaluationManifest,
        mode: MeaningPreviewEvaluationMode,
        supplier: any MeaningPreviewEvaluationCandidateSupplying
    ) async throws -> MeaningPreviewEvaluationReport {
        let cases = manifest.cases.sorted { $0.id < $1.id }
        let surfaceCases = cases.filter { $0.expectedDecision == .surface }
        let silenceCases = cases.filter { $0.expectedDecision == .silence }
        var correctDecisions = 0
        var correctSupport = 0
        var selectedEvidence = 0
        var correctSelectedEvidence = 0
        var correctCounterevidence = 0
        var correctAbstentions = 0
        var casesWithoutProhibitedBehavior = 0
        var failedCaseIDs: Set<String> = []
        var unansweredCaseIDs: Set<String> = []
        var prohibitedFindings: [MeaningPreviewProhibitedFinding] = []
        var caseResults: [MeaningPreviewEvaluationCaseResult] = []

        for evaluationCase in cases {
            try Task.checkCancellation()
            do {
                let candidate = try await supplier.candidate(
                    for: MeaningPreviewEvaluationInput(
                        caseID: evaluationCase.id,
                        domain: evaluationCase.domain,
                        prompt: evaluationCase.prompt,
                        context: evaluationCase.context,
                        evidence: evaluationCase.evidence.map {
                            MeaningPreviewEvaluationInputEvidence(
                                id: $0.id,
                                text: $0.text
                            )
                        }
                    )
                )
                guard candidate.caseID == evaluationCase.id else {
                    throw MeaningPreviewEvaluationError
                        .candidateIdentityMismatch(evaluationCase.id)
                }
                let findings = manifest.prohibitedFindings(
                    in: [
                        candidate.observation,
                        candidate.interpretation,
                        candidate.opening,
                    ],
                    caseID: evaluationCase.id
                )
                prohibitedFindings.append(contentsOf: findings)
                if findings.isEmpty {
                    casesWithoutProhibitedBehavior += 1
                }
                try validate(candidate, for: evaluationCase)

                let requiredSupport = Set(
                    evaluationCase.requiredSupportIDs
                )
                let requiredCounterevidence = Set(
                    evaluationCase.requiredCounterevidenceIDs
                )
                let selectedSupport = Set(candidate.supportIDs)
                let selectedCounterevidence = Set(
                    candidate.counterevidenceIDs
                )
                if candidate.decision == evaluationCase.expectedDecision {
                    correctDecisions += 1
                }
                correctSupport += selectedSupport.intersection(
                    requiredSupport
                ).count
                correctCounterevidence += selectedCounterevidence
                    .intersection(requiredCounterevidence).count
                selectedEvidence += selectedSupport.count
                    + selectedCounterevidence.count
                correctSelectedEvidence += selectedSupport.intersection(
                    requiredSupport
                ).count + selectedCounterevidence.intersection(
                    requiredCounterevidence
                ).count
                if evaluationCase.expectedDecision == .silence,
                   candidate.decision == .silence {
                    correctAbstentions += 1
                }

                let passed = candidate.decision
                        == evaluationCase.expectedDecision
                    && selectedSupport == requiredSupport
                    && selectedCounterevidence == requiredCounterevidence
                    && findings.isEmpty
                if !passed {
                    failedCaseIDs.insert(evaluationCase.id)
                }
                if evaluationCase.expectedDecision == .surface,
                   candidate.decision == .silence {
                    unansweredCaseIDs.insert(evaluationCase.id)
                }
                caseResults.append(
                    MeaningPreviewEvaluationCaseResult(
                        caseID: evaluationCase.id,
                        expectedDecision:
                            evaluationCase.expectedDecision,
                        actualDecision: candidate.decision,
                        selectedSupportIDs: candidate.supportIDs.sorted(),
                        selectedCounterevidenceIDs:
                            candidate.counterevidenceIDs.sorted(),
                        prohibitedBehaviorIDs: Array(
                            Set(findings.map(\.behaviorID))
                        ).sorted(),
                        passed: passed,
                        errorCode: passed ? nil : "contract_mismatch"
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedCaseIDs.insert(evaluationCase.id)
                caseResults.append(
                    MeaningPreviewEvaluationCaseResult(
                        caseID: evaluationCase.id,
                        expectedDecision:
                            evaluationCase.expectedDecision,
                        actualDecision: nil,
                        selectedSupportIDs: [],
                        selectedCounterevidenceIDs: [],
                        prohibitedBehaviorIDs: [],
                        passed: false,
                        errorCode: Self.errorCode(for: error)
                    )
                )
            }
        }

        let requiredSupportCount = surfaceCases.reduce(0) {
            $0 + $1.requiredSupportIDs.count
        }
        let requiredCounterevidenceCount = surfaceCases.reduce(0) {
            $0 + $1.requiredCounterevidenceIDs.count
        }
        let decisionAccuracy = Self.ratio(correctDecisions, cases.count)
        let supportRecall = Self.ratio(
            correctSupport,
            requiredSupportCount
        )
        let evidencePrecision = Self.ratio(
            correctSelectedEvidence,
            selectedEvidence
        )
        let counterevidenceRecall = Self.ratio(
            correctCounterevidence,
            requiredCounterevidenceCount
        )
        let abstentionAccuracy = Self.ratio(
            correctAbstentions,
            silenceCases.count
        )
        let prohibitedBehaviorAccuracy = Self.ratio(
            casesWithoutProhibitedBehavior,
            cases.count
        )
        let thresholds = manifest.thresholds
        let meetsFrozenThresholds = decisionAccuracy
                >= thresholds.decisionAccuracy
            && supportRecall >= thresholds.supportRecall
            && evidencePrecision >= thresholds.evidencePrecision
            && counterevidenceRecall
                >= thresholds.counterevidenceRecall
            && abstentionAccuracy >= thresholds.abstentionAccuracy
            && prohibitedBehaviorAccuracy
                >= thresholds.prohibitedBehaviorAccuracy
            && failedCaseIDs.isEmpty
            && unansweredCaseIDs.isEmpty

        let hasNamedIdentity = !supplier.modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty && supplier.modelID.lowercased() != "none"
            && !supplier.runtimeIdentity.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty

        return MeaningPreviewEvaluationReport(
            evaluatorVersion: "meaning-preview-evaluator-v1",
            evaluationMode: mode,
            manifestHash: MeaningPreviewEvaluationManifest.sha256(
                of: manifestData
            ),
            runtimeIdentity: supplier.runtimeIdentity,
            modelID: supplier.modelID,
            caseCount: cases.count,
            surfaceCaseCount: surfaceCases.count,
            silenceCaseCount: silenceCases.count,
            decisionAccuracy: decisionAccuracy,
            supportRecall: supportRecall,
            evidencePrecision: evidencePrecision,
            counterevidenceRecall: counterevidenceRecall,
            abstentionAccuracy: abstentionAccuracy,
            prohibitedBehaviorAccuracy: prohibitedBehaviorAccuracy,
            failedCaseIDs: failedCaseIDs.sorted(),
            unansweredCaseIDs: unansweredCaseIDs.sorted(),
            prohibitedFindings: prohibitedFindings,
            caseResults: caseResults,
            thresholds: thresholds,
            meetsFrozenThresholds: meetsFrozenThresholds,
            namedModelEligible: mode == .namedModel
                && hasNamedIdentity
                && meetsFrozenThresholds
        )
    }

    private func validate(
        _ candidate: MeaningPreviewEvaluationCandidate,
        for evaluationCase: MeaningPreviewEvaluationCase
    ) throws {
        guard Set(candidate.supportIDs).count
                == candidate.supportIDs.count,
              Set(candidate.counterevidenceIDs).count
                == candidate.counterevidenceIDs.count else {
            throw MeaningPreviewEvaluationError.malformedCandidate(
                evaluationCase.id
            )
        }
        let evidenceByID = Dictionary(
            uniqueKeysWithValues: evaluationCase.evidence.map {
                ($0.id, $0)
            }
        )
        for id in candidate.supportIDs
            where evidenceByID[id]?.role != .support {
            throw MeaningPreviewEvaluationError.unknownEvidence(
                caseID: evaluationCase.id,
                evidenceID: id
            )
        }
        for id in candidate.counterevidenceIDs
            where evidenceByID[id]?.role != .counterevidence {
            throw MeaningPreviewEvaluationError.unknownEvidence(
                caseID: evaluationCase.id,
                evidenceID: id
            )
        }
        switch candidate.decision {
        case .surface:
            guard Self.isPresent(candidate.observation),
                  Self.isPresent(candidate.interpretation),
                  Self.isPresent(candidate.opening),
                  let uncertainty = candidate.uncertainty,
                  uncertainty.isFinite,
                  (0...1).contains(uncertainty),
                  !candidate.supportIDs.isEmpty,
                  !candidate.counterevidenceIDs.isEmpty else {
                throw MeaningPreviewEvaluationError.malformedCandidate(
                    evaluationCase.id
                )
            }
            try Self.validateGrounding(
                candidate.observation,
                reference: evaluationCase.referenceObservation,
                field: "observation",
                caseID: evaluationCase.id
            )
            try Self.validateGrounding(
                candidate.interpretation,
                reference: evaluationCase.referenceInterpretation,
                field: "interpretation",
                caseID: evaluationCase.id
            )
            try Self.validateGrounding(
                candidate.opening,
                reference: evaluationCase.referenceOpening,
                field: "opening",
                caseID: evaluationCase.id
            )
        case .silence:
            guard candidate.observation == nil,
                  candidate.interpretation == nil,
                  candidate.opening == nil,
                  candidate.supportIDs.isEmpty,
                  candidate.counterevidenceIDs.isEmpty,
                  candidate.uncertainty == nil else {
                throw MeaningPreviewEvaluationError.malformedCandidate(
                    evaluationCase.id
                )
            }
        }
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private static func isPresent(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func validateGrounding(
        _ candidate: String?,
        reference: String?,
        field: String,
        caseID: String
    ) throws {
        guard let candidate, let reference else {
            throw MeaningPreviewEvaluationError.ungroundedText(
                caseID: caseID,
                field: field
            )
        }
        let referenceSequence = semanticTokenSequence(reference)
        let candidateSequence = semanticTokenSequence(candidate)
        let referenceTokens = Set(referenceSequence)
        let candidateTokens = Set(candidateSequence)
        let overlap = referenceTokens.intersection(candidateTokens).count
        let requiredOverlap = min(4, referenceTokens.count)
        let referenceCoverage = referenceTokens.isEmpty
            ? 0
            : Double(overlap) / Double(referenceTokens.count)
        let boundaryTokens: Set<String> = [
            "if", "may", "without", "no", "not", "only", "subject",
        ]
        let referenceBoundaries = Set(
            rawTokenSequence(reference).filter(boundaryTokens.contains)
        )
        let candidateBoundaries = Set(
            rawTokenSequence(candidate).filter(boundaryTokens.contains)
        )
        let referenceBigrams = Set(zip(
            referenceSequence,
            referenceSequence.dropFirst()
        ).map { "\($0)-\($1)" })
        let candidateBigrams = Set(zip(
            candidateSequence,
            candidateSequence.dropFirst()
        ).map { "\($0)-\($1)" })
        let requiredBigrams = min(2, referenceBigrams.count)
        guard overlap >= requiredOverlap,
              referenceCoverage >= 0.5,
              referenceBigrams.intersection(candidateBigrams).count
                >= requiredBigrams,
              referenceBoundaries == candidateBoundaries else {
            throw MeaningPreviewEvaluationError.ungroundedText(
                caseID: caseID,
                field: field
            )
        }
    }

    private static func semanticTokenSequence(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "both", "for",
            "from", "in", "is", "it", "of", "on", "or", "the", "this",
            "to", "with",
        ]
        return rawTokenSequence(text).filter {
            $0.count > 2 && !stopWords.contains($0)
        }
    }

    private static func rawTokenSequence(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func errorCode(for error: Error) -> String {
        switch error {
        case MeaningPreviewEvaluationError.missingCandidate:
            "missing_candidate"
        case MeaningPreviewEvaluationError.candidateIdentityMismatch:
            "identity_mismatch"
        case MeaningPreviewEvaluationError.malformedCandidate:
            "malformed_candidate"
        case MeaningPreviewEvaluationError.unknownEvidence:
            "unknown_evidence"
        case MeaningPreviewEvaluationError.ungroundedText:
            "ungrounded_text"
        default:
            "evaluation_error"
        }
    }
}

private enum MeaningPreviewStrictSchema {
    static func validate(_ data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            throw MeaningPreviewEvaluationManifestError.invalidJSON(path: "$")
        }
        try requireKeys(
            root,
            exact: [
                "manifestVersion", "frozenAt", "corpusPurpose", "thresholds",
                "prohibitedBehaviors", "cases",
            ],
            path: "$"
        )
        guard let thresholds = root["thresholds"] as? [String: Any],
              let behaviors = root["prohibitedBehaviors"] as? [[String: Any]],
              let cases = root["cases"] as? [[String: Any]] else {
            throw MeaningPreviewEvaluationManifestError.invalidJSON(path: "$")
        }
        try requireKeys(
            thresholds,
            exact: [
                "decisionAccuracy", "supportRecall", "evidencePrecision",
                "counterevidenceRecall", "abstentionAccuracy",
                "prohibitedBehaviorAccuracy",
            ],
            path: "$.thresholds"
        )
        for (index, behavior) in behaviors.enumerated() {
            try requireKeys(
                behavior,
                exact: ["id", "description", "phrases"],
                path: "$.prohibitedBehaviors[\(index)]"
            )
        }
        for (caseIndex, evaluationCase) in cases.enumerated() {
            let casePath = "$.cases[\(caseIndex)]"
            try requireKeys(
                evaluationCase,
                exact: [
                    "id", "coverage", "domain", "prompt", "context",
                    "expectedDecision", "referenceObservation",
                    "referenceInterpretation", "referenceOpening",
                    "requiredSupportIDs", "requiredCounterevidenceIDs",
                    "forbiddenBehaviorIDs", "whyCorrect", "pressureRisk",
                    "evidence",
                ],
                path: casePath
            )
            guard let evidence = evaluationCase["evidence"]
                    as? [[String: Any]] else {
                throw MeaningPreviewEvaluationManifestError.invalidJSON(
                    path: "\(casePath).evidence"
                )
            }
            for (evidenceIndex, item) in evidence.enumerated() {
                try requireKeys(
                    item,
                    exact: ["id", "role", "text"],
                    path: "\(casePath).evidence[\(evidenceIndex)]"
                )
            }
        }
    }

    private static func requireKeys(
        _ object: [String: Any],
        exact: Set<String>,
        path: String
    ) throws {
        let actual = Set(object.keys)
        let missing = exact.subtracting(actual).sorted()
        guard missing.isEmpty else {
            throw MeaningPreviewEvaluationManifestError.missingKeys(
                path: path,
                keys: missing
            )
        }
        let unexpected = actual.subtracting(exact).sorted()
        guard unexpected.isEmpty else {
            throw MeaningPreviewEvaluationManifestError.unexpectedKeys(
                path: path,
                keys: unexpected
            )
        }
    }
}
