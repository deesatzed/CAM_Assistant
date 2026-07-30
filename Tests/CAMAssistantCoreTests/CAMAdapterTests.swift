import CryptoKit
import Foundation
import Testing
@testable import CAMAssistantCore

@Test("pinned CAM capability and runtime snapshots conform without donor execution")
func pinnedCAMSnapshotsConformWithoutDonorExecution() throws {
    let contract = try CAMCapabilityContract.decode(
        Data(contentsOf: camFixtureURL("capabilities.json"))
    )
    let runtime = try CAMRuntimeSchema.decode(
        Data(contentsOf: camFixtureURL("runtime-tools.json"))
    )
    let report = CAMConformanceEvaluator().evaluate(contract: contract, runtime: runtime)

    #expect(contract.hubOwner == "CAM_Codx")
    #expect(contract.runtimeOwner == "CAM_CAM")
    #expect(contract.capability(id: "query_memory")?.toolName == "claw_query_memory")
    #expect(contract.capability(id: "store_finding")?.requiresExactApproval == true)
    #expect(report.missingRuntimeTools.isEmpty)
    #expect(report.unexpectedRuntimeTools.isEmpty)
    #expect(report.isConformant)
}

@Test("CAM contract rejects duplicate capability IDs")
func camContractRejectsDuplicateCapabilityIDs() throws {
    let data = Data(
        """
        {"schemaVersion":1,"sourceContractVersion":"1.0","hubOwner":"CAM_Codx","runtimeOwner":"CAM_CAM","capabilities":[
          {"id":"duplicate","toolName":"claw_one","safetyClass":"read_only_local","requiresExactApproval":false},
          {"id":"duplicate","toolName":"claw_two","safetyClass":"read_only_local","requiresExactApproval":false}
        ]}
        """.utf8
    )

    #expect(throws: CAMContractError.duplicateCapabilityID("duplicate")) {
        _ = try CAMCapabilityContract.decode(data)
    }
}

@Test("CAM adapter proposes capabilities without invoking an unavailable runtime")
func camAdapterProposesCapabilitiesWithoutRuntimeInvocation() throws {
    let contract = try CAMCapabilityContract.decode(
        Data(contentsOf: camFixtureURL("capabilities.json"))
    )
    let runtime = try CAMRuntimeSchema.decode(
        Data(contentsOf: camFixtureURL("runtime-tools.json"))
    )
    let ready = CAMAdapter(
        contract: contract,
        runtime: runtime,
        identity: CAMRuntimeIdentity(
            hubOwner: "CAM_Codx",
            runtimeOwner: "CAM_CAM",
            sourceContractVersion: "1.0",
            runtimeSchemaVersion: 1
        )
    )
    let unavailable = CAMAdapter(contract: contract, runtime: nil, identity: nil)

    #expect(ready.health == .ready)
    #expect(unavailable.health == .unavailable)
    let readOnly = try ready.propose(
        capabilityID: "query_memory",
        inputDigest: "a" + String(repeating: "0", count: 63),
        stateVersion: 4
    )
    let mutation = try ready.propose(
        capabilityID: "store_finding",
        inputDigest: "b" + String(repeating: "0", count: 63),
        stateVersion: 4
    )

    #expect(readOnly.approvalClass == .none)
    #expect(mutation.approvalClass == .exact)
    #expect(mutation.runtimeOwner == "CAM_CAM")
    #expect(ready.status.contractIdentity == "CAM_Codx → CAM_CAM (contract 1.0)")
    #expect(unavailable.status.health == .unavailable)
    #expect(unavailable.status.runtimeMessage == "Runtime not connected; CAM actions are unavailable.")
    #expect(
        throws: CAMAdapterError.runtimeUnavailable
    ) {
        _ = try unavailable.propose(
            capabilityID: "query_memory",
            inputDigest: "a" + String(repeating: "0", count: 63),
            stateVersion: 4
        )
    }
}

@Test("CAM adapter rejects an identity mismatch instead of proposing an action")
func camAdapterRejectsIdentityMismatch() throws {
    let contract = try CAMCapabilityContract.decode(
        Data(contentsOf: camFixtureURL("capabilities.json"))
    )
    let runtime = try CAMRuntimeSchema.decode(
        Data(contentsOf: camFixtureURL("runtime-tools.json"))
    )
    let adapter = CAMAdapter(
        contract: contract,
        runtime: runtime,
        identity: CAMRuntimeIdentity(
            hubOwner: "other-hub",
            runtimeOwner: "CAM_CAM",
            sourceContractVersion: "1.0",
            runtimeSchemaVersion: 1
        )
    )

    #expect(adapter.health == .incompatible)
    #expect(
        throws: CAMAdapterError.incompatibleRuntime
    ) {
        _ = try adapter.propose(
            capabilityID: "query_memory",
            inputDigest: "a" + String(repeating: "0", count: 63),
            stateVersion: 4
        )
    }
}

@Test("CAM mining plan pins bounded repository and runtime identity without source content")
func camMiningPlanPinsBoundedRepositoryAndRuntimeIdentity() throws {
    let pin = try CAMMiningRuntimePin(
        runtimeIdentitySHA256: String(repeating: "1", count: 64),
        configurationSHA256: String(repeating: "2", count: 64),
        databaseSHA256: String(repeating: "3", count: 64)
    )
    let plan = try CAMMiningPlan(
        repositoryCanonicalPath: "/tmp/selected-repository",
        repositoryCommit: String(repeating: "a", count: 40),
        sourceRootIDs: ["Docs", "Sources"],
        runtimePin: pin,
        maxRepositories: 1,
        maxDurationSeconds: 300,
        expectedWrites: ["CAM derived mining receipt"],
        verificationCommand: "cam verify --receipt <id>",
        recoveryDescription: "Cancel the run and preserve the local receipt.",
        idempotencyKey: "mine-selected-repository-a",
        stateVersion: 7
    )

    #expect(plan.sourceRootIDs == ["Docs", "Sources"])
    #expect(plan.runtimePin == pin)
    #expect(plan.planDigest.count == 64)
    #expect(throws: CAMMiningPlanError.invalidSourceRoots) {
        _ = try CAMMiningPlan(
            repositoryCanonicalPath: "/tmp/selected-repository",
            repositoryCommit: String(repeating: "a", count: 40),
            sourceRootIDs: [],
            runtimePin: pin,
            maxRepositories: 1,
            maxDurationSeconds: 300,
            expectedWrites: ["CAM derived mining receipt"],
            verificationCommand: "cam verify --receipt <id>",
            recoveryDescription: "Cancel the run and preserve the local receipt.",
            idempotencyKey: "mine-selected-repository-a",
            stateVersion: 7
        )
    }
}

