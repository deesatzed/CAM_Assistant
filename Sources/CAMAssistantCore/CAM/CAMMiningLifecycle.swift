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

/// A closed input contract for the first real external CAM mining proof. All
/// source paths must be regular files or directories below one fixture root;
/// the executor will later make its own disposable copy before launch.
public struct CAMDisposableMiningRequest: Equatable, Sendable {
    public let fixtureRoot: URL
    public let repositoryURL: URL
    public let configurationURL: URL
    public let databaseURL: URL
    public let runtimeIdentitySHA256: String
    public let expectedDatabaseSHA256: String
    public let maximumOutputBytes: Int

    public init(
        fixtureRoot: URL,
        repositoryURL: URL,
        configurationURL: URL,
        databaseURL: URL,
        runtimeIdentitySHA256: String,
        expectedDatabaseSHA256: String,
        maximumOutputBytes: Int
    ) throws {
        let normalizedRoot = fixtureRoot.standardizedFileURL
        guard normalizedRoot.isFileURL,
              FileManager.default.fileExists(atPath: normalizedRoot.path) else {
            throw CAMDisposableMiningRequestError.invalidFixtureRoot
        }
        let normalizedRepository = repositoryURL.standardizedFileURL
        let normalizedConfiguration = configurationURL.standardizedFileURL
        let normalizedDatabase = databaseURL.standardizedFileURL
        let inputs = [normalizedRepository, normalizedConfiguration, normalizedDatabase]
        guard inputs.allSatisfy({ Self.isDescendant($0, of: normalizedRoot) }) else {
            throw CAMDisposableMiningRequestError.pathOutsideFixture
        }
        guard inputs.allSatisfy({
            !Self.isSymbolicLink($0)
                && FileManager.default.fileExists(atPath: $0.path)
        }) else {
            throw CAMDisposableMiningRequestError.invalidFixtureInput
        }
        let normalizedRuntimeIdentity = runtimeIdentitySHA256.lowercased()
        let normalizedDatabaseDigest = expectedDatabaseSHA256.lowercased()
        guard CAMMiningPlan.isSHA256(normalizedRuntimeIdentity),
              CAMMiningPlan.isSHA256(normalizedDatabaseDigest) else {
            throw CAMDisposableMiningRequestError.invalidDatabaseDigest
        }
        guard (1...1_048_576).contains(maximumOutputBytes) else {
            throw CAMDisposableMiningRequestError.invalidOutputLimit
        }
        self.fixtureRoot = normalizedRoot
        self.repositoryURL = normalizedRepository
        self.configurationURL = normalizedConfiguration
        self.databaseURL = normalizedDatabase
        self.runtimeIdentitySHA256 = normalizedRuntimeIdentity
        self.expectedDatabaseSHA256 = normalizedDatabaseDigest
        self.maximumOutputBytes = maximumOutputBytes
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(rootPath)
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?
            .isSymbolicLink) == true
    }
}

public enum CAMDisposableMiningRequestError: Error, Equatable {
    case invalidFixtureRoot
    case pathOutsideFixture
    case invalidFixtureInput
    case invalidDatabaseDigest
    case invalidOutputLimit
}

/// A deliberately tiny, structured corpus used exclusively by the isolated
/// mining proof. It contains fixture identifiers only: callers cannot pass a
/// path, configuration, database, source bytes, or an external CAM command.
public struct CAMSyntheticMiningCorpus: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let fixtureID: String
    public let repositoryIDs: [String]
    public let sha256: String

    public init(fixtureID: String, repositoryIDs: [String]) throws {
        let normalizedFixtureID = fixtureID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedRepositoryIDs = repositoryIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        guard Self.isSafeIdentifier(normalizedFixtureID),
              !normalizedRepositoryIDs.isEmpty,
              normalizedRepositoryIDs.allSatisfy(Self.isSafeIdentifier),
              Set(normalizedRepositoryIDs).count == normalizedRepositoryIDs.count else {
            throw CAMIsolatedMiningRequestError.invalidSyntheticCorpus
        }
        schemaVersion = 1
        self.fixtureID = normalizedFixtureID
        self.repositoryIDs = normalizedRepositoryIDs

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        sha256 = SHA256.hash(
            data: try encoder.encode(
                CAMSyntheticMiningCorpusDigestMaterial(
                    schemaVersion: schemaVersion,
                    fixtureID: normalizedFixtureID,
                    repositoryIDs: normalizedRepositoryIDs
                )
            )
        ).hexString
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        let decodedFixtureID = try values.decode(String.self, forKey: .fixtureID)
        let decodedRepositoryIDs = try values.decode([String].self, forKey: .repositoryIDs)
        let decodedSHA256 = try values.decode(String.self, forKey: .sha256)
        let validated: CAMSyntheticMiningCorpus
        do {
            validated = try CAMSyntheticMiningCorpus(
                fixtureID: decodedFixtureID,
                repositoryIDs: decodedRepositoryIDs
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .fixtureID,
                in: values,
                debugDescription: "Synthetic corpus identifiers are invalid."
            )
        }
        guard decodedSchemaVersion == validated.schemaVersion,
              decodedSHA256.lowercased() == validated.sha256 else {
            throw DecodingError.dataCorruptedError(
                forKey: .sha256,
                in: values,
                debugDescription: "Synthetic corpus digest does not match its contents."
            )
        }
        self = validated
    }

    fileprivate static func isSafeIdentifier(_ value: String) -> Bool {
        (1...128).contains(value.utf8.count)
            && value.unicodeScalars.allSatisfy { scalar in
                (48...57).contains(scalar.value)
                    || (65...90).contains(scalar.value)
                    || (97...122).contains(scalar.value)
                    || scalar == "-"
                    || scalar == "_"
                    || scalar == "."
                    || scalar == ":"
            }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case fixtureID
        case repositoryIDs
        case sha256
    }
}

