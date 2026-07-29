import Foundation
import Testing
@testable import CAMAssistantApp
@testable import CAMAssistantCore

@MainActor
@Test("app model presents acquires keeps and discards one exact research packet")
func appModelRunsExplicitResearchAcquisitionLifecycle() async throws {
    let root = URL(filePath: "/tmp/ResearchVault")
    let recorder = ResearchAppOperationRecorder()
    let proposal = try makeResearchAppProposal(stateVersion: 0)
    let result = try makeResearchAppResult(proposal: proposal)
    let operations = ResearchAcquisitionOperations(
        prepare: { suppliedRoot, _, query, target in
            #expect(suppliedRoot == root)
            #expect(query == "PUBLIC: What does HTTP define?")
            #expect(
                target.absoluteString
                    == "https://www.rfc-editor.org/rfc/rfc9110.txt"
            )
            return proposal
        },
        execute: { suppliedRoot, suppliedProposal in
            #expect(suppliedRoot == root)
            #expect(suppliedProposal == proposal)
            await recorder.recordExecute()
            return result
        },
        resume: { _, _ in
            try makeResearchAppProposal(stateVersion: 1)
        },
        cancel: { _, id in
            await recorder.recordCancel(id)
        },
        recoverAndLoadJobs: { _ in [] },
        loadJobs: { _ in [result.job] },
        keep: { _, packet in
            await recorder.recordKeep()
            return [packet.retained()]
        },
        loadPackets: { _ in [] }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        researchAcquisitionOperations: operations,
        vaultRootProvider: { root }
    )
    model.researchQuery = "PUBLIC: What does HTTP define?"
    model.researchSourceURL =
        "https://www.rfc-editor.org/rfc/rfc9110.txt"

    model.prepareResearchAcquisition()
    await waitForResearchPreparation(model)
    #expect(model.researchAcquisitionProposal == proposal)
    #expect(model.pendingActionCard == proposal.actionCard)
    #expect(model.researchAcquisitionResult == nil)

    model.approveAndAcquireResearchSource()
    await waitForResearchAcquisition(model)
    #expect(await recorder.executeCount == 1)
    #expect(model.researchAcquisitionResult == result)
    #expect(model.researchAcquisitionPacket?.retention == .ephemeral)
    #expect(
        model.researchAcquisitionStatus
            == "Ephemeral public-document packet ready for review. Nothing was retained automatically."
    )
    #expect(model.pendingActionCard == nil)
    #expect(model.researchAcquisitionError == nil)

    model.keepResearchAcquisitionPacket()
    await waitForResearchRetention(model)
    #expect(await recorder.keepCount == 1)
    #expect(model.retainedResearchPackets.count == 1)
    #expect(
        model.researchAcquisitionStatus
            == "Research packet kept locally. The displayed source receipt and typed results will reopen after restart."
    )
    #expect(
        model.retainedResearchPackets[0].retention
            == .explicitlyKept
    )
    #expect(model.researchAcquisitionPacket?.retention == .ephemeral)

    model.discardResearchAcquisitionPacket()
    #expect(model.researchAcquisitionResult == nil)
    #expect(model.researchAcquisitionPacket == nil)
    #expect(
        model.researchAcquisitionStatus
            == "Ephemeral research packet discarded. Kept packets and vault source bytes were not changed."
    )
}

@MainActor
@Test("app model blocks protected research and safely cancels acquisition")
func appModelBlocksAndCancelsResearchSafely() async throws {
    let recorder = ResearchAppOperationRecorder()
    let proposal = try makeResearchAppProposal(stateVersion: 0)
    let operations = ResearchAcquisitionOperations(
        prepare: { _, _, query, _ in
            if query.contains("api_key") {
                throw ResearchAcquisitionError.policyBlocked(.restricted)
            }
            return proposal
        },
        execute: { _, _ in
            try await Task.sleep(for: .seconds(30))
            throw CancellationError()
        },
        resume: { _, _ in
            try makeResearchAppProposal(stateVersion: 1)
        },
        cancel: { _, id in
            await recorder.recordCancel(id)
        },
        recoverAndLoadJobs: { _ in [] },
        loadJobs: { _ in [] },
        keep: { _, _ in [] },
        loadPackets: { _ in [] }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        researchAcquisitionOperations: operations,
        vaultRootProvider: {
            URL(filePath: "/tmp/ResearchVault")
        }
    )
    model.researchSourceURL =
        "https://www.rfc-editor.org/rfc/rfc9110.txt"
    model.researchQuery = "api_key=synthetic-secret"

    model.prepareResearchAcquisition()
    await waitForResearchPreparation(model)
    #expect(model.researchAcquisitionProposal == nil)
    #expect(model.pendingActionCard == nil)
    #expect(
        model.researchAcquisitionError
            == "The research question or target contains protected data. No network request or approval was created."
    )

    model.researchQuery = "PUBLIC: Safe question"
    model.prepareResearchAcquisition()
    await waitForResearchPreparation(model)
    model.approveAndAcquireResearchSource()
    #expect(model.isResearchAcquiring)
    model.cancelResearchAcquisition()
    await waitForResearchAcquisition(model)

    #expect(await recorder.cancelledIDs == [proposal.id])
    #expect(model.researchAcquisitionResult == nil)
    #expect(model.researchAcquisitionError == nil)
    #expect(
        model.researchAcquisitionStatus
            == "Public document acquisition was cancelled. No packet was retained; safe resume requires a new exact approval."
    )
}

