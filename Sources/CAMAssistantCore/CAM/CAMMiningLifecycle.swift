import CryptoKit
import Foundation

/// Digest-only identity for a separately inspected CAM runtime. The actual
/// runtime, configuration, and database stay outside this native contract.
public struct CAMMiningRuntimePin: Codable, Equatable, Sendable {
    public let runtimeIdentitySHA256: String
    public let configurationSHA256: String
    public let databaseSHA256: String

    public init(
        runtimeIdentitySHA256: String,
        configurationSHA256: String,
        databaseSHA256: String
    ) throws {
        guard [runtimeIdentitySHA256, configurationSHA256, databaseSHA256]
            .allSatisfy(CAMMiningPlan.isSHA256) else {
            throw CAMMiningPlanError.invalidRuntimePin
        }
        self.runtimeIdentitySHA256 = runtimeIdentitySHA256.lowercased()
        self.configurationSHA256 = configurationSHA256.lowercased()
        self.databaseSHA256 = databaseSHA256.lowercased()
    }
}

/// Exact scope for a future CAM mining operation. It contains only selected
/// local identifiers and digests, never repository source content, config
/// values, database paths, or credentials.
public struct CAMMiningPlan: Codable, Equatable, Sendable {
    public let repositoryCanonicalPath: String
    public let repositoryCommit: String
    public let sourceRootIDs: [String]
    public let runtimePin: CAMMiningRuntimePin
    public let maxRepositories: Int
    public let maxDurationSeconds: Int
    public let expectedWrites: [String]
    public let verificationCommand: String
    public let recoveryDescription: String
    public let idempotencyKey: String
    public let stateVersion: Int
    public let planDigest: String

    public init(
        repositoryCanonicalPath: String,
        repositoryCommit: String,
        sourceRootIDs: [String],
        runtimePin: CAMMiningRuntimePin,
        maxRepositories: Int,
        maxDurationSeconds: Int,
        expectedWrites: [String],
        verificationCommand: String,
        recoveryDescription: String,
        idempotencyKey: String,
        stateVersion: Int
    ) throws {
        let normalizedPath = repositoryCanonicalPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCommit = repositoryCommit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedRoots = sourceRootIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        let normalizedWrites = expectedWrites
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        let requiredText = [verificationCommand, recoveryDescription, idempotencyKey]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !normalizedPath.isEmpty, normalizedCommit.count == 40,
              normalizedCommit.unicodeScalars.allSatisfy(CAMMiningPlan.isHexScalar) else {
            throw CAMMiningPlanError.invalidRepositoryIdentity
        }
        guard !normalizedRoots.isEmpty,
              normalizedRoots.allSatisfy({ !$0.isEmpty }),
              Set(normalizedRoots).count == normalizedRoots.count else {
            throw CAMMiningPlanError.invalidSourceRoots
        }
        guard maxRepositories > 0, maxDurationSeconds > 0 else {
            throw CAMMiningPlanError.invalidBounds
        }
        guard !normalizedWrites.isEmpty, normalizedWrites.allSatisfy({ !$0.isEmpty }),
              requiredText.allSatisfy({ !$0.isEmpty }), stateVersion >= 0 else {
            throw CAMMiningPlanError.missingRequiredDetail
        }

        self.repositoryCanonicalPath = normalizedPath
        self.repositoryCommit = normalizedCommit
        self.sourceRootIDs = normalizedRoots
        self.runtimePin = runtimePin
        self.maxRepositories = maxRepositories
        self.maxDurationSeconds = maxDurationSeconds
        self.expectedWrites = normalizedWrites
        self.verificationCommand = requiredText[0]
        self.recoveryDescription = requiredText[1]
        self.idempotencyKey = requiredText[2]
        self.stateVersion = stateVersion

        let material = MiningPlanDigestMaterial(
            repositoryCanonicalPath: normalizedPath,
            repositoryCommit: normalizedCommit,
            sourceRootIDs: normalizedRoots,
            runtimePin: runtimePin,
            maxRepositories: maxRepositories,
            maxDurationSeconds: maxDurationSeconds,
            expectedWrites: normalizedWrites,
            verificationCommand: requiredText[0],
            recoveryDescription: requiredText[1],
            idempotencyKey: requiredText[2],
            stateVersion: stateVersion
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        planDigest = SHA256.hash(data: try encoder.encode(material)).hexString
    }

    fileprivate static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy(isHexScalar)
    }

    fileprivate static func isHexScalar(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...70).contains(scalar.value)
            || (97...102).contains(scalar.value)
    }

    public func actionCard(expiresAt: Date, id: UUID = UUID()) throws -> ActionCard {
        let payload = "mining-plan:\(planDigest)"
        let payloadData = Data(payload.utf8)
        let manifest = OutboundManifest(
            operation: "cam-mining",
            requestedRole: nil,
            stateVersion: stateVersion,
            riskClass: .generic,
            redactedPayload: payload,
            payloadSHA256: SHA256.hash(data: payloadData).hexString,
            outboundByteCount: payloadData.count
        )
        return try ActionCard(
            id: id,
            goal: "Mine the approved selected repository into the pinned CAM runtime.",
            moduleID: "cam.mining",
            target: "CAM mining plan \(planDigest)",
            accessedResources: [repositoryCanonicalPath] + sourceRootIDs,
            excludedResources: ["personal vault", "credentials", "unselected repositories"],
            riskReason: "CAM mining writes derived corpus material and is bound to a pinned runtime/config/database identity.",
            outboundManifest: manifest,
            expiresAt: expiresAt,
            rollbackDescription: recoveryDescription
        )
    }

    fileprivate var approvalPayloadDigest: String {
        SHA256.hash(data: Data("mining-plan:\(planDigest)".utf8)).hexString
    }
}

