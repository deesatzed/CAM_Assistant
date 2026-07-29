import CryptoKit
import Foundation

public struct RepositorySemanticEvaluationRequest:
    Equatable, Sendable {
    public let manifestURL: URL
    public let outputURL: URL
    public let assignment: ModelAssignment

    public static func parse(arguments: [String]) throws -> Self {
        guard arguments.count == 5,
              arguments.first == "evaluate-repository-semantic" else {
            throw RepositorySemanticEvaluationRequestError
                .invalidArguments
        }
        return try Self(
            manifestURL: URL(filePath: arguments[1]),
            outputURL: URL(filePath: arguments[2]),
            assignment: ModelAssignment(
                provider: .local,
                modelID: arguments[3],
                localEndpoint: arguments[4]
            )
        )
    }
}

public enum RepositorySemanticEvaluationRequestError:
    Error, Equatable {
    case invalidArguments
}

public enum RepositorySemanticExpectedOutcome:
    String, Codable, Equatable, Sendable {
    case observation
    case abstain
}

public enum RepositorySemanticEvidenceRole:
    String, Codable, Equatable, Sendable {
    case support
    case counterevidence
}

public struct RepositorySemanticEvaluationThresholds:
    Codable, Equatable, Sendable {
    public let observationRecall: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
}

public struct RepositorySemanticEvidence:
    Codable, Equatable, Sendable {
    public let id: String
    public let snapshotCommit: String
    public let filePath: String
    public let line: Int
    public let symbol: String
    public let role: RepositorySemanticEvidenceRole
    public let excerpt: String
}

public struct RepositorySemanticEvaluationCase:
    Codable, Equatable, Sendable {
    public let id: String
    public let snapshotCommit: String
    public let license: String
    public let prompt: String
    public let expectedOutcome: RepositorySemanticExpectedOutcome
    public let requiredConceptGroups: [[String]]
    public let requiredSupportIDs: [String]
    public let requiredCounterevidenceIDs: [String]
    public let evidence: [RepositorySemanticEvidence]
}

public struct RepositorySemanticEvaluationManifest:
    Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let frozenAt: String
    public let corpusPurpose: String
    public let thresholds: RepositorySemanticEvaluationThresholds
    public let cases: [RepositorySemanticEvaluationCase]

    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate() throws {
        guard (1...2).contains(manifestVersion) else {
            throw RepositorySemanticManifestError.unsupportedVersion(
                manifestVersion
            )
        }
        guard !frozenAt.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        !corpusPurpose.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        !cases.isEmpty else {
            throw RepositorySemanticManifestError.invalidManifest
        }
        try validate(thresholds)

        var caseIDs: Set<String> = []
        for evaluationCase in cases {
            guard caseIDs.insert(evaluationCase.id).inserted else {
                throw RepositorySemanticManifestError.duplicateCaseID(
                    evaluationCase.id
                )
            }
            try validate(evaluationCase)
        }
    }

    private func validate(
        _ thresholds: RepositorySemanticEvaluationThresholds
    ) throws {
        let values = [
            thresholds.observationRecall,
            thresholds.evidencePrecision,
            thresholds.counterevidenceRecall,
            thresholds.abstentionAccuracy,
        ]
        guard values.allSatisfy({
            $0.isFinite && (0...1).contains($0)
        }) else {
            throw RepositorySemanticManifestError.invalidThresholds
        }
    }

    private func validate(
        _ evaluationCase: RepositorySemanticEvaluationCase
    ) throws {
        guard !evaluationCase.id.isEmpty,
              Self.isCommit(evaluationCase.snapshotCommit),
              !evaluationCase.license.isEmpty,
              !evaluationCase.prompt.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              !evaluationCase.evidence.isEmpty else {
            throw RepositorySemanticManifestError.invalidCase(
                evaluationCase.id
            )
        }

        var evidenceByID: [String: RepositorySemanticEvidence] = [:]
        for evidence in evaluationCase.evidence {
            guard !evidence.id.isEmpty,
                  evidenceByID[evidence.id] == nil,
                  evidence.snapshotCommit == evaluationCase.snapshotCommit,
                  !evidence.filePath.isEmpty,
                  !evidence.filePath.hasPrefix("/"),
                  !evidence.filePath.split(separator: "/").contains(".."),
                  evidence.line > 0,
                  !evidence.symbol.isEmpty,
                  !evidence.excerpt.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ).isEmpty else {
                throw RepositorySemanticManifestError.invalidEvidence(
                    evidence.id
                )
            }
            evidenceByID[evidence.id] = evidence
        }

        switch evaluationCase.expectedOutcome {
        case .observation:
            guard !evaluationCase.requiredConceptGroups.isEmpty,
                  evaluationCase.requiredConceptGroups.allSatisfy({
                      !$0.isEmpty && $0.allSatisfy {
                          !$0.trimmingCharacters(
                              in: .whitespacesAndNewlines
                          ).isEmpty
                      }
                  }),
                  !evaluationCase.requiredSupportIDs.isEmpty,
                  !evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw RepositorySemanticManifestError.invalidCase(
                    evaluationCase.id
                )
            }
            try validate(
                evaluationCase.requiredSupportIDs,
                role: .support,
                evidenceByID: evidenceByID,
                caseID: evaluationCase.id
            )
            try validate(
                evaluationCase.requiredCounterevidenceIDs,
                role: .counterevidence,
                evidenceByID: evidenceByID,
                caseID: evaluationCase.id
            )
        case .abstain:
            guard evaluationCase.requiredConceptGroups.isEmpty,
                  evaluationCase.requiredSupportIDs.isEmpty,
                  evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw RepositorySemanticManifestError.invalidCase(
                    evaluationCase.id
                )
            }
        }
    }

    private func validate(
        _ ids: [String],
        role: RepositorySemanticEvidenceRole,
        evidenceByID: [String: RepositorySemanticEvidence],
        caseID: String
    ) throws {
        guard Set(ids).count == ids.count,
              ids.allSatisfy({ evidenceByID[$0]?.role == role }) else {
            throw RepositorySemanticManifestError.invalidCase(caseID)
        }
    }

    private static func isCommit(_ value: String) -> Bool {
        value.count == 40 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef").contains($0)
        }
    }
}