/// Inputs for a mutation proof that never receives a filesystem corpus path.
/// Only an executor-owned temporary copy may later be materialized from this
/// structured synthetic fixture.
public struct CAMIsolatedMiningRequest: Equatable, Sendable {
    public let corpus: CAMSyntheticMiningCorpus
    public let expectedCorpusSHA256: String
    public let expectedWriteIDs: [String]
    public let maximumWriteCount: Int

    public init(
        corpus: CAMSyntheticMiningCorpus,
        expectedCorpusSHA256: String,
        expectedWriteIDs: [String],
        maximumWriteCount: Int
    ) throws {
        let normalizedDigest = expectedCorpusSHA256.lowercased()
        let normalizedWriteIDs = expectedWriteIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        guard CAMMiningPlan.isSHA256(normalizedDigest),
              normalizedDigest == corpus.sha256 else {
            throw CAMIsolatedMiningRequestError.invalidExpectedCorpusDigest
        }
        guard !normalizedWriteIDs.isEmpty,
              normalizedWriteIDs.allSatisfy(CAMSyntheticMiningCorpus.isSafeIdentifier),
              Set(normalizedWriteIDs).count == normalizedWriteIDs.count else {
            throw CAMIsolatedMiningRequestError.invalidExpectedWrites
        }
        guard (1...128).contains(maximumWriteCount),
              normalizedWriteIDs.count <= maximumWriteCount else {
            throw CAMIsolatedMiningRequestError.invalidBounds
        }
        self.corpus = corpus
        self.expectedCorpusSHA256 = normalizedDigest
        self.expectedWriteIDs = normalizedWriteIDs
        self.maximumWriteCount = maximumWriteCount
    }
}

public enum CAMIsolatedMiningRequestError: Error, Equatable {
    case invalidSyntheticCorpus
    case invalidExpectedCorpusDigest
    case invalidExpectedWrites
    case invalidBounds
}

public enum CAMIsolatedMiningStatus: String, Codable, Equatable, Sendable {
    case verified
    case failed
    case cancelled
    case postconditionFailed
}

/// Status-only checkpoint written before the synthetic adapter receives the
/// executor-owned operation paths. It deliberately excludes corpus contents,
/// configuration, source paths, and any external runtime identity.
public struct CAMIsolatedMiningCheckpoint: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let operationID: UUID
    public let runID: UUID
    public let planDigest: String
    public let approvalID: UUID
    public let initialCorpusSHA256: String
    public let expectedWriteIDs: [String]
    public let maximumWriteCount: Int
    public let startedAt: Date
}

/// Paths exposed to the test-only synthetic adapter are always descendants of
/// the executor-created operation directory. No caller supplies these paths.
public struct CAMIsolatedMiningOperation: Sendable {
    public let corpusURL: URL
    public let checkpointURL: URL

    fileprivate init(corpusURL: URL, checkpointURL: URL) {
        self.corpusURL = corpusURL
        self.checkpointURL = checkpointURL
    }
}

/// Test seam for the isolated proof. The adapter returns bounded identifiers;
/// the executor, not the adapter, performs the only mutation of the copied
/// synthetic corpus. This cannot invoke CAM or receive a live database path.
public struct CAMSyntheticMiningAdapter: Sendable {
    private let deriveWrites: @Sendable (CAMIsolatedMiningOperation) throws -> [String]

    public init(
        deriveWrites: @escaping @Sendable (
            CAMIsolatedMiningOperation
        ) throws -> [String]
    ) {
        self.deriveWrites = deriveWrites
    }