@Test("CAM mining requires consumed exact approval and cancellation never reports success")
func camMiningRequiresApprovalAndCancellationNeverReportsSuccess() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let plan = try camMiningTestPlan()
    let card = try plan.actionCard(expiresAt: Date(timeIntervalSince1970: 100))
    let approvals = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))
    var run = CAMMiningRun(plan: plan)

    #expect(run.status == .awaitingExactApproval)
    #expect(throws: CAMMiningRunError.missingExactApproval) {
        _ = try run.start(
            approvalID: nil,
            approvalStore: approvals,
            card: card,
            now: Date(timeIntervalSince1970: 10)
        )
    }

    let approval = try approvals.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))
    run = try run.start(
        approvalID: approval.id,
        approvalStore: approvals,
        card: card,
        now: Date(timeIntervalSince1970: 20)
    )
    #expect(run.status == .active)
    #expect(run.approvalReceipt?.approvalID == approval.id)

    let cancelled = try run.cancel(reason: "User cancelled before CAM invocation.")
    #expect(cancelled.status == .cancelled)
    #expect(cancelled.terminalReason == "User cancelled before CAM invocation.")
}

@Test("CAM mining unavailable executor returns a failure receipt without success")
func camMiningUnavailableExecutorReturnsFailureReceiptWithoutSuccess() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let plan = try camMiningTestPlan()
    let card = try plan.actionCard(expiresAt: Date(timeIntervalSince1970: 100))
    let approvals = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))
    let approval = try approvals.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))
    let active = try CAMMiningRun(plan: plan).start(
        approvalID: approval.id,
        approvalStore: approvals,
        card: card,
        now: Date(timeIntervalSince1970: 20)
    )

    let receipt = try CAMMiningUnavailableExecutor().attempt(active)

    #expect(receipt.status == .unavailable)
    #expect(receipt.idempotencyKey == plan.idempotencyKey)
    #expect(receipt.verificationCommand == plan.verificationCommand)
    #expect(receipt.terminalReason.contains("No CAM runtime"))
}

@Test("isolated CAM mining input is synthetic bounded and digest-bound before mutation")
func isolatedCAMMiningInputIsSyntheticBoundedAndDigestBoundBeforeMutation() throws {
    let corpus = try CAMSyntheticMiningCorpus(
        fixtureID: "cam-mining-fixture-v1",
        repositoryIDs: ["fixture-repository"]
    )
    let request = try CAMIsolatedMiningRequest(
        corpus: corpus,
        expectedCorpusSHA256: corpus.sha256,
        expectedWriteIDs: ["methodology:fixture-repository"],
        maximumWriteCount: 1
    )

    #expect(request.corpus.fixtureID == "cam-mining-fixture-v1")
    #expect(request.expectedCorpusSHA256 == corpus.sha256)
    #expect(request.expectedWriteIDs == ["methodology:fixture-repository"])
    #expect(throws: CAMIsolatedMiningRequestError.invalidExpectedCorpusDigest) {
        _ = try CAMIsolatedMiningRequest(
            corpus: corpus,
            expectedCorpusSHA256: String(repeating: "g", count: 64),
            expectedWriteIDs: ["methodology:fixture-repository"],
            maximumWriteCount: 1
        )
    }
    #expect(throws: CAMIsolatedMiningRequestError.invalidBounds) {
        _ = try CAMIsolatedMiningRequest(
            corpus: corpus,
            expectedCorpusSHA256: corpus.sha256,
            expectedWriteIDs: ["methodology:fixture-repository"],
            maximumWriteCount: 0
        )
    }
    let encoded = try JSONEncoder().encode(corpus)
    let tampered = Data(
        String(decoding: encoded, as: UTF8.self)
            .replacingOccurrences(
                of: "cam-mining-fixture-v1",
                with: "cam-mining-forged-v1"
            )
            .utf8
    )
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(CAMSyntheticMiningCorpus.self, from: tampered)
    }
}

@Test("isolated CAM mining persists a bound checkpoint before synthetic mutation")
func isolatedCAMMiningPersistsBoundCheckpointBeforeSyntheticMutation() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let active = try activeCAMMiningTestRun(root: root)
    let corpus = try CAMSyntheticMiningCorpus(
        fixtureID: "cam-mining-checkpoint-v1",
        repositoryIDs: ["fixture-repository"]
    )
    let request = try CAMIsolatedMiningRequest(
        corpus: corpus,
        expectedCorpusSHA256: corpus.sha256,
        expectedWriteIDs: ["methodology:fixture-repository"],
        maximumWriteCount: 1
    )
    let adapter = CAMSyntheticMiningAdapter { operation in
        let data = try Data(contentsOf: operation.checkpointURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let checkpoint = try decoder.decode(
            CAMIsolatedMiningCheckpoint.self,
            from: data
        )
        #expect(checkpoint.planDigest == active.plan.planDigest)
        #expect(checkpoint.approvalID == active.approvalReceipt?.approvalID)
        #expect(checkpoint.initialCorpusSHA256 == corpus.sha256)
        return ["methodology:fixture-repository"]
    }

    let result = try CAMIsolatedMiningExecutor().attempt(
        run: active,
        request: request,
        workspaceRoot: root,
        adapter: adapter
    )

    #expect(result.receipt.status == .verified)
    #expect(result.receipt.operationDiscarded)
    #expect(result.receipt.initialCorpusSHA256 == corpus.sha256)
}