public enum RepositorySemanticManifestError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidManifest
    case invalidThresholds
    case duplicateCaseID(String)
    case invalidCase(String)
    case invalidEvidence(String)
}

public struct RepositorySemanticCandidate: Equatable, Sendable {
    public let snapshotCommit: String
    public let statement: String
    public let supportIDs: [String]
    public let counterevidenceIDs: [String]
    public let confidence: Double
    public let runtimeIdentity: String
    public let modelID: String
    public let retention: ResearchRetention

    public init(
        snapshotCommit: String,
        statement: String,
        supportIDs: [String],
        counterevidenceIDs: [String],
        confidence: Double,
        runtimeIdentity: String,
        modelID: String,
        retention: ResearchRetention
    ) {
        self.snapshotCommit = snapshotCommit
        self.statement = statement
        self.supportIDs = supportIDs
        self.counterevidenceIDs = counterevidenceIDs
        self.confidence = confidence
        self.runtimeIdentity = runtimeIdentity
        self.modelID = modelID
        self.retention = retention
    }

    public static func abstention(
        snapshotCommit: String,
        runtimeIdentity: String,
        modelID: String
    ) -> Self {
        Self(
            snapshotCommit: snapshotCommit,
            statement: "",
            supportIDs: [],
            counterevidenceIDs: [],
            confidence: 0,
            runtimeIdentity: runtimeIdentity,
            modelID: modelID,
            retention: .ephemeral
        )
    }
}

