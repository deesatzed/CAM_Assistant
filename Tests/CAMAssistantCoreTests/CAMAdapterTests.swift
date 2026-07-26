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