@Test("isolated CAM mining discards only its copy after cancellation or failed postcondition")
func isolatedCAMMiningDiscardsOnlyItsCopyAfterCancellationOrFailedPostcondition() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let active = try activeCAMMiningTestRun(root: root)
    let corpus = try CAMSyntheticMiningCorpus(
        fixtureID: "cam-mining-rollback-v1",
        repositoryIDs: ["fixture-repository"]
    )
    let originalCorpus = corpus
    let request = try CAMIsolatedMiningRequest(
        corpus: corpus,
        expectedCorpusSHA256: corpus.sha256,
        expectedWriteIDs: ["methodology:fixture-repository"],
        maximumWriteCount: 1
    )
    let executor = CAMIsolatedMiningExecutor()
    let cancelled = try executor.attempt(
        run: active,
        request: request,
        workspaceRoot: root,
        adapter: CAMSyntheticMiningAdapter { _ in
            ["unexpected-write"]
        },
        isCancellationRequested: { true }
    )
    let postconditionFailure = try executor.attempt(
        run: active,
        request: request,
        workspaceRoot: root,
        adapter: CAMSyntheticMiningAdapter { _ in
            ["unexpected-write"]
        }
    )

    #expect(cancelled.receipt.status == .cancelled)
    #expect(cancelled.receipt.failureCode == "cancelled_before_synthetic_mutation")
    #expect(cancelled.receipt.operationDiscarded)
    #expect(postconditionFailure.receipt.status == .postconditionFailed)
    #expect(postconditionFailure.receipt.failureCode == "unexpected_write_set")
    #expect(postconditionFailure.receipt.operationDiscarded)
    #expect(postconditionFailure.receipt.finalCorpusSHA256 == nil)
    #expect(corpus == originalCorpus)
    for operationID in [cancelled.receipt.operationID, postconditionFailure.receipt.operationID] {
        let operationURL = root
            .appending(path: "isolated-cam-mining-operations", directoryHint: .isDirectory)
            .appending(path: operationID.uuidString, directoryHint: .isDirectory)
        #expect(!FileManager.default.fileExists(atPath: operationURL.path))
    }
}

@Test("CAM runtime inspection pins executable config and database bytes without execution")
func camRuntimeInspectionPinsSelectedBytesWithoutExecution() throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }

    let pin = try fixture.inspect()

    #expect(pin.schemaVersion == 2)
    #expect(pin.distributionName == "claw")
    #expect(
        pin.executableSHA256
            == (try CAMRuntimeInspector.sha256(of: fixture.executableURL))
    )
    #expect(pin.identitySHA256.count == 64)
}

@Test("closed CAM tool request accepts only a bounded enumerated operation")
func camClosedToolRequestValidatesClosedContract() throws {
    let identity = String(repeating: "a", count: 64)
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: identity,
        idempotencyKey: "stats-checkpoint-1",
        maximumAttempts: 2,
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )

    #expect(request.toolID == .statistics)
    #expect(request.runtimeIdentitySHA256 == identity)
    #expect(request.idempotencyKey == "stats-checkpoint-1")
    #expect(request.maximumAttempts == 2)

    #expect(throws: CAMClosedToolRequestError.invalidRuntimeIdentity) {
        _ = try CAMClosedToolRequest(
            toolID: .statistics,
            runtimeIdentitySHA256: "not-a-digest",
            idempotencyKey: "stats-checkpoint-1"
        )
    }
    #expect(throws: CAMClosedToolRequestError.invalidIdempotencyKey) {
        _ = try CAMClosedToolRequest(
            toolID: .statistics,
            runtimeIdentitySHA256: identity,
            idempotencyKey: "../escape"
        )
    }
    #expect(throws: CAMClosedToolRequestError.invalidBounds) {
        _ = try CAMClosedToolRequest(
            toolID: .statistics,
            runtimeIdentitySHA256: identity,
            idempotencyKey: "stats-checkpoint-1",
            maximumAttempts: 4
        )
    }
}

@Test("closed CAM tool executes typed statistics only on disposable state")
func camClosedToolExecutesTypedDisposableStatistics() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .liveStatsSuccess)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-success",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )

    let result = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )
    let receipt = result.receipt

    #expect(result.replayed == false)
    #expect(receipt.toolID == .statistics)
    #expect(receipt.status == .verified)
    #expect(receipt.failureCode == nil)
    #expect(receipt.attemptCount == 1)
    #expect(receipt.processExitCode == 0)
    #expect(receipt.statistics?.methodologyCount == 12)
    #expect(receipt.statistics?.sourceRepositoryCount == 3)
    #expect(receipt.runtimeIdentitySHA256 == pin.identitySHA256)
    #expect(receipt.donorSurfaceEvidence.allSatisfy {
        $0.beforeSHA256 == $0.afterSHA256
    })
    #expect(receipt.disposableDatabaseSHA256Before != nil)
    #expect(receipt.disposableDatabaseSHA256After != nil)
    #expect(receipt.sandboxed)
    #expect(!receipt.workspaceRetained)
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("closed CAM tool sandbox denies writes outside its disposable operation")
func camClosedToolSandboxDeniesExternalWrites() async throws {
    let fixture = try CAMInstalledRuntimeFixture(
        behavior: .liveStatsExternalWrite
    )
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-external-write",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )

    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .failed)
    #expect(receipt.failureCode == "process_failed")
    #expect(receipt.processExitCode != 0)
    #expect(!FileManager.default.fileExists(atPath: fixture.externalMarkerURL.path))
    #expect(receipt.donorSurfaceEvidence.allSatisfy {
        $0.beforeSHA256 == $0.afterSHA256
    })
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool rejects output for any database except its copy")
func camClosedToolRejectsWrongDatabaseOutput() async throws {
    let fixture = try CAMInstalledRuntimeFixture(
        behavior: .liveStatsWrongDatabase
    )
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-wrong-database",
        timeoutSeconds: 5
    )

    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .postconditionFailed)
    #expect(receipt.failureCode == "database_path_mismatch")
    #expect(receipt.statistics == nil)
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool rejects selected runtime drift before launch")
func camClosedToolRejectsRuntimeDriftBeforeLaunch() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .liveStatsSuccess)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    try Data("# runtime drift\n".utf8).append(to: fixture.packageCLIURL)
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-runtime-drift",
        timeoutSeconds: 5
    )

    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .drifted)
    #expect(receipt.failureCode == "runtime_drift")
    #expect(receipt.attemptCount == 0)
}

