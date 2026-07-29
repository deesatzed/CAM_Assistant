import CryptoKit
import Foundation

public struct RepositorySemanticV3EvaluationRequest:
    Equatable, Sendable {
    public let manifestURL: URL
    public let outputURL: URL
    public let assignment: ModelAssignment

    public static func parse(arguments: [String]) throws -> Self {
        guard arguments.count == 5,
              arguments.first
                == "evaluate-repository-semantic-v3" else {
            throw RepositorySemanticV3EvaluationRequestError
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

public enum RepositorySemanticV3EvaluationRequestError:
    Error, Equatable {
    case invalidArguments
}

public struct RepositorySemanticV3Thresholds:
    Codable, Equatable, Sendable {
    public let claimRecall: Double
    public let claimPrecision: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
}

public struct RepositorySemanticClaim:
    Codable, Equatable, Sendable {
    public let id: String
    public let description: String
}

public struct RepositorySemanticV3Case:
    Codable, Equatable, Sendable {
    public let id: String
    public let snapshotCommit: String
    public let license: String
    public let prompt: String
    public let expectedOutcome: RepositorySemanticExpectedOutcome
    public let claimCatalog: [RepositorySemanticClaim]
    public let requiredClaimIDs: [String]
    public let requiredSupportIDs: [String]
    public let requiredCounterevidenceIDs: [String]
    public let evidence: [RepositorySemanticEvidence]
}

public struct RepositorySemanticV3Manifest:
    Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let frozenAt: String
    public let corpusPurpose: String
    public let thresholds: RepositorySemanticV3Thresholds
    public let cases: [RepositorySemanticV3Case]

    public static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public func validate() throws {
        guard manifestVersion == 3 else {
            throw RepositorySemanticV3ManifestError.unsupportedVersion(
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
            throw RepositorySemanticV3ManifestError.invalidManifest
        }
        try validate(thresholds)

        var caseIDs: Set<String> = []
        for evaluationCase in cases {
            guard caseIDs.insert(evaluationCase.id).inserted else {
                throw RepositorySemanticV3ManifestError.duplicateCaseID(
                    evaluationCase.id
                )
            }
            try validate(evaluationCase)
        }
    }

    private func validate(
        _ thresholds: RepositorySemanticV3Thresholds
    ) throws {
        let values = [
            thresholds.claimRecall,
            thresholds.claimPrecision,
            thresholds.evidencePrecision,
            thresholds.counterevidenceRecall,
            thresholds.abstentionAccuracy,
        ]
        guard values.allSatisfy({
            $0.isFinite && (0...1).contains($0)
        }) else {
            throw RepositorySemanticV3ManifestError.invalidThresholds
        }
    }

    private func validate(
        _ evaluationCase: RepositorySemanticV3Case
    ) throws {
        guard !evaluationCase.id.isEmpty,
              Self.isCommit(evaluationCase.snapshotCommit),
              !evaluationCase.license.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              !evaluationCase.prompt.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty,
              !evaluationCase.claimCatalog.isEmpty,
              !evaluationCase.evidence.isEmpty else {
            throw RepositorySemanticV3ManifestError.invalidCase(
                evaluationCase.id
            )
        }

        var claims: Set<String> = []
        for claim in evaluationCase.claimCatalog {
            guard !claim.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            !claim.description.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            claims.insert(claim.id).inserted else {
                throw RepositorySemanticV3ManifestError.invalidClaim(
                    claim.id
                )
            }
        }

        var evidenceByID: [String: RepositorySemanticEvidence] = [:]
        for evidence in evaluationCase.evidence {
            guard !evidence.id.isEmpty,
                  evidenceByID[evidence.id] == nil,
                  evidence.snapshotCommit
                    == evaluationCase.snapshotCommit,
                  !evidence.filePath.isEmpty,
                  !evidence.filePath.hasPrefix("/"),
                  !evidence.filePath.split(separator: "/")
                    .contains(".."),
                  evidence.line > 0,
                  !evidence.symbol.isEmpty,
                  !evidence.excerpt.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ).isEmpty else {
                throw RepositorySemanticV3ManifestError.invalidEvidence(
                    evidence.id
                )
            }
            evidenceByID[evidence.id] = evidence
        }

        guard Set(evaluationCase.requiredClaimIDs).count
                == evaluationCase.requiredClaimIDs.count,
              evaluationCase.requiredClaimIDs.allSatisfy(
                claims.contains
              ) else {
            throw RepositorySemanticV3ManifestError.invalidCase(
                evaluationCase.id
            )
        }

        switch evaluationCase.expectedOutcome {
        case .observation:
            guard !evaluationCase.requiredClaimIDs.isEmpty,
                  evaluationCase.claimCatalog.count
                    > evaluationCase.requiredClaimIDs.count,
                  !evaluationCase.requiredSupportIDs.isEmpty,
                  !evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw RepositorySemanticV3ManifestError.invalidCase(
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
            guard evaluationCase.requiredClaimIDs.isEmpty,
                  evaluationCase.requiredSupportIDs.isEmpty,
                  evaluationCase.requiredCounterevidenceIDs.isEmpty else {
                throw RepositorySemanticV3ManifestError.invalidCase(
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
            throw RepositorySemanticV3ManifestError.invalidCase(caseID)
        }
    }

    private static func isCommit(_ value: String) -> Bool {
        value.count == 40 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef").contains($0)
        }
    }
}

public enum RepositorySemanticV3ManifestError:
    Error, Equatable {
    case unsupportedVersion(Int)
    case invalidManifest
    case invalidThresholds
    case duplicateCaseID(String)
    case invalidCase(String)
    case invalidClaim(String)
    case invalidEvidence(String)
}

public struct RepositorySemanticV3Candidate:
    Equatable, Sendable {
    public let snapshotCommit: String
    public let statement: String
    public let claimIDs: [String]
    public let supportIDs: [String]
    public let counterevidenceIDs: [String]
    public let confidence: Double
    public let runtimeIdentity: String
    public let modelID: String
    public let retention: ResearchRetention

    public init(
        snapshotCommit: String,
        statement: String,
        claimIDs: [String],
        supportIDs: [String],
        counterevidenceIDs: [String],
        confidence: Double,
        runtimeIdentity: String,
        modelID: String,
        retention: ResearchRetention
    ) {
        self.snapshotCommit = snapshotCommit
        self.statement = statement
        self.claimIDs = claimIDs
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
            claimIDs: [],
            supportIDs: [],
            counterevidenceIDs: [],
            confidence: 0,
            runtimeIdentity: runtimeIdentity,
            modelID: modelID,
            retention: .ephemeral
        )
    }
}

public struct RepositorySemanticV3ValidatedCandidate:
    Equatable, Sendable {
    public let caseID: String
    public let snapshotCommit: String
    public let license: String
    public let statement: String
    public let claims: [RepositorySemanticClaim]
    public let support: [RepositorySemanticEvidence]
    public let counterevidence: [RepositorySemanticEvidence]
    public let confidence: Double
    public let runtimeIdentity: String
    public let modelID: String
    public let retention: ResearchRetention
}

public struct RepositorySemanticV3CandidateValidator:
    Sendable {
    public init() {}

    public func validate(
        _ candidate: RepositorySemanticV3Candidate,
        for evaluationCase: RepositorySemanticV3Case
    ) throws -> RepositorySemanticV3ValidatedCandidate? {
        guard candidate.snapshotCommit
                == evaluationCase.snapshotCommit else {
            throw RepositorySemanticV3ValidationError.snapshotMismatch
        }
        guard candidate.confidence.isFinite,
              (0...1).contains(candidate.confidence) else {
            throw RepositorySemanticV3ValidationError.invalidConfidence
        }
        guard !candidate.runtimeIdentity.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        !candidate.modelID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty,
        candidate.retention == .ephemeral else {
            throw RepositorySemanticV3ValidationError.invalidIdentity
        }

        let statement = candidate.statement.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let allSelectionsAreEmpty = candidate.claimIDs.isEmpty
            && candidate.supportIDs.isEmpty
            && candidate.counterevidenceIDs.isEmpty
        if statement.isEmpty || allSelectionsAreEmpty {
            guard statement.isEmpty,
                  allSelectionsAreEmpty,
                  candidate.confidence == 0 else {
                throw RepositorySemanticV3ValidationError
                    .malformedCandidate
            }
            return nil
        }
        guard evaluationCase.expectedOutcome == .observation else {
            throw RepositorySemanticV3ValidationError.expectedAbstention
        }
        guard !candidate.claimIDs.isEmpty,
              !candidate.supportIDs.isEmpty,
              !candidate.counterevidenceIDs.isEmpty else {
            throw RepositorySemanticV3ValidationError.malformedCandidate
        }
        guard Set(candidate.claimIDs).count
                == candidate.claimIDs.count else {
            throw RepositorySemanticV3ValidationError.duplicateClaim
        }
        guard Set(candidate.supportIDs).count
                == candidate.supportIDs.count,
              Set(candidate.counterevidenceIDs).count
                == candidate.counterevidenceIDs.count,
              Set(candidate.supportIDs).isDisjoint(
                with: candidate.counterevidenceIDs
              ) else {
            throw RepositorySemanticV3ValidationError.duplicateEvidence
        }

        let claimByID = Dictionary(
            uniqueKeysWithValues: evaluationCase.claimCatalog.map {
                ($0.id, $0)
            }
        )
        let claims = try candidate.claimIDs.map { id in
            guard let claim = claimByID[id] else {
                throw RepositorySemanticV3ValidationError
                    .unknownClaim(id)
            }
            return claim
        }
        guard Set(evaluationCase.requiredClaimIDs).isSubset(
            of: candidate.claimIDs
        ) else {
            throw RepositorySemanticV3ValidationError
                .missingRequiredClaim
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
            throw RepositorySemanticV3ValidationError
                .missingRequiredEvidence
        }
        guard Set(evaluationCase.requiredCounterevidenceIDs).isSubset(
            of: candidate.counterevidenceIDs
        ) else {
            throw RepositorySemanticV3ValidationError
                .missingRequiredCounterevidence
        }

        return RepositorySemanticV3ValidatedCandidate(
            caseID: evaluationCase.id,
            snapshotCommit: candidate.snapshotCommit,
            license: evaluationCase.license,
            statement: statement,
            claims: claims,
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
                throw RepositorySemanticV3ValidationError
                    .unknownEvidence(id)
            }
            guard evidence.role == role else {
                throw RepositorySemanticV3ValidationError
                    .evidenceRoleMismatch(id)
            }
            return evidence
        }
    }
}

public enum RepositorySemanticV3ValidationError:
    Error, Equatable {
    case snapshotMismatch
    case invalidConfidence
    case invalidIdentity
    case malformedCandidate
    case expectedAbstention
    case duplicateClaim
    case duplicateEvidence
    case unknownClaim(String)
    case unknownEvidence(String)
    case evidenceRoleMismatch(String)
    case missingRequiredClaim
    case missingRequiredEvidence
    case missingRequiredCounterevidence
}

public protocol RepositorySemanticV3CandidateGenerator:
    Sendable {
    var runtimeIdentity: String { get }
    var modelID: String { get }

    func generate(
        for evaluationCase: RepositorySemanticV3Case
    ) async throws -> RepositorySemanticV3Candidate
}

public enum RepositorySemanticV3GeneratorError:
    Error, Equatable {
    case missingCandidate(String)
    case identityMismatch
}

public struct RepositorySemanticV3CaseResult:
    Codable, Equatable, Sendable {
    public let caseID: String
    public let expectedOutcome: RepositorySemanticExpectedOutcome
    public let claimIDs: [String]
    public let supportIDs: [String]
    public let counterevidenceIDs: [String]
    public let confidence: Double?
    public let abstained: Bool
    public let passed: Bool
    public let errorCode: String?
}

public struct RepositorySemanticV3EvaluationReport:
    Codable, Equatable, Sendable {
    public let evaluatorVersion: String
    public let manifestHash: String
    public let runtimeIdentity: String
    public let modelID: String
    public let caseCount: Int
    public let observationCaseCount: Int
    public let abstentionCaseCount: Int
    public let claimRecall: Double
    public let claimPrecision: Double
    public let evidencePrecision: Double
    public let counterevidenceRecall: Double
    public let abstentionAccuracy: Double
    public let failedCaseIDs: [String]
    public let unansweredCaseIDs: [String]
    public let caseResults: [RepositorySemanticV3CaseResult]
    public let thresholds: RepositorySemanticV3Thresholds
    public let meetsFrozenThresholds: Bool
}

public enum RepositorySemanticV3EvaluationExitCode {
    public static func forReport(
        _ report: RepositorySemanticV3EvaluationReport
    ) -> Int32 {
        report.meetsFrozenThresholds ? 0 : 2
    }
}

public struct RepositorySemanticV3Evaluator: Sendable {
    public init() {}

    public func evaluate(
        manifestURL: URL,
        generator: any RepositorySemanticV3CandidateGenerator
    ) async throws -> RepositorySemanticV3EvaluationReport {
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try RepositorySemanticV3Manifest.decode(
            manifestData
        )
        try manifest.validate()

        let observationCases = manifest.cases.filter {
            $0.expectedOutcome == .observation
        }
        let abstentionCases = manifest.cases.filter {
            $0.expectedOutcome == .abstain
        }
        let allRequiredClaims = observationCases.reduce(0) {
            $0 + $1.requiredClaimIDs.count
        }
        let allRequiredCounterevidence = observationCases.reduce(0) {
            $0 + $1.requiredCounterevidenceIDs.count
        }
        var correctClaims = 0
        var selectedClaims = 0
        var correctSupport = 0
        var selectedSupport = 0
        var citedRequiredCounterevidence = 0
        var correctAbstentions = 0
        var failedCaseIDs: [String] = []
        var unansweredCaseIDs: [String] = []
        var results: [RepositorySemanticV3CaseResult] = []
        let validator = RepositorySemanticV3CandidateValidator()

        for evaluationCase in manifest.cases {
            try Task.checkCancellation()
            do {
                let candidate = try await generator.generate(
                    for: evaluationCase
                )
                guard candidate.runtimeIdentity
                        == generator.runtimeIdentity,
                      candidate.modelID == generator.modelID else {
                    throw RepositorySemanticV3GeneratorError
                        .identityMismatch
                }
                let validated = try validator.validate(
                    candidate,
                    for: evaluationCase
                )

                if let validated {
                    let requiredClaims = Set(
                        evaluationCase.requiredClaimIDs
                    )
                    let selectedClaimIDs = validated.claims.map(\.id)
                    correctClaims += selectedClaimIDs.filter {
                        requiredClaims.contains($0)
                    }.count
                    selectedClaims += selectedClaimIDs.count

                    let requiredSupport = Set(
                        evaluationCase.requiredSupportIDs
                    )
                    let supportIDs = validated.support.map(\.id)
                    correctSupport += supportIDs.filter {
                        requiredSupport.contains($0)
                    }.count
                    selectedSupport += supportIDs.count

                    let requiredCounterevidence = Set(
                        evaluationCase.requiredCounterevidenceIDs
                    )
                    let counterevidenceIDs = validated
                        .counterevidence.map(\.id)
                    citedRequiredCounterevidence += counterevidenceIDs
                        .filter {
                            requiredCounterevidence.contains($0)
                        }.count

                    let passed = Set(selectedClaimIDs)
                            == requiredClaims
                        && Set(supportIDs) == requiredSupport
                        && Set(counterevidenceIDs)
                            == requiredCounterevidence
                    if !passed {
                        failedCaseIDs.append(evaluationCase.id)
                    }
                    results.append(
                        RepositorySemanticV3CaseResult(
                            caseID: evaluationCase.id,
                            expectedOutcome:
                                evaluationCase.expectedOutcome,
                            claimIDs: selectedClaimIDs,
                            supportIDs: supportIDs,
                            counterevidenceIDs: counterevidenceIDs,
                            confidence: validated.confidence,
                            abstained: false,
                            passed: passed,
                            errorCode: passed
                                ? nil
                                : "unexpected_selection"
                        )
                    )
                } else {
                    let passed = evaluationCase.expectedOutcome
                        == .abstain
                    if passed {
                        correctAbstentions += 1
                    } else {
                        unansweredCaseIDs.append(evaluationCase.id)
                    }
                    results.append(
                        RepositorySemanticV3CaseResult(
                            caseID: evaluationCase.id,
                            expectedOutcome:
                                evaluationCase.expectedOutcome,
                            claimIDs: [],
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
                    RepositorySemanticV3CaseResult(
                        caseID: evaluationCase.id,
                        expectedOutcome:
                            evaluationCase.expectedOutcome,
                        claimIDs: [],
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

        let claimRecall = Self.ratio(
            correctClaims,
            allRequiredClaims
        )
        let claimPrecision = Self.ratio(
            correctClaims,
            selectedClaims
        )
        let evidencePrecision = Self.ratio(
            correctSupport,
            selectedSupport
        )
        let counterevidenceRecall = Self.ratio(
            citedRequiredCounterevidence,
            allRequiredCounterevidence
        )
        let abstentionAccuracy = Self.ratio(
            correctAbstentions,
            abstentionCases.count
        )
        let thresholds = manifest.thresholds
        let meetsThresholds = claimRecall >= thresholds.claimRecall
            && claimPrecision >= thresholds.claimPrecision
            && evidencePrecision >= thresholds.evidencePrecision
            && counterevidenceRecall
                >= thresholds.counterevidenceRecall
            && abstentionAccuracy >= thresholds.abstentionAccuracy
            && failedCaseIDs.isEmpty
            && unansweredCaseIDs.isEmpty

        return RepositorySemanticV3EvaluationReport(
            evaluatorVersion: "repository-semantic-evaluator-v3",
            manifestHash: RepositorySemanticV3Manifest.sha256(
                of: manifestData
            ),
            runtimeIdentity: generator.runtimeIdentity,
            modelID: generator.modelID,
            caseCount: manifest.cases.count,
            observationCaseCount: observationCases.count,
            abstentionCaseCount: abstentionCases.count,
            claimRecall: claimRecall,
            claimPrecision: claimPrecision,
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
        case RepositorySemanticV3ValidationError.snapshotMismatch:
            "snapshot_mismatch"
        case RepositorySemanticV3ValidationError.invalidConfidence:
            "invalid_confidence"
        case RepositorySemanticV3ValidationError.invalidIdentity:
            "invalid_identity"
        case RepositorySemanticV3ValidationError.malformedCandidate:
            "malformed_candidate"
        case RepositorySemanticV3ValidationError.expectedAbstention:
            "expected_abstention"
        case RepositorySemanticV3ValidationError.duplicateClaim:
            "duplicate_claim"
        case RepositorySemanticV3ValidationError.duplicateEvidence:
            "duplicate_evidence"
        case RepositorySemanticV3ValidationError.unknownClaim:
            "unknown_claim"
        case RepositorySemanticV3ValidationError.unknownEvidence:
            "unknown_evidence"
        case RepositorySemanticV3ValidationError.evidenceRoleMismatch:
            "evidence_role_mismatch"
        case RepositorySemanticV3ValidationError.missingRequiredClaim:
            "missing_required_claim"
        case RepositorySemanticV3ValidationError.missingRequiredEvidence:
            "missing_required_evidence"
        case RepositorySemanticV3ValidationError
            .missingRequiredCounterevidence:
            "missing_required_counterevidence"
        case RepositorySemanticV3GeneratorError.missingCandidate:
            "missing_candidate"
        case RepositorySemanticV3GeneratorError.identityMismatch:
            "generator_identity_mismatch"
        default:
            "generator_error"
        }
    }
}

public enum RepositorySemanticV3LocalGeneratorError:
    Error, Equatable {
    case invalidAssignment
    case healthRequired
    case evidenceBoundsExceeded
    case transportUnavailable
    case httpStatus(Int)
    case invalidResponse
    case selectedModelUnavailable(String)
    case modelIdentityMismatch(expected: String, actual: String)
    case unknownClaim(String)
    case unknownEvidence(String)
    case malformedCandidate
}

public actor RepositorySemanticV3LocalGenerator:
    RepositorySemanticV3CandidateGenerator {
    public nonisolated let runtimeIdentity: String
    public nonisolated let modelID: String

    private static let maximumClaimCount = 32
    private static let maximumEvidenceCount = 64
    private static let maximumDescriptionCharacters = 1_000
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
            throw RepositorySemanticV3LocalGeneratorError
                .invalidAssignment
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
        let catalog: RepositorySemanticV3ModelListEnvelope
        do {
            catalog = try JSONDecoder().decode(
                RepositorySemanticV3ModelListEnvelope.self,
                from: response.data
            )
        } catch {
            throw RepositorySemanticV3LocalGeneratorError
                .invalidResponse
        }
        guard catalog.data.contains(where: { $0.id == modelID }) else {
            throw RepositorySemanticV3LocalGeneratorError
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
        for evaluationCase: RepositorySemanticV3Case
    ) async throws -> RepositorySemanticV3Candidate {
        guard healthVerified else {
            throw RepositorySemanticV3LocalGeneratorError
                .healthRequired
        }
        guard evaluationCase.claimCatalog.count
                <= Self.maximumClaimCount,
              evaluationCase.claimCatalog.allSatisfy({
                  $0.description.count
                    <= Self.maximumDescriptionCharacters
              }),
              evaluationCase.evidence.count
                <= Self.maximumEvidenceCount,
              evaluationCase.evidence.allSatisfy({
                  $0.excerpt.count <= Self.maximumExcerptCharacters
              }) else {
            throw RepositorySemanticV3LocalGeneratorError
                .evidenceBoundsExceeded
        }

        let claimData = try JSONEncoder().encode(
            evaluationCase.claimCatalog
        )
        let neutralEvidence = evaluationCase.evidence.map {
            RepositorySemanticV3PromptEvidence(evidence: $0)
        }
        let evidenceData = try JSONEncoder().encode(neutralEvidence)
        let claimText = String(decoding: claimData, as: UTF8.self)
        let evidenceText = String(
            decoding: evidenceData,
            as: UTF8.self
        )
        let claimIDs = evaluationCase.claimCatalog.map(\.id)
        let evidenceIDs = evaluationCase.evidence.map(\.id)
        let request = RepositorySemanticV3ChatCompletionRequest(
            model: modelID,
            messages: [
                RepositorySemanticV3ChatMessage(
                    role: "system",
                    content: """
                    Analyze only the supplied immutable repository evidence. Select only catalog claim IDs and evidence IDs. Return exactly one JSON object with statement, claim_ids, support_ids, counterevidence_ids, and confidence. Cite direct support and important limiting counterevidence. If no catalog claim is supported, return an empty statement, empty ID arrays, and confidence 0. Never invent an ID. This is an ephemeral hypothesis, not truth or permission to retain, copy, execute, or modify code.

                    Snapshot commit: \(evaluationCase.snapshotCommit)
                    Claim catalog JSON: \(claimText)
                    Evidence JSON: \(evidenceText)
                    """
                ),
                RepositorySemanticV3ChatMessage(
                    role: "user",
                    content: evaluationCase.prompt
                ),
            ],
            stream: false,
            temperature: 0,
            maxTokens: 512,
            seed: 0,
            responseFormat: .semanticCandidate(
                claimIDs: claimIDs,
                evidenceIDs: evidenceIDs
            )
        )
        let body = try JSONEncoder().encode(request)
        guard body.count <= Self.maximumRequestBytes else {
            throw RepositorySemanticV3LocalGeneratorError
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
        let envelope: RepositorySemanticV3ChatCompletionEnvelope
        do {
            envelope = try JSONDecoder().decode(
                RepositorySemanticV3ChatCompletionEnvelope.self,
                from: response.data
            )
        } catch {
            throw RepositorySemanticV3LocalGeneratorError
                .invalidResponse
        }
        guard envelope.model == modelID else {
            throw RepositorySemanticV3LocalGeneratorError
                .modelIdentityMismatch(
                    expected: modelID,
                    actual: envelope.model
                )
        }
        guard let content = envelope.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let output = try? JSONDecoder().decode(
                  RepositorySemanticV3ModelOutput.self,
                  from: contentData
              ) else {
            throw RepositorySemanticV3LocalGeneratorError
                .invalidResponse
        }

        let statement = output.statement.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let noSelections = output.claimIDs.isEmpty
            && output.supportIDs.isEmpty
            && output.counterevidenceIDs.isEmpty
        guard output.confidence.isFinite,
              (0...1).contains(output.confidence),
              (statement.isEmpty
                && noSelections
                && output.confidence == 0)
                || (!statement.isEmpty
                    && !output.claimIDs.isEmpty
                    && !output.supportIDs.isEmpty
                    && !output.counterevidenceIDs.isEmpty)
        else {
            throw RepositorySemanticV3LocalGeneratorError
                .malformedCandidate
        }

        let validClaimIDs = Set(claimIDs)
        for id in output.claimIDs {
            guard validClaimIDs.contains(id) else {
                throw RepositorySemanticV3LocalGeneratorError
                    .unknownClaim(id)
            }
        }
        let validEvidenceIDs = Set(evidenceIDs)
        for id in output.supportIDs + output.counterevidenceIDs {
            guard validEvidenceIDs.contains(id) else {
                throw RepositorySemanticV3LocalGeneratorError
                    .unknownEvidence(id)
            }
        }

        return RepositorySemanticV3Candidate(
            snapshotCommit: evaluationCase.snapshotCommit,
            statement: statement,
            claimIDs: output.claimIDs,
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
        } catch let error as RepositorySemanticV3LocalGeneratorError {
            throw error
        } catch {
            throw RepositorySemanticV3LocalGeneratorError
                .transportUnavailable
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RepositorySemanticV3LocalGeneratorError
                .httpStatus(response.statusCode)
        }
        guard response.data.count <= Self.maximumResponseBytes else {
            throw RepositorySemanticV3LocalGeneratorError
                .invalidResponse
        }
        return response
    }
}

private struct RepositorySemanticV3PromptEvidence:
    Encodable {
    let id: String
    let snapshotCommit: String
    let filePath: String
    let line: Int
    let symbol: String
    let excerpt: String

    init(evidence: RepositorySemanticEvidence) {
        id = evidence.id
        snapshotCommit = evidence.snapshotCommit
        filePath = evidence.filePath
        line = evidence.line
        symbol = evidence.symbol
        excerpt = evidence.excerpt
    }
}

private struct RepositorySemanticV3ModelListEnvelope:
    Decodable {
    let data: [RepositorySemanticV3ModelListItem]
}

private struct RepositorySemanticV3ModelListItem:
    Decodable {
    let id: String
}

private struct RepositorySemanticV3ChatMessage: Codable {
    let role: String
    let content: String
}

private struct RepositorySemanticV3ChatCompletionRequest:
    Encodable {
    let model: String
    let messages: [RepositorySemanticV3ChatMessage]
    let stream: Bool
    let temperature: Int
    let maxTokens: Int
    let seed: Int
    let responseFormat: RepositorySemanticV3ResponseFormat

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

private struct RepositorySemanticV3ResponseFormat:
    Encodable {
    let type: String
    let jsonSchema: RepositorySemanticV3JSONSchema

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    static func semanticCandidate(
        claimIDs: [String],
        evidenceIDs: [String]
    ) -> Self {
        Self(
            type: "json_schema",
            jsonSchema: RepositorySemanticV3JSONSchema(
                name: "repository_semantic_v3_candidate",
                schema: RepositorySemanticV3CandidateSchema(
                    claimIDs: claimIDs,
                    evidenceIDs: evidenceIDs
                )
            )
        )
    }
}

private struct RepositorySemanticV3JSONSchema: Encodable {
    let name: String
    let schema: RepositorySemanticV3CandidateSchema
}

private struct RepositorySemanticV3CandidateSchema: Encodable {
    let type = "object"
    let properties: [String: RepositorySemanticV3SchemaProperty]
    let required = [
        "statement",
        "claim_ids",
        "support_ids",
        "counterevidence_ids",
        "confidence",
    ]
    let additionalProperties = false

    init(claimIDs: [String], evidenceIDs: [String]) {
        properties = [
            "statement": RepositorySemanticV3SchemaProperty(
                type: "string"
            ),
            "claim_ids": RepositorySemanticV3SchemaProperty(
                type: "array",
                allowedValues: claimIDs
            ),
            "support_ids": RepositorySemanticV3SchemaProperty(
                type: "array",
                allowedValues: evidenceIDs
            ),
            "counterevidence_ids":
                RepositorySemanticV3SchemaProperty(
                    type: "array",
                    allowedValues: evidenceIDs
                ),
            "confidence": RepositorySemanticV3SchemaProperty(
                type: "number",
                minimum: 0,
                maximum: 1
            ),
        ]
    }
}

private struct RepositorySemanticV3SchemaProperty: Encodable {
    let type: String
    let items: RepositorySemanticV3SchemaItems?
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
            RepositorySemanticV3SchemaItems(
                type: "string",
                allowedValues: $0.isEmpty ? nil : $0
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
}

private struct RepositorySemanticV3SchemaItems: Encodable {
    let type: String
    let allowedValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case allowedValues = "enum"
    }
}

private struct RepositorySemanticV3ChatCompletionEnvelope:
    Decodable {
    let model: String
    let choices: [RepositorySemanticV3ChatChoice]
}

private struct RepositorySemanticV3ChatChoice: Decodable {
    let message: RepositorySemanticV3ChatMessage
}

private struct RepositorySemanticV3ModelOutput: Decodable {
    let statement: String
    let claimIDs: [String]
    let supportIDs: [String]
    let counterevidenceIDs: [String]
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case statement
        case claimIDs = "claim_ids"
        case supportIDs = "support_ids"
        case counterevidenceIDs = "counterevidence_ids"
        case confidence
    }

    init(from decoder: Decoder) throws {
        let allKeys = try decoder.container(
            keyedBy: RepositorySemanticV3DynamicCodingKey.self
        ).allKeys.map(\.stringValue)
        let allowed = Set([
            "statement",
            "claim_ids",
            "support_ids",
            "counterevidence_ids",
            "confidence",
        ])
        guard Set(allKeys) == allowed else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "Semantic V3 response keys must match exactly"
                )
            )
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statement = try container.decode(
            String.self,
            forKey: .statement
        )
        claimIDs = try container.decode(
            [String].self,
            forKey: .claimIDs
        )
        supportIDs = try container.decode(
            [String].self,
            forKey: .supportIDs
        )
        counterevidenceIDs = try container.decode(
            [String].self,
            forKey: .counterevidenceIDs
        )
        confidence = try container.decode(
            Double.self,
            forKey: .confidence
        )
    }
}

private struct RepositorySemanticV3DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