    public func writes(for operation: CAMIsolatedMiningOperation) throws -> [String] {
        try deriveWrites(operation)
    }
}

/// A terminal local receipt. It contains only plan/run identifiers, digests,
/// counts, status, and opaque failure codes; it never serializes corpus bytes
/// or an operation filesystem path.
public struct CAMIsolatedMiningReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let operationID: UUID
    public let runID: UUID
    public let planDigest: String
    public let approvalID: UUID
    public let status: CAMIsolatedMiningStatus
    public let failureCode: String?
    public let initialCorpusSHA256: String
    public let finalCorpusSHA256: String?
    public let writeIDs: [String]
    public let operationDiscarded: Bool
    public let startedAt: Date
    public let finishedAt: Date
}

public struct CAMIsolatedMiningExecutionResult: Equatable, Sendable {
    public let receipt: CAMIsolatedMiningReceipt
}

public enum CAMIsolatedMiningExecutorError: Error, Equatable {
    case runNotActive
    case approvalNotConsumed
    case invalidWorkspace
    case checkpointPersistenceFailed
    case receiptPersistenceFailed
}

/// Executes a synthetic-only mining mutation in a newly-created operation
/// directory. It is intentionally not an external CAM executor and has no
/// source/database/configuration path input or promotion API.
public struct CAMIsolatedMiningExecutor: Sendable {
    public init() {}

    public func attempt(
        run: CAMMiningRun,
        request: CAMIsolatedMiningRequest,
        workspaceRoot: URL,
        adapter: CAMSyntheticMiningAdapter,
        isCancellationRequested: @Sendable () -> Bool = { false }
    ) throws -> CAMIsolatedMiningExecutionResult {
        guard run.status == .active else {
            throw CAMIsolatedMiningExecutorError.runNotActive
        }
        guard let approval = run.approvalReceipt else {
            throw CAMIsolatedMiningExecutorError.approvalNotConsumed
        }
        guard workspaceRoot.isFileURL,
              workspaceRoot.path.hasPrefix("/") else {
            throw CAMIsolatedMiningExecutorError.invalidWorkspace
        }

        let fileManager = FileManager.default
        let operationID = UUID()
        let operationsRoot = workspaceRoot.appending(
            path: "isolated-cam-mining-operations",
            directoryHint: .isDirectory
        )
        let operationRoot = operationsRoot.appending(
            path: operationID.uuidString,
            directoryHint: .isDirectory
        )
        let corpusURL = operationRoot.appending(path: "synthetic-corpus.json")
        let checkpointURL = operationRoot.appending(path: "checkpoint.json")
        let startedAt = Date()

        do {
            try fileManager.createDirectory(
                at: operationRoot,
                withIntermediateDirectories: true
            )
            let initialDocument = CAMIsolatedMiningCorpusDocument(
                schemaVersion: 1,
                fixtureID: request.corpus.fixtureID,
                repositoryIDs: request.corpus.repositoryIDs,
                writeIDs: []
            )
            try Self.encode(initialDocument).write(to: corpusURL, options: .atomic)
            let checkpoint = CAMIsolatedMiningCheckpoint(
                schemaVersion: 1,
                operationID: operationID,
                runID: run.id,
                planDigest: run.plan.planDigest,
                approvalID: approval.approvalID,
                initialCorpusSHA256: request.expectedCorpusSHA256,
                expectedWriteIDs: request.expectedWriteIDs,
                maximumWriteCount: request.maximumWriteCount,
                startedAt: startedAt
            )
            try Self.encode(checkpoint).write(to: checkpointURL, options: .atomic)
        } catch {
            try? fileManager.removeItem(at: operationRoot)
            throw CAMIsolatedMiningExecutorError.checkpointPersistenceFailed
        }

        let operation = CAMIsolatedMiningOperation(
            corpusURL: corpusURL,
            checkpointURL: checkpointURL
        )
        if isCancellationRequested() {
            return try saveTerminalReceipt(
                operationID: operationID,
                run: run,
                approval: approval,
                status: .cancelled,
                failureCode: "cancelled_before_synthetic_mutation",
                initialCorpusSHA256: request.expectedCorpusSHA256,
                finalCorpusSHA256: nil,
                writeIDs: [],
                startedAt: startedAt,
                operationRoot: operationRoot,
                workspaceRoot: workspaceRoot
            )
        }
        let writes: [String]
        do {
            writes = try adapter.writes(for: operation)
        } catch {
            return try saveTerminalReceipt(
                operationID: operationID,
                run: run,
                approval: approval,
                status: .failed,
                failureCode: "synthetic_adapter_failed",
                initialCorpusSHA256: request.expectedCorpusSHA256,
                finalCorpusSHA256: nil,
                writeIDs: [],
                startedAt: startedAt,
                operationRoot: operationRoot,
                workspaceRoot: workspaceRoot
            )
        }

        let normalizedWrites = writes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        guard normalizedWrites == request.expectedWriteIDs,
              normalizedWrites.count <= request.maximumWriteCount else {
            return try saveTerminalReceipt(
                operationID: operationID,
                run: run,
                approval: approval,
                status: .postconditionFailed,
                failureCode: "unexpected_write_set",
                initialCorpusSHA256: request.expectedCorpusSHA256,
                finalCorpusSHA256: nil,
                writeIDs: normalizedWrites,
                startedAt: startedAt,
                operationRoot: operationRoot,
                workspaceRoot: workspaceRoot
            )
        }

        do {
            let finalDocument = CAMIsolatedMiningCorpusDocument(
                schemaVersion: 1,
                fixtureID: request.corpus.fixtureID,
                repositoryIDs: request.corpus.repositoryIDs,
                writeIDs: normalizedWrites
            )
            let finalData = try Self.encode(finalDocument)
            try finalData.write(to: corpusURL, options: .atomic)
            return try saveTerminalReceipt(
                operationID: operationID,
                run: run,
                approval: approval,
                status: .verified,
                failureCode: nil,
                initialCorpusSHA256: request.expectedCorpusSHA256,
                finalCorpusSHA256: SHA256.hash(data: finalData).hexString,
                writeIDs: normalizedWrites,
                startedAt: startedAt,
                operationRoot: operationRoot,
                workspaceRoot: workspaceRoot
            )
        } catch {
            return try saveTerminalReceipt(
                operationID: operationID,
                run: run,
                approval: approval,
                status: .failed,
                failureCode: "synthetic_corpus_write_failed",
                initialCorpusSHA256: request.expectedCorpusSHA256,
                finalCorpusSHA256: nil,
                writeIDs: normalizedWrites,
                startedAt: startedAt,
                operationRoot: operationRoot,
                workspaceRoot: workspaceRoot
            )
        }
    }