@Test("closed CAM tool timeout kills the child and records bounded facts")
func camClosedToolTimeoutTerminatesChild() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .ignoresTermination)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-timeout",
        timeoutSeconds: 0.05,
        maximumOutputBytes: 16_384
    )

    let started = ContinuousClock.now
    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .timedOut)
    #expect(receipt.failureCode == "process_timed_out")
    #expect(receipt.processExitCode != nil)
    #expect(started.duration(to: .now) < .seconds(2))
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool cancellation wins and records child termination")
func camClosedToolCancellationTerminatesChild() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .ignoresTermination)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-cancel",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )
    let task = Task {
        await CAMClosedToolExecutor().attempt(
            request: request,
            pin: pin,
            workspaceRoot: fixture.workspaceURL
        )
    }
    try await Task.sleep(for: .milliseconds(30))
    task.cancel()

    let receipt = await task.value.receipt

    #expect(receipt.status == .cancelled)
    #expect(receipt.failureCode == "process_cancelled")
    #expect(receipt.processExitCode != nil)
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool output limit records counts without retaining bytes")
func camClosedToolOutputLimitRecordsBoundedFacts() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .oversizedStderr)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-output-limit",
        timeoutSeconds: 5,
        maximumOutputBytes: 1_024
    )

    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .outputLimited)
    #expect(receipt.failureCode == "output_too_large")
    #expect(receipt.stderrByteCount > request.maximumOutputBytes)
    #expect(receipt.stderrSHA256 != nil)
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool retries only a retryable failure on a fresh attempt")
func camClosedToolRetriesRetryableFailure() async throws {
    let fixture = try CAMInstalledRuntimeFixture(
        behavior: .liveStatsFailsFirstAttempt
    )
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-retry",
        maximumAttempts: 2,
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )

    let receipt = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    ).receipt

    #expect(receipt.status == .verified)
    #expect(receipt.failureCode == nil)
    #expect(receipt.attemptCount == 2)
    #expect(receipt.statistics?.methodologyCount == 12)
    #expect(!receipt.workspaceRetained)
}

@Test("closed CAM tool replays one identical terminal idempotency receipt")
func camClosedToolReplaysIdenticalTerminalReceipt() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .liveStatsSuccess)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-idempotent",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )
    let executor = CAMClosedToolExecutor()

    let first = await executor.attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )
    try Data("# drift after terminal receipt\n".utf8)
        .append(to: fixture.packageCLIURL)
    let replay = await executor.attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )

    #expect(first.receipt.status == .verified)
    #expect(!first.replayed)
    #expect(replay.replayed)
    #expect(replay.receipt == first.receipt)
}

@Test("closed CAM tool refuses an idempotency key bound to another request")
func camClosedToolRefusesConflictingIdempotencyRequest() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .liveStatsSuccess)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let original = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-conflict",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )
    let conflict = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-conflict",
        timeoutSeconds: 6,
        maximumOutputBytes: 16_384
    )
    let executor = CAMClosedToolExecutor()
    let first = await executor.attempt(
        request: original,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )

    let refused = await executor.attempt(
        request: conflict,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )

    #expect(first.receipt.status == .verified)
    #expect(refused.receipt.status == .failed)
    #expect(refused.receipt.failureCode == "idempotency_conflict")
    #expect(refused.receipt.attemptCount == 0)
    #expect(!refused.replayed)
}

@Test("closed CAM tool fails closed when a prior durable run is interrupted")
func camClosedToolRecoversInterruptedDurableRunWithoutLaunchingAgain() async throws {
    let fixture = try CAMInstalledRuntimeFixture(
        behavior: .liveStatsExternalWrite
    )
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let request = try CAMClosedToolRequest(
        toolID: .statistics,
        runtimeIdentitySHA256: pin.identitySHA256,
        idempotencyKey: "live-stats-interrupted",
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )
    let keyDigest = SHA256.hash(data: Data(request.idempotencyKey.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
    let journalURL = fixture.workspaceURL
        .appending(path: "closed-cam-inflight")
        .appending(path: "\(keyDigest).json")
    try FileManager.default.createDirectory(
        at: journalURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let journal = """
    {"idempotencyKey":"\(request.idempotencyKey)","requestSHA256":"\(request.requestSHA256)","runtimeIdentitySHA256":"\(pin.identitySHA256)","schemaVersion":1,"startedAt":"2026-07-30T00:00:00Z","toolID":"\(request.toolID.rawValue)"}
    """
    try Data(journal.utf8).write(to: journalURL, options: .atomic)

    let interrupted = try CAMClosedToolExecutor.interruptedRuns(
        workspaceRoot: fixture.workspaceURL
    )
    let expectedStartedAt = try #require(
        ISO8601DateFormatter().date(from: "2026-07-30T00:00:00Z")
    )

    #expect(interrupted.count == 1)
    #expect(interrupted[0].toolID == .statistics)
    #expect(interrupted[0].requestSHA256 == request.requestSHA256)
    #expect(interrupted[0].runtimeIdentitySHA256 == pin.identitySHA256)
    #expect(interrupted[0].startedAt == expectedStartedAt)

    let result = await CAMClosedToolExecutor().attempt(
        request: request,
        pin: pin,
        workspaceRoot: fixture.workspaceURL
    )

    #expect(!result.replayed)
    #expect(result.receipt.status == .failed)
    #expect(result.receipt.failureCode == "interrupted_previous_run")
    #expect(result.receipt.attemptCount == 0)
    #expect(result.receipt.statistics == nil)
    #expect(!result.receipt.sandboxed)
    #expect(!FileManager.default.fileExists(atPath: fixture.externalMarkerURL.path))
    #expect(FileManager.default.fileExists(atPath: journalURL.path))
}

@Test("closed CAM statistics probe reads only a disposable snapshot and returns typed evidence")
func closedCAMStatisticsProbeReadsOnlyDisposableSnapshot() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let pin = try fixture.inspect()

    let receipt = try await CAMDisposableStatisticsProbe().run(
        pin: pin,
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5,
        maximumOutputBytes: 16_384
    )

    #expect(receipt.toolID == "cam.stats.snapshot.v1")
    #expect(receipt.status == .verified)
    #expect(receipt.statistics?.methodologyCount == 12)
    #expect(receipt.statistics?.sourceRepositoryCount == 3)
    #expect(receipt.donorDatabaseSHA256Before == pin.databaseSHA256)
    #expect(receipt.donorDatabaseSHA256After == pin.databaseSHA256)
    #expect(receipt.disposableDatabaseSHA256Before == pin.databaseSHA256)
    #expect(receipt.disposableDatabaseSHA256After == pin.databaseSHA256)
    #expect(receipt.donorSurfaceEvidence.count == 6)
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM statistics probe refuses runtime drift before process invocation")
func camStatisticsProbeRefusesRuntimeDriftBeforeInvocation() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    try Data("changed configuration".utf8).write(
        to: fixture.configurationURL,
        options: .atomic
    )

    await #expect(throws: CAMRuntimeProbeError.runtimeDrift(.configuration)) {
        _ = try await CAMDisposableStatisticsProbe().run(
            pin: pin,
            workspaceRoot: fixture.workspaceURL,
            timeoutSeconds: 5
        )
    }
}