@MainActor
@Test("native cancellation atomically wins over a live coordinator completion")
func appModelCancellationWinsLiveCoordinatorRace() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString,
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let contentStore = try ContentStore(
        rootDirectory: root.appending(path: "content")
    )
    let queue = try IngestQueue(
        databaseURL: databaseURL,
        contentStore: contentStore,
        extractors: .localDefaults
    )
    let jobStore = try ResearchAcquisitionJobStore(databaseURL: databaseURL)
    let jobStoreBox = ResearchSendableJobStoreBox(store: jobStore)
    let approvalStore = try ApprovalStore(
        stateURL: root.appending(path: "approvals.json")
    )
    let transport = ResearchAppBlockingTransport()
    let coordinator = ResearchAcquisitionCoordinator(
        jobStore: jobStore,
        approvalStore: approvalStore,
        queue: queue,
        transport: transport
    )
    let operations = ResearchAcquisitionOperations(
        prepare: { _, runID, query, target in
            try coordinator.proposal(
                runID: runID,
                query: query,
                target: target,
                stateVersion: 0,
                expiresAt: .distantFuture
            )
        },
        execute: { _, proposal in
            try await coordinator.execute(
                proposal,
                approvalSource: "native-test"
            )
        },
        resume: { _, id in
            try coordinator.resumeProposal(
                jobID: id,
                expiresAt: .distantFuture
            )
        },
        cancel: { _, id in
            _ = try jobStoreBox.store.cancel(id)
        },
        recoverAndLoadJobs: { _ in
            _ = try jobStoreBox.store.recoverInterrupted()
            return try jobStoreBox.store.all()
        },
        loadJobs: { _ in try jobStoreBox.store.all() },
        keep: { _, packet in [packet.retained()] },
        loadPackets: { _ in [] }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        researchAcquisitionOperations: operations,
        vaultRootProvider: { root }
    )
    model.researchQuery = "PUBLIC: What does HTTP define?"
    model.researchSourceURL =
        "https://www.rfc-editor.org/rfc/rfc9110.txt"

    model.prepareResearchAcquisition()
    await waitForResearchPreparation(model)
    let proposal = try #require(model.researchAcquisitionProposal)
    model.approveAndAcquireResearchSource()
    for _ in 0..<1_000 {
        if await transport.callCount > 0 {
            break
        }
        await Task.yield()
    }
    #expect(await transport.callCount == 1)

    model.cancelResearchAcquisition()
    await waitForResearchAcquisition(model)

    #expect(model.researchAcquisitionResult == nil)
    #expect(model.researchAcquisitionError == nil)
    #expect(
        try jobStore.record(id: proposal.id)?.status == .cancelled
    )
}