    private func saveTerminalReceipt(
        operationID: UUID,
        run: CAMMiningRun,
        approval: ApprovalReceipt,
        status: CAMIsolatedMiningStatus,
        failureCode: String?,
        initialCorpusSHA256: String,
        finalCorpusSHA256: String?,
        writeIDs: [String],
        startedAt: Date,
        operationRoot: URL,
        workspaceRoot: URL
    ) throws -> CAMIsolatedMiningExecutionResult {
        let fileManager = FileManager.default
        let receiptDirectory = workspaceRoot.appending(
            path: "isolated-cam-mining-receipts",
            directoryHint: .isDirectory
        )
        let receiptURL = receiptDirectory.appending(
            path: "\(operationID.uuidString).json"
        )
        let provisional = CAMIsolatedMiningReceipt(
            schemaVersion: 1,
            operationID: operationID,
            runID: run.id,
            planDigest: run.plan.planDigest,
            approvalID: approval.approvalID,
            status: status,
            failureCode: failureCode,
            initialCorpusSHA256: initialCorpusSHA256,
            finalCorpusSHA256: finalCorpusSHA256,
            writeIDs: writeIDs,
            operationDiscarded: false,
            startedAt: startedAt,
            finishedAt: Date()
        )
        do {
            try fileManager.createDirectory(
                at: receiptDirectory,
                withIntermediateDirectories: true
            )
            try Self.encode(provisional).write(to: receiptURL, options: .atomic)
            try fileManager.removeItem(at: operationRoot)
            let receipt = CAMIsolatedMiningReceipt(
                schemaVersion: provisional.schemaVersion,
                operationID: provisional.operationID,
                runID: provisional.runID,
                planDigest: provisional.planDigest,
                approvalID: provisional.approvalID,
                status: provisional.status,
                failureCode: provisional.failureCode,
                initialCorpusSHA256: provisional.initialCorpusSHA256,
                finalCorpusSHA256: provisional.finalCorpusSHA256,
                writeIDs: provisional.writeIDs,
                operationDiscarded: true,
                startedAt: provisional.startedAt,
                finishedAt: Date()
            )
            try Self.encode(receipt).write(to: receiptURL, options: .atomic)
            return CAMIsolatedMiningExecutionResult(receipt: receipt)
        } catch {
            throw CAMIsolatedMiningExecutorError.receiptPersistenceFailed
        }
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
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

private struct CAMSyntheticMiningCorpusDigestMaterial: Codable {
    let schemaVersion: Int
    let fixtureID: String
    let repositoryIDs: [String]
}

private struct CAMIsolatedMiningCorpusDocument: Codable, Equatable {
    let schemaVersion: Int
    let fixtureID: String
    let repositoryIDs: [String]
    let writeIDs: [String]
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