@Test("CAM CLI creates a pin then a typed disposable statistics receipt")
func camCLICreatesPinAndDisposableStatisticsReceipt() throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let pinURL = fixture.root.appending(path: "runtime-pin.json")
    let receiptURL = fixture.root.appending(path: "runtime-receipt.json")
    let cli = try camDebugCLIURL()

    let inspect = Process()
    inspect.executableURL = cli
    inspect.arguments = [
        "cam",
        "runtime-inspect",
        fixture.executableURL.path,
        fixture.configurationURL.path,
        fixture.databaseURL.path,
        pinURL.path,
    ]
    try inspect.run()
    inspect.waitUntilExit()
    #expect(inspect.terminationStatus == 0)
    #expect(FileManager.default.fileExists(atPath: pinURL.path))

    let probe = Process()
    probe.executableURL = cli
    probe.arguments = [
        "cam",
        "runtime-probe",
        pinURL.path,
        fixture.workspaceURL.path,
        receiptURL.path,
        "--timeout-seconds",
        "5",
    ]
    try probe.run()
    probe.waitUntilExit()
    #expect(probe.terminationStatus == 0)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let receipt = try decoder.decode(
        CAMRuntimeProbeReceipt.self,
        from: Data(contentsOf: receiptURL)
    )
    #expect(receipt.status == .verified)
    #expect(receipt.statistics?.methodologyCount == 12)
}

@Test("CAM CLI executes and replays the closed disposable statistics tool")
func camCLIExecutesClosedDisposableStatisticsTool() throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .liveStatsSuccess)
    defer { fixture.remove() }
    let pin = try fixture.inspect()
    let pinURL = fixture.root.appending(path: "closed-runtime-pin.json")
    let receiptURL = fixture.root.appending(path: "closed-runtime-receipt.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(pin).write(to: pinURL, options: .atomic)
    let cli = try camDebugCLIURL()

    for _ in 0..<2 {
        let process = Process()
        process.executableURL = cli
        process.arguments = [
            "cam",
            "runtime-execute-stats",
            pinURL.path,
            fixture.workspaceURL.path,
            receiptURL.path,
            "cli-closed-stats",
            "--timeout-seconds",
            "5",
            "--maximum-attempts",
            "2",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let receipt = try decoder.decode(
        CAMClosedToolReceipt.self,
        from: Data(contentsOf: receiptURL)
    )
    #expect(receipt.status == .verified)
    #expect(receipt.toolID == .statistics)
    #expect(receipt.statistics?.methodologyCount == 12)
    #expect(receipt.statistics?.sourceRepositoryCount == 3)
    #expect(receipt.idempotencyKey == "cli-closed-stats")
}

@Test("CAM runtime pin derives interpreter package metadata and source commit")
func camRuntimePinDerivesInstalledRuntimeIdentity() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }

    let pin = try CAMRuntimeInspector().inspect(
        executableURL: fixture.executableURL,
        configurationURL: fixture.configurationURL,
        databaseURL: fixture.databaseURL
    )

    #expect(pin.distributionName == "claw")
    #expect(pin.distributionVersion == "0.1.0")
    #expect(pin.entryPoint == "claw.cli:app_main")
    #expect(pin.sourceCommit == fixture.sourceCommit)
    #expect(pin.interpreterSHA256.count == 64)
    #expect(pin.packageSHA256.count == 64)
    #expect(pin.installationMetadataSHA256.count == 64)

    try Data("# drift".utf8).append(to: fixture.packageCLIURL)
    await #expect(throws: CAMRuntimeProbeError.runtimeDrift(.package)) {
        _ = try await CAMDisposableStatisticsProbe().run(
            pin: pin,
            workspaceRoot: fixture.workspaceURL,
            timeoutSeconds: 2
        )
    }
}

@Test("CAM native snapshot probe never launches selected executable behavior")
func camNativeSnapshotProbeNeverLaunchesSelectedExecutable() async throws {
    let oversized = try CAMInstalledRuntimeFixture(behavior: .oversizedStderr)
    defer { oversized.remove() }
    let oversizedPin = try oversized.inspect()
    let oversizedReceipt = await CAMDisposableStatisticsProbe().attempt(
        pin: oversizedPin,
        workspaceRoot: oversized.workspaceURL,
        timeoutSeconds: 2,
        maximumOutputBytes: 1_024
    )
    #expect(oversizedReceipt.status == .verified)
    #expect(oversizedReceipt.stderrByteCount == 0)

    let hanging = try CAMInstalledRuntimeFixture(behavior: .ignoresTermination)
    defer { hanging.remove() }
    let hangingPin = try hanging.inspect()
    let started = ContinuousClock.now
    let timeoutReceipt = await CAMDisposableStatisticsProbe().attempt(
        pin: hangingPin,
        workspaceRoot: hanging.workspaceURL,
        timeoutSeconds: 0.1
    )
    #expect(timeoutReceipt.status == .verified)
    #expect(started.duration(to: .now) < .seconds(2))
}