@MainActor
@Test("app model recovers jobs and prepares resume with a new state version")
func appModelRecoversResearchJobsAndPreparesResume() async throws {
    let cancelled = try makeResearchAppJob(
        status: .cancelled,
        stateVersion: 0
    )
    let resumedProposal = try makeResearchAppProposal(
        id: cancelled.id,
        stateVersion: 1
    )
    let operations = ResearchAcquisitionOperations(
        prepare: { _, _, _, _ in
            try makeResearchAppProposal(stateVersion: 0)
        },
        execute: { _, proposal in
            try makeResearchAppResult(proposal: proposal)
        },
        resume: { _, id in
            #expect(id == cancelled.id)
            return resumedProposal
        },
        cancel: { _, _ in },
        recoverAndLoadJobs: { _ in [cancelled] },
        loadJobs: { _ in [cancelled] },
        keep: { _, _ in [] },
        loadPackets: { _ in [] }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        researchAcquisitionOperations: operations,
        vaultRootProvider: {
            URL(filePath: "/tmp/ResearchVault")
        }
    )

    model.reloadResearchAcquisitionState(recoverInterrupted: true)
    await waitForResearchStateReload(model)
    #expect(model.researchAcquisitionJobs == [cancelled])

    model.prepareResearchAcquisitionResume(cancelled.id)
    await waitForResearchPreparation(model)
    #expect(
        model.researchAcquisitionProposal?.request.stateVersion == 1
    )
    #expect(model.pendingActionCard == resumedProposal.actionCard)
    #expect(
        model.researchAcquisitionStatus
            == "Resume proposal ready. Review and approve the new exact action card."
    )
}

@MainActor
@Test("app model reopens a completed receipt as ephemeral review after restart")
func appModelReopensCompletedReceiptForReview() async throws {
    let id = UUID()
    let receipt = try makeResearchAppReceipt(acquisitionID: id)
    let completed = try makeResearchAppJob(
        id: id,
        status: .completed,
        stateVersion: 0,
        receipt: receipt
    )
    let recorder = ResearchAppOperationRecorder()
    let operations = ResearchAcquisitionOperations(
        prepare: { _, _, _, _ in
            try makeResearchAppProposal(stateVersion: 0)
        },
        execute: { _, proposal in
            try makeResearchAppResult(proposal: proposal)
        },
        resume: { _, _ in
            try makeResearchAppProposal(stateVersion: 1)
        },
        cancel: { _, _ in },
        recoverAndLoadJobs: { _ in [completed] },
        loadJobs: { _ in [completed] },
        keep: { _, packet in
            await recorder.recordKeep()
            return [packet.retained()]
        },
        loadPackets: { _ in [] }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        researchAcquisitionOperations: operations,
        vaultRootProvider: {
            URL(filePath: "/tmp/ResearchVault")
        }
    )

    model.reloadResearchAcquisitionState(recoverInterrupted: true)
    await waitForResearchStateReload(model)
    model.reviewCompletedResearchAcquisition(id)

    #expect(model.researchAcquisitionResult?.job == completed)
    #expect(model.researchAcquisitionPacket?.retention == .ephemeral)
    #expect(
        model.researchAcquisitionStatus
            == "Completed receipt reopened as an ephemeral packet for review. Nothing was retained automatically."
    )

    model.keepResearchAcquisitionPacket()
    await waitForResearchRetention(model)
    #expect(await recorder.keepCount == 1)
    #expect(model.retainedResearchPackets.first?.retention == .explicitlyKept)
}

private actor ResearchAppOperationRecorder {
    private(set) var executeCount = 0
    private(set) var keepCount = 0
    private(set) var cancelledIDs: [UUID] = []

    func recordExecute() {
        executeCount += 1
    }

    func recordKeep() {
        keepCount += 1
    }

    func recordCancel(_ id: UUID) {
        cancelledIDs.append(id)
    }
}

private actor ResearchAppBlockingTransport: ResearchAcquisitionTransport {
    private(set) var callCount = 0

    func fetch(
        _ request: ResearchTransportRequest
    ) async throws -> ResearchTransportResponse {
        callCount += 1
        try await Task.sleep(for: .seconds(30))
        throw CancellationError()
    }
}

private final class ResearchSendableJobStoreBox: @unchecked Sendable {
    let store: ResearchAcquisitionJobStore

    init(store: ResearchAcquisitionJobStore) {
        self.store = store
    }
}

private func makeResearchAppProposal(
    id: UUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000064"
    )!,
    stateVersion: Int
) throws -> ResearchAcquisitionProposal {
    let request = try ResearchAcquisitionRequest(
        runID: "research-app",
        query: "PUBLIC: What does HTTP define?",
        target: #require(
            URL(string: "https://www.rfc-editor.org/rfc/rfc9110.txt")
        ),
        stateVersion: stateVersion,
        maxBytes: 1_048_576
    )
    let manifest = OutboundManifest(
        operation: "research-public-document",
        requestedRole: nil,
        stateVersion: stateVersion,
        riskClass: .generic,
        redactedPayload: request.canonicalPayload,
        payloadSHA256: request.payloadSHA256,
        outboundByteCount: request.canonicalPayload.utf8.count
    )
    let card = try ActionCard(
        id: UUID(),
        goal: request.query,
        moduleID: "cam.research",
        target: request.target.absoluteString,
        accessedResources: ["Exact public HTTPS document"],
        excludedResources: ["Local vault content"],
        riskReason: "One zero-cost bounded GET.",
        outboundManifest: manifest,
        expiresAt: .distantFuture,
        rollbackDescription: "Cancel the current attempt."
    )
    return ResearchAcquisitionProposal(
        id: id,
        request: request,
        actionCard: card
    )
}