public struct RepositorySemanticValidatedCandidate:
    Equatable, Sendable {
    public let caseID: String
    public let snapshotCommit: String
    public let license: String
    public let statement: String
    public let support: [RepositorySemanticEvidence]
    public let counterevidence: [RepositorySemanticEvidence]
    public let confidence: Double
    public let runtimeIdentity: String
    public let modelID: String
    public let retention: ResearchRetention

    public func ideaCard(
        id: String,
        title: String,
        rejectedAlternatives: [String],
        validationExperiment: String
    ) throws -> RepositoryIdeaCard {
        let alternatives = rejectedAlternatives.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !alternatives.isEmpty,
              alternatives.allSatisfy({ !$0.isEmpty }) else {
            throw RepositoryIdeaError.missingRejectedAlternatives
        }
        let experiment = validationExperiment.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !experiment.isEmpty else {
            throw RepositoryIdeaError.invalidCard
        }
        let supportObservations = support.map {
            RepositoryObservation(
                snapshotCommit: $0.snapshotCommit,
                filePath: $0.filePath,
                line: $0.line,
                symbol: $0.symbol,
                statement: $0.excerpt
            )
        }
        let counterevidenceObservations = counterevidence.map {
            RepositoryObservation(
                snapshotCommit: $0.snapshotCommit,
                filePath: $0.filePath,
                line: $0.line,
                symbol: $0.symbol,
                statement: $0.excerpt
            )
        }
        return try RepositoryIdeaCard(
            id: id,
            title: title,
            rationale: statement,
            evidence: supportObservations,
            counterevidence: counterevidence.map(\.excerpt),
            counterevidenceCitations: counterevidenceObservations,
            rejectedAlternatives: alternatives,
            confidence: confidence,
            license: license,
            validationExperiment: experiment
        )
    }
}

public struct RepositorySemanticCandidateValidator: Sendable {
    public init() {}

    public func validate(
        _ candidate: RepositorySemanticCandidate,
        for evaluationCase: RepositorySemanticEvaluationCase
    ) throws -> RepositorySemanticValidatedCandidate? {
        guard candidate.snapshotCommit == evaluationCase.snapshotCommit else {
            throw RepositorySemanticValidationError.snapshotMismatch
        }
        guard candidate.confidence.isFinite,
              (0...1).contains(candidate.confidence) else {
            throw RepositorySemanticValidationError.invalidConfidence
        }
        guard !candidate.runtimeIdentity.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        !candidate.modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        candidate.retention == .ephemeral else {
            throw RepositorySemanticValidationError.invalidIdentity
        }

        let statement = candidate.statement.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let hasNoEvidence = candidate.supportIDs.isEmpty
            && candidate.counterevidenceIDs.isEmpty
        if statement.isEmpty || hasNoEvidence {
            guard statement.isEmpty && hasNoEvidence else {
                throw RepositorySemanticValidationError.malformedCandidate
            }
            return nil
        }
        guard evaluationCase.expectedOutcome == .observation else {
            throw RepositorySemanticValidationError.expectedAbstention
        }
        guard Set(candidate.supportIDs).count
                == candidate.supportIDs.count,
              Set(candidate.counterevidenceIDs).count
                == candidate.counterevidenceIDs.count,
              Set(candidate.supportIDs).isDisjoint(
                with: candidate.counterevidenceIDs
              ) else {
            throw RepositorySemanticValidationError.duplicateEvidence
        }

        let evidenceByID = Dictionary(
            uniqueKeysWithValues: evaluationCase.evidence.map {
                ($0.id, $0)
            }
        )
        let support = try resolve(
            candidate.supportIDs,
            role: .support,
            evidenceByID: evidenceByID
        )
        let counterevidence = try resolve(
            candidate.counterevidenceIDs,
            role: .counterevidence,
            evidenceByID: evidenceByID
        )
        guard Set(evaluationCase.requiredSupportIDs).isSubset(
            of: candidate.supportIDs
        ) else {
            throw RepositorySemanticValidationError
                .missingRequiredEvidence
        }
        guard Set(evaluationCase.requiredCounterevidenceIDs).isSubset(
            of: candidate.counterevidenceIDs
        ) else {
            throw RepositorySemanticValidationError
                .missingRequiredCounterevidence
        }

        let normalizedStatement = Self.normalized(statement)
        guard evaluationCase.requiredConceptGroups.allSatisfy({ group in
            group.contains { alternative in
                normalizedStatement.contains(Self.normalized(alternative))
            }
        }) else {
            throw RepositorySemanticValidationError.missingRequiredConcept
        }

        return RepositorySemanticValidatedCandidate(
            caseID: evaluationCase.id,
            snapshotCommit: candidate.snapshotCommit,
            license: evaluationCase.license,
            statement: statement,
            support: support,
            counterevidence: counterevidence,
            confidence: candidate.confidence,
            runtimeIdentity: candidate.runtimeIdentity,
            modelID: candidate.modelID,
            retention: candidate.retention
        )
    }