@Test("CAM native probe cannot execute external writes and cleans its snapshot")
func camNativeProbeCannotExecuteExternalWritesAndCleansWorkspace() async throws {
    let fixture = try CAMInstalledRuntimeFixture(behavior: .attemptExternalWrite)
    defer { fixture.remove() }
    let receipt = await CAMDisposableStatisticsProbe().attempt(
        pin: try fixture.inspect(),
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 2
    )

    #expect(receipt.status == .verified)
    #expect(!FileManager.default.fileExists(atPath: fixture.externalMarkerURL.path))
    #expect(receipt.workspaceRetained == false)
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM native probe cancellation wins before verified completion")
func camNativeProbeCancellationWinsBeforeVerifiedCompletion() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let (entered, signal) = AsyncStream<Void>.makeStream()
    let pin = try fixture.inspect()
    let probe = CAMDisposableStatisticsProbe(checkpointHook: { checkpoint, _ in
        guard checkpoint == .beforeVerified else { return }
        signal.yield()
        try await Task.sleep(for: .seconds(30))
    })
    let task = Task {
        await probe.attempt(
            pin: pin,
            workspaceRoot: fixture.workspaceURL,
            timeoutSeconds: 5
        )
    }

    for await _ in entered { break }
    task.cancel()
    let receipt = await task.value
    signal.finish()

    #expect(receipt.status == .cancelled)
    #expect(receipt.failureCode == "process_cancelled")
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM native probe enforces its monotonic deadline")
func camNativeProbeEnforcesMonotonicDeadline() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let probe = CAMDisposableStatisticsProbe(checkpointHook: { checkpoint, _ in
        guard checkpoint == .afterSnapshot else { return }
        try await Task.sleep(for: .milliseconds(100))
    })

    let receipt = await probe.attempt(
        pin: try fixture.inspect(),
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 0.01
    )

    #expect(receipt.status == .timedOut)
    #expect(receipt.failureCode == "process_timed_out")
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM native probe cannot verify a mutated disposable database")
func camNativeProbeCannotVerifyMutatedDisposableDatabase() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let probe = CAMDisposableStatisticsProbe(
        checkpointHook: { checkpoint, databaseURL in
            guard checkpoint == .afterStatistics else { return }
            try Data("mutation".utf8).append(to: databaseURL)
        }
    )

    let receipt = await probe.attempt(
        pin: try fixture.inspect(),
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5
    )

    #expect(receipt.status == .drifted)
    #expect(receipt.failureCode == "disposable_database_mutated")
    #expect(!FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM native probe reports a retained workspace when cleanup fails")
func camNativeProbeReportsRetainedWorkspaceOnCleanupFailure() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let probe = CAMDisposableStatisticsProbe(
        cleanupHandler: { _ in
            throw CAMRuntimeProbeTestError.forcedCleanupFailure
        }
    )

    let receipt = await probe.attempt(
        pin: try fixture.inspect(),
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5
    )

    #expect(receipt.status == .failed)
    #expect(receipt.failureCode == "workspace_cleanup_failed")
    #expect(receipt.workspaceRetained)
    #expect(FileManager.default.fileExists(atPath: receipt.workspaceURL.path))
}

@Test("CAM runtime pin enforces a deadline during bounded surface hashing")
func camRuntimePinEnforcesDeadlineDuringSurfaceHashing() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let largePackageFile = fixture.packageRootURL.appending(
        path: "bounded-large-fixture.bin"
    )
    #expect(
        FileManager.default.createFile(
            atPath: largePackageFile.path,
            contents: nil
        )
    )
    let handle = try FileHandle(forWritingTo: largePackageFile)
    try handle.truncate(atOffset: 134_217_728)
    try handle.close()
    let started = ContinuousClock.now

    do {
        _ = try await CAMRuntimeInspector().inspectBounded(
            executableURL: fixture.executableURL,
            configurationURL: fixture.configurationURL,
            databaseURL: fixture.databaseURL,
            timeoutSeconds: 0.005
        )
        Issue.record("Expected bounded runtime inspection to time out.")
    } catch {
        #expect(error as? CAMRuntimeProbeError == .processTimedOut)
    }

    #expect(started.duration(to: .now) < .seconds(1))
}

@Test("CAM runtime pin cancellation interrupts initial package hashing")
func camRuntimePinCancellationInterruptsInitialHashing() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let largePackageFile = fixture.packageRootURL.appending(
        path: "cancellable-large-fixture.bin"
    )
    #expect(
        FileManager.default.createFile(
            atPath: largePackageFile.path,
            contents: nil
        )
    )
    let handle = try FileHandle(forWritingTo: largePackageFile)
    try handle.truncate(atOffset: 536_870_912)
    try handle.close()
    let task = Task {
        try await CAMRuntimeInspector().inspectBounded(
            executableURL: fixture.executableURL,
            configurationURL: fixture.configurationURL,
            databaseURL: fixture.databaseURL,
            timeoutSeconds: 5
        )
    }
    try await Task.sleep(for: .milliseconds(5))
    task.cancel()

    do {
        _ = try await task.value
        Issue.record("Expected runtime inspection cancellation.")
    } catch {
        #expect(error as? CAMRuntimeProbeError == .processCancelled)
    }
}

@Test("CAM inspector rejects inline config credentials before copying")
func camInspectorRejectsInlineConfigCredentials() throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    try Data("api_key = \"sk-live-secret-value\"\n".utf8).write(
        to: fixture.configurationURL,
        options: .atomic
    )

    #expect(throws: CAMRuntimeProbeError.configurationContainsSecret) {
        _ = try fixture.inspect()
    }
}

@Test("CAM SQLite snapshot includes committed WAL state")
func camSQLiteSnapshotIncludesCommittedWALState() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-wal-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    let source = root.appending(path: "source.db")
    let snapshot = root.appending(path: "snapshot.db")
    let store = try SQLiteStore(databaseURL: source, migrations: [])
    _ = try store.query("PRAGMA journal_mode = WAL")
    _ = try store.query("PRAGMA wal_autocheckpoint = 0")
    try store.execute("CREATE TABLE proof(value TEXT NOT NULL)")
    try store.execute("INSERT INTO proof(value) VALUES ('committed-in-wal')")

    try CAMSQLiteSnapshotter.copy(source: source, destination: snapshot)
    let copied = try SQLiteStore(databaseURL: snapshot, migrations: [])
    #expect(
        try copied.query("SELECT value FROM proof").first?.first
            == "committed-in-wal"
    )
}