public enum CAMMiningPlanError: Error, Equatable {
    case invalidRuntimePin
    case invalidRepositoryIdentity
    case invalidSourceRoots
    case invalidBounds
    case missingRequiredDetail
}

public enum CAMMiningStatus: String, Codable, Equatable, Sendable {
    case awaitingExactApproval
    case active
    case cancelled
    case unavailable
}

/// Reducer-style lifecycle state. It never executes a CAM command; a future
/// executor must consume this state only after the exact approval is bound.
public struct CAMMiningRun: Equatable, Sendable {
    public let id: UUID
    public let plan: CAMMiningPlan
    public let status: CAMMiningStatus
    public let approvalReceipt: ApprovalReceipt?
    public let terminalReason: String?

    public init(id: UUID = UUID(), plan: CAMMiningPlan) {
        self.id = id
        self.plan = plan
        status = .awaitingExactApproval
        approvalReceipt = nil
        terminalReason = nil
    }

    public func start(
        approvalID: UUID?,
        approvalStore: ApprovalStore,
        card: ActionCard,
        now: Date = Date()
    ) throws -> Self {
        guard status == .awaitingExactApproval else {
            throw CAMMiningRunError.invalidTransition
        }
        guard let approvalID else { throw CAMMiningRunError.missingExactApproval }
        guard card.moduleID == "cam.mining",
              card.outboundManifest.operation == "cam-mining",
              card.outboundManifest.stateVersion == plan.stateVersion,
              card.outboundManifest.payloadSHA256 == plan.approvalPayloadDigest,
              card.target == "CAM mining plan \(plan.planDigest)" else {
            throw CAMMiningRunError.mismatchedActionCard
        }
        let receipt = try approvalStore.consume(approvalID: approvalID, for: card, now: now)
        return Self(
            id: id,
            plan: plan,
            status: .active,
            approvalReceipt: receipt,
            terminalReason: nil
        )
    }

    public func cancel(reason: String) throws -> Self {
        guard status == .active else { throw CAMMiningRunError.invalidTransition }
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReason.isEmpty else { throw CAMMiningRunError.invalidCancellationReason }
        return Self(
            id: id,
            plan: plan,
            status: .cancelled,
            approvalReceipt: approvalReceipt,
            terminalReason: normalizedReason
        )
    }

    private init(
        id: UUID,
        plan: CAMMiningPlan,
        status: CAMMiningStatus,
        approvalReceipt: ApprovalReceipt?,
        terminalReason: String?
    ) {
        self.id = id
        self.plan = plan
        self.status = status
        self.approvalReceipt = approvalReceipt
        self.terminalReason = terminalReason
    }
}

public enum CAMMiningRunError: Error, Equatable {
    case missingExactApproval
    case mismatchedActionCard
    case invalidTransition
    case invalidCancellationReason
}

/// A local receipt for an attempted lifecycle transition. It does not include
/// CAM output or any raw source/configuration data.
public struct CAMMiningReceipt: Equatable, Sendable {
    public let runID: UUID
    public let planDigest: String
    public let idempotencyKey: String
    public let status: CAMMiningStatus
    public let verificationCommand: String
    public let terminalReason: String
}

public enum CAMMiningExecutorError: Error, Equatable {
    case runNotActive
    case approvalNotConsumed
}

/// The only executor currently available in this app. It deliberately does no
/// I/O and records that a live CAM runtime was not attached to the product.
public struct CAMMiningUnavailableExecutor: Sendable {
    public init() {}

    public func attempt(_ run: CAMMiningRun) throws -> CAMMiningReceipt {
        guard run.status == .active else { throw CAMMiningExecutorError.runNotActive }
        guard run.approvalReceipt != nil else { throw CAMMiningExecutorError.approvalNotConsumed }
        return CAMMiningReceipt(
            runID: run.id,
            planDigest: run.plan.planDigest,
            idempotencyKey: run.plan.idempotencyKey,
            status: .unavailable,
            verificationCommand: run.plan.verificationCommand,
            terminalReason: "No CAM runtime is attached; no repository, configuration, database, or corpus was opened."
        )
    }
}

private struct MiningPlanDigestMaterial: Codable {
    let repositoryCanonicalPath: String
    let repositoryCommit: String
    let sourceRootIDs: [String]
    let runtimePin: CAMMiningRuntimePin
    let maxRepositories: Int
    let maxDurationSeconds: Int
    let expectedWrites: [String]
    let verificationCommand: String
    let recoveryDescription: String
    let idempotencyKey: String
    let stateVersion: Int
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