    private func resolve(
        _ ids: [String],
        role: RepositorySemanticEvidenceRole,
        evidenceByID: [String: RepositorySemanticEvidence]
    ) throws -> [RepositorySemanticEvidence] {
        try ids.map { id in
            guard let evidence = evidenceByID[id] else {
                throw RepositorySemanticValidationError
                    .unknownEvidence(id)
            }
            guard evidence.role == role else {
                throw RepositorySemanticValidationError
                    .evidenceRoleMismatch(id)
            }
            return evidence
        }
    }

    private static func normalized(_ text: String) -> String {
        let scalars = text.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                ? Character(scalar)
                : " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

public enum RepositorySemanticValidationError: Error, Equatable {
    case snapshotMismatch
    case invalidConfidence
    case invalidIdentity
    case malformedCandidate
    case expectedAbstention
    case duplicateEvidence
    case unknownEvidence(String)
    case evidenceRoleMismatch(String)
    case missingRequiredEvidence
    case missingRequiredCounterevidence
    case missingRequiredConcept
}

public protocol RepositorySemanticCandidateGenerator: Sendable {
    var runtimeIdentity: String { get }
    var modelID: String { get }

    func generate(
        for evaluationCase: RepositorySemanticEvaluationCase
    ) async throws -> RepositorySemanticCandidate
}

public enum RepositorySemanticGeneratorError: Error, Equatable {
    case missingCandidate(String)
    case identityMismatch
}

public struct RepositorySemanticCaseResult:
    Codable, Equatable, Sendable {
    public let caseID: String
    public let expectedOutcome: RepositorySemanticExpectedOutcome
    public let supportIDs: [String]
    public let counterevidenceIDs: [String]
    public let confidence: Double?
    public let abstained: Bool
    public let passed: Bool
    public let errorCode: String?
}

public struct RepositorySemanticEvaluationReport:
    Codable, Equatable, Sendable {
    public let evaluatorVersion: String
    public let manifestHash: String
    public let runtimeIdentity: String
    public let modelID: String
    public let caseCount: Int
    public let observationCaseCount: Int
    public let abstentionCaseCount: Int
    public let observationRecall: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
    public let failedCaseIDs: [String]
    public let unansweredCaseIDs: [String]
    public let caseResults: [RepositorySemanticCaseResult]
    public let thresholds: RepositorySemanticEvaluationThresholds
    public let meetsFrozenThresholds: Bool
}

public enum RepositorySemanticEvaluationExitCode {
    public static func forReport(
        _ report: RepositorySemanticEvaluationReport
    ) -> Int32 {
        report.meetsFrozenThresholds ? 0 : 2
    }
}

public struct RepositorySemanticEvaluator: Sendable {
    public init() {}

    public func evaluate(
        manifestURL: URL,
        generator: any RepositorySemanticCandidateGenerator
    ) async throws -> RepositorySemanticEvaluationReport {
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try RepositorySemanticEvaluationManifest.decode(
            manifestData
        )
        try manifest.validate()

        let observationCases = manifest.cases.filter {
            $0.expectedOutcome == .observation
        }
        let abstentionCases = manifest.cases.filter {
            $0.expectedOutcome == .abstain
        }
        var acceptedObservationCount = 0
        var correctSupportCitations = 0
        var allSupportCitations = 0
        var citedRequiredCounterevidence = 0
        let allRequiredCounterevidence = observationCases.reduce(0) {
            $0 + $1.requiredCounterevidenceIDs.count
        }
        var correctAbstentionCount = 0
        var failedCaseIDs: [String] = []
        var unansweredCaseIDs: [String] = []
        var results: [RepositorySemanticCaseResult] = []
        let validator = RepositorySemanticCandidateValidator()

        for evaluationCase in manifest.cases {
            try Task.checkCancellation()
            do {
                let candidate = try await generator.generate(
                    for: evaluationCase
                )
                guard candidate.runtimeIdentity
                        == generator.runtimeIdentity,
                      candidate.modelID == generator.modelID else {
                    throw RepositorySemanticGeneratorError
                        .identityMismatch
                }
                let validated = try validator.validate(
                    candidate,
                    for: evaluationCase
                )

                if let validated {
                    acceptedObservationCount += 1
                    let requiredSupport = Set(
                        evaluationCase.requiredSupportIDs
                    )
                    correctSupportCitations += validated.support.filter {
                        requiredSupport.contains($0.id)
                    }.count
                    allSupportCitations += validated.support.count
                    let requiredCounterevidence = Set(
                        evaluationCase.requiredCounterevidenceIDs
                    )
                    citedRequiredCounterevidence += validated
                        .counterevidence
                        .filter {
                            requiredCounterevidence.contains($0.id)
                        }
                        .count
                    results.append(
                        RepositorySemanticCaseResult(
                            caseID: evaluationCase.id,
                            expectedOutcome:
                                evaluationCase.expectedOutcome,
                            supportIDs: validated.support.map(\.id),
                            counterevidenceIDs: validated
                                .counterevidence.map(\.id),
                            confidence: validated.confidence,
                            abstained: false,
                            passed: true,
                            errorCode: nil
                        )
                    )
                } else {
                    let passed = evaluationCase.expectedOutcome
                        == .abstain
                    if passed {
                        correctAbstentionCount += 1
                    } else {
                        unansweredCaseIDs.append(evaluationCase.id)
                    }
                    results.append(
                        RepositorySemanticCaseResult(
                            caseID: evaluationCase.id,
                            expectedOutcome:
                                evaluationCase.expectedOutcome,
                            supportIDs: [],
                            counterevidenceIDs: [],
                            confidence: nil,
                            abstained: true,
                            passed: passed,
                            errorCode: nil
                        )
                    )
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedCaseIDs.append(evaluationCase.id)
                results.append(
                    RepositorySemanticCaseResult(
                        caseID: evaluationCase.id,
                        expectedOutcome:
                            evaluationCase.expectedOutcome,
                        supportIDs: [],
                        counterevidenceIDs: [],
                        confidence: nil,
                        abstained: false,
                        passed: false,
                        errorCode: Self.errorCode(for: error)
                    )
                )
            }
        }

        let observationRecall = Self.ratio(
            acceptedObservationCount,
            observationCases.count
        )
        let evidencePrecision = Self.ratio(
            correctSupportCitations,
            allSupportCitations
        )
        let counterevidenceRecall = Self.ratio(
            citedRequiredCounterevidence,
            allRequiredCounterevidence
        )
        let abstentionAccuracy = Self.ratio(
            correctAbstentionCount,
            abstentionCases.count
        )
        let thresholds = manifest.thresholds
        let meetsThresholds = observationRecall
                >= thresholds.observationRecall
            && evidencePrecision >= thresholds.evidencePrecision
            && counterevidenceRecall
                >= thresholds.counterevidenceRecall
            && abstentionAccuracy >= thresholds.abstentionAccuracy
            && failedCaseIDs.isEmpty
            && unansweredCaseIDs.isEmpty

        return RepositorySemanticEvaluationReport(
            evaluatorVersion: "repository-semantic-evaluator-v2",
            manifestHash: RepositorySemanticEvaluationManifest.sha256(
                of: manifestData
            ),
            runtimeIdentity: generator.runtimeIdentity,
            modelID: generator.modelID,
            caseCount: manifest.cases.count,
            observationCaseCount: observationCases.count,
            abstentionCaseCount: abstentionCases.count,
            observationRecall: observationRecall,
            evidencePrecision: evidencePrecision,
            counterevidenceRecall: counterevidenceRecall,
            abstentionAccuracy: abstentionAccuracy,
            failedCaseIDs: failedCaseIDs.sorted(),
            unansweredCaseIDs: unansweredCaseIDs.sorted(),
            caseResults: results.sorted { $0.caseID < $1.caseID },
            thresholds: thresholds,
            meetsFrozenThresholds: meetsThresholds
        )
    }

    private static func ratio(
        _ numerator: Int,
        _ denominator: Int
    ) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    private static func errorCode(for error: Error) -> String {
        switch error {
        case RepositorySemanticValidationError.snapshotMismatch:
            "snapshot_mismatch"
        case RepositorySemanticValidationError.invalidConfidence:
            "invalid_confidence"
        case RepositorySemanticValidationError.invalidIdentity:
            "invalid_identity"
        case RepositorySemanticValidationError.malformedCandidate:
            "malformed_candidate"
        case RepositorySemanticValidationError.expectedAbstention:
            "expected_abstention"
        case RepositorySemanticValidationError.duplicateEvidence:
            "duplicate_evidence"
        case RepositorySemanticValidationError.unknownEvidence:
            "unknown_evidence"
        case RepositorySemanticValidationError.evidenceRoleMismatch:
            "evidence_role_mismatch"
        case RepositorySemanticValidationError.missingRequiredEvidence:
            "missing_required_evidence"
        case RepositorySemanticValidationError
            .missingRequiredCounterevidence:
            "missing_required_counterevidence"
        case RepositorySemanticValidationError.missingRequiredConcept:
            "missing_required_concept"
        case RepositorySemanticGeneratorError.missingCandidate:
            "missing_candidate"
        case RepositorySemanticGeneratorError.identityMismatch:
            "generator_identity_mismatch"
        default:
            "generator_error"
        }
    }
}

public enum RepositorySemanticLocalGeneratorError:
    Error, Equatable {
    case invalidAssignment
    case healthRequired
    case evidenceBoundsExceeded
    case transportUnavailable
    case httpStatus(Int)
    case invalidResponse
    case selectedModelUnavailable(String)
    case modelIdentityMismatch(expected: String, actual: String)
    case unknownEvidence(String)
    case malformedCandidate
}

public actor RepositorySemanticLocalGenerator:
    RepositorySemanticCandidateGenerator {
    public nonisolated let runtimeIdentity: String
    public nonisolated let modelID: String

    private static let maximumEvidenceCount = 64
    private static let maximumExcerptCharacters = 2_000
    private static let maximumRequestBytes = 64_000
    private static let maximumResponseBytes = 64_000

    private let endpointIdentity: String
    private let baseURL: URL
    private let transport: any LocalModelTransport
    private var healthVerified = false

    public init(
        assignment: ModelAssignment,
        transport: any LocalModelTransport = URLSessionLocalModelTransport()
    ) throws {
        guard assignment.provider == .local,
              let endpoint = assignment.localEndpoint,
              ModelAssignment.isSafeLocalEndpoint(endpoint),
              let baseURL = URL(string: endpoint) else {
            throw RepositorySemanticLocalGeneratorError.invalidAssignment
        }
        modelID = assignment.modelID
        endpointIdentity = endpoint.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        runtimeIdentity = "loopback:\(endpointIdentity)"
        self.baseURL = baseURL
        self.transport = transport
    }

    public func health() async throws -> LocalModelHealth {
        healthVerified = false
        let response = try await perform(
            LocalModelHTTPRequest(
                method: .get,
                url: baseURL.appending(path: "models")
            )
        )
        let catalog: RepositorySemanticModelListEnvelope
        do {
            catalog = try JSONDecoder().decode(
                RepositorySemanticModelListEnvelope.self,
                from: response.data
            )
        } catch {
            throw RepositorySemanticLocalGeneratorError.invalidResponse
        }
        guard catalog.data.contains(where: { $0.id == modelID }) else {
            throw RepositorySemanticLocalGeneratorError
                .selectedModelUnavailable(modelID)
        }
        healthVerified = true
        return LocalModelHealth(
            modelID: modelID,
            endpointIdentity: endpointIdentity,
            isAvailable: true
        )
    }

    public func generate(
        for evaluationCase: RepositorySemanticEvaluationCase
    ) async throws -> RepositorySemanticCandidate {
        guard healthVerified else {
            throw RepositorySemanticLocalGeneratorError.healthRequired
        }
        guard evaluationCase.evidence.count
                <= Self.maximumEvidenceCount,
              evaluationCase.evidence.allSatisfy({
                  $0.excerpt.count <= Self.maximumExcerptCharacters
              }) else {
            throw RepositorySemanticLocalGeneratorError
                .evidenceBoundsExceeded
        }

        let supportIDs = evaluationCase.evidence
            .filter { $0.role == .support }
            .map(\.id)
        let counterevidenceIDs = evaluationCase.evidence
            .filter { $0.role == .counterevidence }
            .map(\.id)
        let evidenceData = try JSONEncoder().encode(
            evaluationCase.evidence
        )
        let evidenceText = String(decoding: evidenceData, as: UTF8.self)
        let request = RepositorySemanticChatCompletionRequest(
            model: modelID,
            messages: [
                RepositorySemanticChatMessage(
                    role: "system",
                    content: """
                    Analyze only the supplied immutable repository evidence. Return exactly one JSON object with statement, support_ids, counterevidence_ids, and confidence. Cite support and important limiting counterevidence. If the evidence cannot support the requested semantic observation, return an empty statement, empty ID arrays, and confidence 0. Never invent evidence IDs. The result is an ephemeral candidate, not truth or permission to copy or execute code.

                    Snapshot commit: \(evaluationCase.snapshotCommit)
                    Evidence JSON: \(evidenceText)
                    """
                ),
                RepositorySemanticChatMessage(
                    role: "user",
                    content: evaluationCase.prompt
                ),
            ],
            stream: false,
            temperature: 0,
            maxTokens: 384,
            seed: 0,
            responseFormat: .semanticCandidate(
                supportIDs: supportIDs,
                counterevidenceIDs: counterevidenceIDs
            )
        )
        let body = try JSONEncoder().encode(request)
        guard body.count <= Self.maximumRequestBytes else {
            throw RepositorySemanticLocalGeneratorError
                .evidenceBoundsExceeded
        }
        let response = try await perform(
            LocalModelHTTPRequest(
                method: .post,
                url: baseURL.appending(path: "chat/completions"),
                headers: ["Content-Type": "application/json"],
                body: body
            )
        )
        let envelope: RepositorySemanticChatCompletionEnvelope
        do {
            envelope = try JSONDecoder().decode(
                RepositorySemanticChatCompletionEnvelope.self,
                from: response.data
            )
        } catch {
            throw RepositorySemanticLocalGeneratorError.invalidResponse
        }
        guard envelope.model == modelID else {
            throw RepositorySemanticLocalGeneratorError
                .modelIdentityMismatch(
                    expected: modelID,
                    actual: envelope.model
                )
        }
        guard let content = envelope.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let output = try? JSONDecoder().decode(
                  RepositorySemanticModelOutput.self,
                  from: contentData
              ) else {
            throw RepositorySemanticLocalGeneratorError.invalidResponse
        }

        let statement = output.statement.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let noEvidence = output.supportIDs.isEmpty
            && output.counterevidenceIDs.isEmpty
        guard output.confidence.isFinite,
              (0...1).contains(output.confidence),
              (statement.isEmpty && noEvidence)
                || (!statement.isEmpty && !output.supportIDs.isEmpty)
        else {
            throw RepositorySemanticLocalGeneratorError
                .malformedCandidate
        }

        let validEvidenceIDs = Set(evaluationCase.evidence.map(\.id))
        for id in output.supportIDs + output.counterevidenceIDs {
            guard validEvidenceIDs.contains(id) else {
                throw RepositorySemanticLocalGeneratorError
                    .unknownEvidence(id)
            }
        }

        return RepositorySemanticCandidate(
            snapshotCommit: evaluationCase.snapshotCommit,
            statement: statement,
            supportIDs: output.supportIDs,
            counterevidenceIDs: output.counterevidenceIDs,
            confidence: output.confidence,
            runtimeIdentity: runtimeIdentity,
            modelID: modelID,
            retention: .ephemeral
        )
    }

    private func perform(
        _ request: LocalModelHTTPRequest
    ) async throws -> LocalModelHTTPResponse {
        let response: LocalModelHTTPResponse
        do {
            response = try await transport.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositorySemanticLocalGeneratorError {
            throw error
        } catch {
            throw RepositorySemanticLocalGeneratorError
                .transportUnavailable
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RepositorySemanticLocalGeneratorError
                .httpStatus(response.statusCode)
        }
        guard response.data.count <= Self.maximumResponseBytes else {
            throw RepositorySemanticLocalGeneratorError.invalidResponse
        }
        return response
    }
}

private struct RepositorySemanticModelListEnvelope: Decodable {
    let data: [RepositorySemanticModelListItem]
}

private struct RepositorySemanticModelListItem: Decodable {
    let id: String
}

private struct RepositorySemanticChatMessage: Codable {
    let role: String
    let content: String
}

private struct RepositorySemanticChatCompletionRequest: Encodable {
    let model: String
    let messages: [RepositorySemanticChatMessage]
    let stream: Bool
    let temperature: Int
    let maxTokens: Int
    let seed: Int
    let responseFormat: RepositorySemanticResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
        case seed
        case responseFormat = "response_format"
    }
}

private struct RepositorySemanticResponseFormat: Encodable {
    let type: String
    let jsonSchema: RepositorySemanticJSONSchema

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    static func semanticCandidate(
        supportIDs: [String],
        counterevidenceIDs: [String]
    ) -> Self {
        Self(
            type: "json_schema",
            jsonSchema: RepositorySemanticJSONSchema(
                name: "repository_semantic_candidate",
                schema: RepositorySemanticCandidateSchema(
                    supportIDs: supportIDs,
                    counterevidenceIDs: counterevidenceIDs
                )
            )
        )
    }
}

private struct RepositorySemanticJSONSchema: Encodable {
    let name: String
    let schema: RepositorySemanticCandidateSchema
}

private struct RepositorySemanticCandidateSchema: Encodable {
    let type = "object"
    let properties: [String: RepositorySemanticSchemaProperty]
    let required = [
        "statement",
        "support_ids",
        "counterevidence_ids",
        "confidence",
    ]
    let additionalProperties = false

    init(
        supportIDs: [String],
        counterevidenceIDs: [String]
    ) {
        properties = [
            "statement": RepositorySemanticSchemaProperty(
                type: "string"
            ),
            "support_ids": RepositorySemanticSchemaProperty(
                type: "array",
                allowedValues: supportIDs
            ),
            "counterevidence_ids": RepositorySemanticSchemaProperty(
                type: "array",
                allowedValues: counterevidenceIDs
            ),
            "confidence": RepositorySemanticSchemaProperty(
                type: "number",
                minimum: 0,
                maximum: 1
            ),
        ]
    }
}

private struct RepositorySemanticSchemaProperty: Encodable {
    let type: String
    let items: RepositorySemanticSchemaItems?
    let minimum: Double?
    let maximum: Double?

    init(
        type: String,
        allowedValues: [String]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) {
        self.type = type
        items = allowedValues.map {
            RepositorySemanticSchemaItems(
                type: "string",
                allowedValues: $0
            )
        }
        self.minimum = minimum
        self.maximum = maximum
    }

    enum CodingKeys: String, CodingKey {
        case type
        case items
        case minimum
        case maximum
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(minimum, forKey: .minimum)
        try container.encodeIfPresent(maximum, forKey: .maximum)
    }
}

private struct RepositorySemanticSchemaItems: Encodable {
    let type: String
    let allowedValues: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case allowedValues = "enum"
    }
}

private struct RepositorySemanticChatCompletionEnvelope: Decodable {
    let model: String
    let choices: [RepositorySemanticChatChoice]
}

private struct RepositorySemanticChatChoice: Decodable {
    let message: RepositorySemanticChatMessage
}

private struct RepositorySemanticModelOutput: Decodable {
    let statement: String
    let supportIDs: [String]
    let counterevidenceIDs: [String]
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case statement
        case supportIDs = "support_ids"
        case counterevidenceIDs = "counterevidence_ids"
        case confidence
    }

    init(from decoder: Decoder) throws {
        let allKeys = try decoder.container(
            keyedBy: RepositorySemanticDynamicCodingKey.self
        ).allKeys.map(\.stringValue)
        let allowed = Set([
            "statement",
            "support_ids",
            "counterevidence_ids",
            "confidence",
        ])
        guard Set(allKeys).isSubset(of: allowed) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown semantic response key"
                )
            )
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statement = try container.decode(String.self, forKey: .statement)
        supportIDs = try container.decode(
            [String].self,
            forKey: .supportIDs
        )
        counterevidenceIDs = try container.decode(
            [String].self,
            forKey: .counterevidenceIDs
        )
        confidence = try container.decode(Double.self, forKey: .confidence)
    }
}

private struct RepositorySemanticDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