@Test("CAM probe reads a closed WAL-mode database without creating sidecars")
func camProbeReadsClosedWALDatabaseWithoutCreatingSidecars() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let database = try SQLiteStore(
        databaseURL: fixture.databaseURL,
        migrations: []
    )
    _ = try database.query("PRAGMA journal_mode = WAL")
    try database.close()
    let walURL = URL(filePath: fixture.databaseURL.path + "-wal")
    let shmURL = URL(filePath: fixture.databaseURL.path + "-shm")
    #expect(!FileManager.default.fileExists(atPath: walURL.path))
    #expect(!FileManager.default.fileExists(atPath: shmURL.path))
    let pin = try fixture.inspect()

    let receipt = await CAMDisposableStatisticsProbe().attempt(
        pin: pin,
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5
    )

    #expect(receipt.status == .verified)
    #expect(receipt.statistics?.methodologyCount == 12)
    #expect(receipt.disposableDatabaseSHA256Before == pin.databaseSHA256)
    #expect(receipt.disposableDatabaseSHA256After == pin.databaseSHA256)
    #expect(!FileManager.default.fileExists(atPath: walURL.path))
    #expect(!FileManager.default.fileExists(atPath: shmURL.path))
}

@Test("CAM probe reads active WAL state and preserves donor family bytes")
func camProbeReadsActiveWALStateAndPreservesDonorBytes() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let database = try SQLiteStore(
        databaseURL: fixture.databaseURL,
        migrations: []
    )
    defer { try? database.close() }
    _ = try database.query("PRAGMA journal_mode = WAL")
    _ = try database.query("PRAGMA wal_autocheckpoint = 0")
    try database.execute(
        """
        INSERT INTO methodologies(
            name,
            lifecycle_state,
            tags
        ) VALUES (?, ?, ?)
        """,
        bindings: [
            "active-wal-methodology",
            "viable",
            "[\"source:active-wal-repository\"]",
        ]
    )
    let familyURLs = ["", "-wal", "-shm"].map {
        URL(filePath: fixture.databaseURL.path + $0)
    }
    #expect(familyURLs.allSatisfy {
        FileManager.default.fileExists(atPath: $0.path)
    })
    let donorBefore = try familyURLs.map {
        try CAMRuntimeInspector.sha256(of: $0)
    }
    let pin = try fixture.inspect()

    let receipt = await CAMDisposableStatisticsProbe().attempt(
        pin: pin,
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5
    )
    let donorAfter = try familyURLs.map {
        try CAMRuntimeInspector.sha256(of: $0)
    }

    #expect(receipt.status == .verified)
    #expect(receipt.statistics?.methodologyCount == 13)
    #expect(receipt.statistics?.sourceRepositoryCount == 4)
    #expect(donorAfter == donorBefore)
    #expect(receipt.donorDatabaseSHA256Before == pin.databaseSHA256)
    #expect(receipt.donorDatabaseSHA256After == pin.databaseSHA256)
}

@Test("CAM probe rejects an oversized statistics scan")
func camProbeRejectsOversizedStatisticsScan() async throws {
    let fixture = try CAMInstalledRuntimeFixture()
    defer { fixture.remove() }
    let database = try SQLiteStore(
        databaseURL: fixture.databaseURL,
        migrations: []
    )
    try database.execute(
        "UPDATE methodologies SET tags = ? WHERE id = 1",
        bindings: [String(repeating: "x", count: 1_048_577)]
    )
    try database.close()
    let pin = try fixture.inspect()

    let receipt = await CAMDisposableStatisticsProbe().attempt(
        pin: pin,
        workspaceRoot: fixture.workspaceURL,
        timeoutSeconds: 5
    )

    #expect(receipt.status == .outputLimited)
    #expect(receipt.failureCode == "statistics_limit_exceeded")
}

private func camFixtureURL(_ name: String) -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/CAM/v1/\(name)")
}

private func camMiningTestPlan() throws -> CAMMiningPlan {
    let pin = try CAMMiningRuntimePin(
        runtimeIdentitySHA256: String(repeating: "1", count: 64),
        configurationSHA256: String(repeating: "2", count: 64),
        databaseSHA256: String(repeating: "3", count: 64)
    )
    return try CAMMiningPlan(
        repositoryCanonicalPath: "/tmp/selected-repository",
        repositoryCommit: String(repeating: "a", count: 40),
        sourceRootIDs: ["Docs", "Sources"],
        runtimePin: pin,
        maxRepositories: 1,
        maxDurationSeconds: 300,
        expectedWrites: ["CAM derived mining receipt"],
        verificationCommand: "cam verify --receipt <id>",
        recoveryDescription: "Cancel the run and preserve the local receipt.",
        idempotencyKey: "mine-selected-repository-a",
        stateVersion: 7
    )
}

private func activeCAMMiningTestRun(root: URL) throws -> CAMMiningRun {
    let plan = try camMiningTestPlan()
    let card = try plan.actionCard(expiresAt: Date(timeIntervalSince1970: 100))
    let approvals = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))
    let approval = try approvals.approve(
        card,
        source: "user",
        now: Date(timeIntervalSince1970: 10)
    )
    return try CAMMiningRun(plan: plan).start(
        approvalID: approval.id,
        approvalStore: approvals,
        card: card,
        now: Date(timeIntervalSince1970: 20)
    )
}

private func camDebugCLIURL() throws -> URL {
    let repositoryRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let candidates = [
        repositoryRoot.appending(path: ".swift-build/debug/cam-assistant"),
        repositoryRoot.appending(path: ".swift-build/arm64-apple-macosx/debug/cam-assistant"),
    ]
    guard let candidate = candidates.first(where: {
        FileManager.default.isExecutableFile(atPath: $0.path)
    }) else {
        throw CAMRuntimeProbeTestError.cliUnavailable
    }
    return candidate
}

private enum CAMRuntimeProbeTestError: Error {
    case cliUnavailable
    case gitFailure
    case forcedCleanupFailure
}

private enum CAMInstalledRuntimeBehavior {
    case success
    case oversizedStderr
    case ignoresTermination
    case attemptExternalWrite
    case liveStatsSuccess
    case liveStatsExternalWrite
    case liveStatsWrongDatabase
    case liveStatsFailsFirstAttempt
}

private struct CAMInstalledRuntimeFixture {
    let root: URL
    let environmentRoot: URL
    let executableURL: URL
    let interpreterURL: URL
    let configurationURL: URL
    let databaseURL: URL
    let workspaceURL: URL
    let externalMarkerURL: URL
    let packageRootURL: URL
    let packageCLIURL: URL
    let sourceCommit: String