private func makeResearchAppResult(
    proposal: ResearchAcquisitionProposal
) throws -> ResearchAcquisitionResult {
    let receipt = try makeResearchAppReceipt(
        acquisitionID: proposal.id
    )
    let packet = ResearchPacket(
        runID: proposal.request.runID,
        sourceReceipts: [receipt],
        verifiedFacts: [],
        inferences: [],
        unansweredQuestions: [
            try ResearchUnansweredQuestion(
                id: "question",
                question: proposal.request.query,
                reason: "Review required."
            ),
        ],
        limitations: [
            try ResearchLimitation(
                id: "limitation",
                statement: "No model-generated finding was created."
            ),
        ],
        retention: .ephemeral
    )
    let job = try makeResearchAppJob(
        id: proposal.id,
        status: .completed,
        stateVersion: proposal.request.stateVersion,
        receipt: receipt
    )
    return ResearchAcquisitionResult(
        job: job,
        receipt: receipt,
        packet: packet
    )
}

private func makeResearchAppJob(
    id: UUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000074"
    )!,
    status: ResearchAcquisitionJobStatus,
    stateVersion: Int,
    receipt: ResearchSourceReceipt? = nil
) throws -> ResearchAcquisitionJobRecord {
    ResearchAcquisitionJobRecord(
        id: id,
        request: try makeResearchAppProposal(
            id: id,
            stateVersion: stateVersion
        ).request,
        status: status,
        attempts: status == .pending ? 0 : 1,
        maxAttempts: 3,
        cardID: status == .pending ? nil : UUID(),
        approvalID: status == .pending ? nil : UUID(),
        approvalConsumedAt: status == .pending ? nil : .distantPast,
        startedAt: status == .pending ? nil : .distantPast,
        completedAt: status == .completed
            ? receipt?.completedAt
            : nil,
        receipt: receipt,
        errorCode: status == .failed ? "interrupted" : nil,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
}

private func makeResearchAppReceipt(
    acquisitionID: UUID
) throws -> ResearchSourceReceipt {
    let sourceID = ContentID(rawValue: String(repeating: "a", count: 64))
    return try ResearchSourceReceipt(
        acquisitionID: acquisitionID,
        sourceID: sourceID,
        requestedURL: "https://www.rfc-editor.org/rfc/rfc9110.txt",
        finalURL: "https://www.rfc-editor.org/rfc/rfc9110.txt",
        contentType: "text/plain",
        byteCount: 4096,
        sha256: sourceID.rawValue,
        route: "WR/direct-public-document",
        toolID: "pinned-curl-public-document-v1",
        startedAt: Date(timeIntervalSince1970: 80),
        completedAt: Date(timeIntervalSince1970: 81),
        maximumCostUSD: 0,
        actualCostUSD: 0,
        wasDuplicateSource: false,
        quality: ResearchSourceQuality(
            publisherHost: "www.rfc-editor.org",
            kind: .unknown,
            reviewed: false,
            retrievedAt: Date(timeIntervalSince1970: 81),
            sourceModifiedAt: nil
        ),
        safetySignals: []
    )
}

@MainActor
private func waitForResearchPreparation(_ model: AppModel) async {
    for _ in 0..<200 where model.isPreparingResearchAcquisition {
        await Task.yield()
    }
}

@MainActor
private func waitForResearchAcquisition(_ model: AppModel) async {
    for _ in 0..<400 where model.isResearchAcquiring {
        await Task.yield()
    }
}

@MainActor
private func waitForResearchRetention(_ model: AppModel) async {
    for _ in 0..<200 where model.isResearchPacketRetentionRunning {
        await Task.yield()
    }
}

@MainActor
private func waitForResearchStateReload(_ model: AppModel) async {
    for _ in 0..<200 where model.isResearchStateReloading {
        await Task.yield()
    }
}