    init(
        behavior: CAMInstalledRuntimeBehavior = .success
    ) throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "cam-installed-runtime-\(UUID().uuidString)")
        environmentRoot = root.appending(path: "env")
        executableURL = environmentRoot.appending(path: "bin/cam")
        interpreterURL = environmentRoot.appending(path: "bin/python3")
        configurationURL = root.appending(path: "claw.toml")
        databaseURL = root.appending(path: "claw.db")
        workspaceURL = root.appending(path: "workspace")
        externalMarkerURL = root.appending(path: "outside-workspace")
        let sitePackages = environmentRoot
            .appending(path: "lib/python3.13/site-packages")
        let sourceRepository = root.appending(path: "runtime-source")
        packageRootURL = sourceRepository.appending(path: "src/claw")
        packageCLIURL = packageRootURL.appending(path: "cli.py")

        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: sitePackages,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: packageRootURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: interpreterURL,
            withDestinationURL: URL(filePath: "/bin/sh")
        )
        try Data("# synthetic claw package\n".utf8).write(
            to: packageRootURL.appending(path: "__init__.py")
        )
        try Data("def app_main(): return 0\n".utf8).write(to: packageCLIURL)

        let distInfo = sitePackages.appending(path: "claw-0.1.0.dist-info")
        try FileManager.default.createDirectory(
            at: distInfo,
            withIntermediateDirectories: true
        )
        try Data("Name: claw\nVersion: 0.1.0\n".utf8)
            .write(to: distInfo.appending(path: "METADATA"))
        try Data("[console_scripts]\ncam = claw.cli:app_main\n".utf8)
            .write(to: distInfo.appending(path: "entry_points.txt"))
        let finder = sitePackages.appending(
            path: "__editable___claw_0_1_0_finder.py"
        )
        try Data(
            "MAPPING = {'claw': '\(packageRootURL.path)'}\n".utf8
        ).write(to: finder)
        try Data(
            "import __editable___claw_0_1_0_finder\n".utf8
        ).write(
            to: sitePackages.appending(path: "__editable__.claw-0.1.0.pth")
        )

        let script: String
        switch behavior {
        case .success:
            script = CAMInstalledRuntimeFixture.successScript
        case .oversizedStderr:
            script = """
            i=0
            while [ "$i" -lt 20000 ]; do
              printf x >&2
              i=$((i + 1))
            done
            """
        case .ignoresTermination:
            script = """
            trap '' TERM
            while :; do :; done
            """
        case .attemptExternalWrite:
            script = """
            if printf forbidden > "\(externalMarkerURL.path)"; then
              exit 91
            fi
            \(CAMInstalledRuntimeFixture.successScript)
            """
        case .liveStatsSuccess:
            script = CAMInstalledRuntimeFixture.liveStatsScript(
                databasePath: "$CLAW_DB_PATH"
            )
        case .liveStatsExternalWrite:
            script = """
            printf forbidden > "\(externalMarkerURL.path)" || exit 91
            \(CAMInstalledRuntimeFixture.liveStatsScript(
                databasePath: "$CLAW_DB_PATH"
            ))
            """
        case .liveStatsWrongDatabase:
            script = CAMInstalledRuntimeFixture.liveStatsScript(
                databasePath: "/tmp/not-the-disposable-database"
            )
        case .liveStatsFailsFirstAttempt:
            script = """
            if [ "$CAM_ASSISTANT_ATTEMPT" = "1" ]; then
              exit 75
            fi
            \(CAMInstalledRuntimeFixture.liveStatsScript(
                databasePath: "$CLAW_DB_PATH"
            ))
            """
        }
        try Data(
            """
            #!\(interpreterURL.path)
            # from claw.cli import app_main
            \(script)
            """.utf8
        ).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )
        try Data(
            """
            [database]
            path = "claw.db"
            api_key_env = ""
            [instances]
            enabled = true
            """.utf8
        )
            .write(to: configurationURL)
        let database = try SQLiteStore(databaseURL: databaseURL, migrations: [])
        try database.execute(
            """
            CREATE TABLE methodologies(
                id INTEGER PRIMARY KEY,
                name TEXT,
                lifecycle_state TEXT NOT NULL,
                tags TEXT
            )
            """
        )
        for index in 0..<12 {
            let state = index < 9
                ? "embryonic"
                : (index < 11 ? "viable" : "thriving")
            let source = index % 3
            try database.execute(
                """
                INSERT INTO methodologies(
                    name,
                    lifecycle_state,
                    tags
                ) VALUES (?, ?, ?)
                """,
                bindings: [
                    "synthetic-\(index)",
                    state,
                    "[\"source:repo-\(source)\"]",
                ]
            )
        }
        try database.close()

        try Self.runGit(["init"], at: sourceRepository)
        try Self.runGit(["config", "user.name", "CAM Test"], at: sourceRepository)
        try Self.runGit(
            ["config", "user.email", "cam-test@example.invalid"],
            at: sourceRepository
        )
        try Self.runGit(["add", "."], at: sourceRepository)
        try Self.runGit(["commit", "-m", "fixture"], at: sourceRepository)
        sourceCommit = try Self.gitOutput(
            ["rev-parse", "HEAD"],
            at: sourceRepository
        )
    }

    func inspect() throws -> CAMVerifiedRuntimePin {
        try CAMRuntimeInspector().inspect(
            executableURL: executableURL,
            configurationURL: configurationURL,
            databaseURL: databaseURL
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    private static let successScript = """
    printf x >> "$CLAW_DB_PATH"
    printf '%s' '{"methodology_count":12,"source_repo_count":3,"lifecycle_states":{"embryonic":9,"viable":2,"thriving":1,"declining":0},"federation_enabled":true}'
    """

    private static func liveStatsScript(databasePath: String) -> String {
        """
        printf '{"ganglion":"synthetic","ganglion_description":"","methodology_count":12,"active_methodology_count":3,"source_repo_count":3,"lifecycle_states":{"embryonic":9,"viable":2,"thriving":1},"federation_enabled":true,"sibling_count":0,"db_path":"%s","cag":{"enabled":false,"loaded":false,"methodology_count":0}}' "\(databasePath)"
        """
    }

    private static func runGit(_ arguments: [String], at root: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CAMRuntimeProbeTestError.gitFailure
        }
    }

    private static func gitOutput(
        _ arguments: [String],
        at root: URL
    ) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.currentDirectoryURL = root
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CAMRuntimeProbeTestError.gitFailure
        }
        return String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Data {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
