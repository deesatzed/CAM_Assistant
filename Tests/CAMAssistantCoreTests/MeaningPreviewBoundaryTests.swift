import Foundation
import MeaningCore
import Testing
@testable import CAMAssistantCore

@Test("operational Meaning Preview actions never imply helpfulness")
func meaningPreviewOperationalActionsDoNotImplyHelpfulness() async throws {
    for action in [UtilityAction.now, .later, .release] {
        let store = BoundaryMeaningPreviewStore()
        let coordinator = try MeaningPreviewCoordinator(store: store)
        let presentation = try await coordinator.requestPractical(
            access: .authorized,
            selection: { boundarySelection(id: action.rawValue, text: "Review the outline") },
            now: .fixed
        )
        let memoryID = try #require(presentation.glance.item?.id)

        _ = try await coordinator.mutate(
            .action(action, memoryID: memoryID, at: .fixed),
            expectedVersion: presentation.version
        )

        #expect(
            store.current.coreState.familiarity.stage(for: "work") == .usefulStranger,
            "action: \(action.rawValue)"
        )
    }
}

@Test("helpfulness changes only after explicit Meaning Preview feedback")
func meaningPreviewHelpfulnessRequiresExplicitFeedback() async throws {
    let store = BoundaryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "feedback", text: "Review the outline") },
        now: .fixed
    )
    let memoryID = try #require(presentation.glance.item?.id)

    _ = try await coordinator.mutate(
        .utilityOutcome(.helpful, memoryID: memoryID, domain: "work"),
        expectedVersion: presentation.version
    )
    let secondPresentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "feedback", text: "Review the outline") },
        now: .fixed
    )
    _ = try await coordinator.mutate(
        .utilityOutcome(.helpful, memoryID: memoryID, domain: "work"),
        expectedVersion: secondPresentation.version
    )

    #expect(store.current.coreState.familiarity.stage(for: "work") == .familiarAssistant)
}

@Test("explicit not-helpful feedback does not advance familiarity")
func meaningPreviewNotHelpfulDoesNotAdvanceFamiliarity() async throws {
    let store = BoundaryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "not-helpful", text: "Review the outline") },
        now: .fixed
    )
    let memoryID = try #require(presentation.glance.item?.id)

    _ = try await coordinator.mutate(
        .utilityOutcome(.notHelpful, memoryID: memoryID, domain: "work"),
        expectedVersion: presentation.version
    )

    #expect(store.current.coreState.familiarity.stage(for: "work") == .usefulStranger)
}

@Test("feedback refuses silence unrelated domains and superseded surfaced results")
func meaningPreviewFeedbackBindsToOneSurfacedDecision() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: BoundaryMeaningPreviewStore())
    let first = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "first", text: "First suggestion") },
        now: .fixed
    )
    let firstID = try #require(first.glance.item?.id)

    await #expect(throws: MeaningPreviewCoordinatorError.feedbackDomainMismatch) {
        _ = try await coordinator.mutate(
            .utilityOutcome(.helpful, memoryID: firstID, domain: "personal"),
            expectedVersion: first.version
        )
    }

    let second = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "second", text: "Second suggestion") },
        now: .fixed
    )
    await #expect(throws: MeaningPreviewCoordinatorError.feedbackDecisionMismatch) {
        _ = try await coordinator.mutate(
            .utilityOutcome(.helpful, memoryID: firstID, domain: "work"),
            expectedVersion: second.version
        )
    }

    let silent = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundaryEmptySelection() },
        now: .fixed
    )
    await #expect(throws: MeaningPreviewCoordinatorError.feedbackUnavailable) {
        _ = try await coordinator.mutate(
            .utilityOutcome(.helpful, memoryID: firstID, domain: "work"),
            expectedVersion: silent.version
        )
    }
}

@Test("correction and release remain retired after isolated-state restart")
func meaningPreviewCorrectionAndRetirementPropagateAcrossRestart() async throws {
    let store = BoundaryMeaningPreviewStore()
    var coordinator = try MeaningPreviewCoordinator(store: store)
    var presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "wrong", text: "Wrong suggestion") },
        now: .fixed
    )
    let originalID = try #require(presentation.glance.item?.id)
    _ = try await coordinator.mutate(
        .correct(memoryID: originalID, replacement: "Corrected suggestion"),
        expectedVersion: presentation.version
    )
    presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "wrong", text: "Wrong suggestion") },
        now: .fixed
    )
    let correctedID = try #require(presentation.glance.item?.id)
    #expect(correctedID != originalID)
    #expect(presentation.glance.item?.text == "Corrected suggestion")

    _ = try await coordinator.mutate(
        .action(.release, memoryID: correctedID, at: .fixed),
        expectedVersion: presentation.version
    )
    coordinator = try MeaningPreviewCoordinator(store: store)
    let restarted = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "wrong", text: "Wrong suggestion") },
        now: .fixed
    )
    #expect(restarted.glance.item == nil)
    #expect(store.current.coreState.memory.contains { $0.id == originalID && $0.status == .superseded })
    #expect(store.current.coreState.memory.contains { $0.id == correctedID && $0.status == .released })
}

@Test("Meaning Preview audit sink persists only bounded status facts")
func meaningPreviewAuditSinkIsStatusOnly() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-meaning-preview-audit")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "audit.sqlite")
    let store = try AuditStore(databaseURL: databaseURL)
    let sink = MeaningPreviewAuditSink(store: store)
    let rawSecret = "api_key=synthetic-credential-0000"

    #expect(sink.record(
        MeaningPreviewAuditReceipt(
            timestamp: .fixed,
            decisionID: rawSecret,
            version: 7,
            status: .denied,
            reason: .restrictedContext,
            exclusions: [.restricted, .secretLike],
            riskClass: .restricted,
            privacyDecision: .blocked,
            outboundByteCount: 0
        )
    ))
    let events = try store.events()
    let export = try store.exportJSON()
    try store.close()

    let databaseText = String(decoding: try Data(contentsOf: databaseURL), as: UTF8.self)
    let exportText = String(decoding: export, as: UTF8.self)
    #expect(events.count == 1)
    #expect(events[0].resourceID == "meaning-preview:invalid:v7")
    #expect(events[0].route == "restricted-context|restricted,secret-like")
    #expect(events[0].outboundByteCount == 0)
    #expect(!databaseText.contains(rawSecret))
    #expect(!exportText.contains(rawSecret))
    #expect(!exportText.contains("sourceText"))
    #expect(!exportText.contains("modelOutput"))
}

@Test("coordinator emits audit receipts and exposes proposals without execution")
func meaningPreviewCoordinatorOwnsInjectedAuditAndProposalBoundaries() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-meaning-preview-coordinator-audit")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let auditStore = try AuditStore(databaseURL: root.appending(path: "audit.sqlite"))
    let coordinator = try MeaningPreviewCoordinator(
        store: BoundaryMeaningPreviewStore(),
        auditSink: MeaningPreviewAuditSink(store: auditStore),
        proposalAdapter: MeaningActionProposalAdapter()
    )
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "audited", text: "Review the outline") },
        now: .fixed
    )
    let memoryID = try #require(presentation.glance.item?.id)
    _ = try await coordinator.mutate(
        .utilityOutcome(.notHelpful, memoryID: memoryID, domain: "work"),
        expectedVersion: presentation.version
    )
    let proposal = try await coordinator.proposeAction(
        id: "restricted-proposal",
        kind: .external,
        description: "api_key=synthetic-credential-0000",
        requestedRole: .grok,
        at: .fixed
    )
    let events = try auditStore.events()
    try auditStore.close()

    #expect(proposal.authority == .proposalOnly)
    #expect(proposal.privacyDecision == .blocked)
    #expect(proposal.outboundByteCount == 0)
    #expect(events.contains { $0.route?.hasPrefix("surfaced") == true })
    #expect(events.contains { $0.route?.hasPrefix("not-helpful") == true })
    #expect(events.contains { $0.route?.hasPrefix("proposal-blocked") == true })
}

@Test("feedback is one-shot and restart requires a fresh request")
func meaningPreviewFeedbackBindingIsOneShotAndEphemeral() async throws {
    let store = BoundaryMeaningPreviewStore()
    var coordinator = try MeaningPreviewCoordinator(store: store)
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "one-shot", text: "Review the outline") },
        now: .fixed
    )
    let memoryID = try #require(presentation.glance.item?.id)
    _ = try await coordinator.mutate(
        .utilityOutcome(.helpful, memoryID: memoryID, domain: "work"),
        expectedVersion: presentation.version
    )
    await #expect(throws: MeaningPreviewCoordinatorError.feedbackUnavailable) {
        _ = try await coordinator.mutate(
            .utilityOutcome(.helpful, memoryID: memoryID, domain: "work"),
            expectedVersion: store.current.revision
        )
    }

    coordinator = try MeaningPreviewCoordinator(store: store)
    await #expect(throws: MeaningPreviewCoordinatorError.feedbackUnavailable) {
        _ = try await coordinator.mutate(
            .utilityOutcome(.helpful, memoryID: memoryID, domain: "work"),
            expectedVersion: store.current.revision
        )
    }
}

@Test("audit delivery failure never turns a committed operation into failure")
func meaningPreviewAuditFailureIsNonthrowingAndVisibleAsHealth() async throws {
    let coordinator = try MeaningPreviewCoordinator(
        store: BoundaryMeaningPreviewStore(),
        auditSink: FailingMeaningPreviewAuditRecorder()
    )
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "audit-failure", text: "Review the outline") },
        now: .fixed
    )

    #expect(presentation.glance.item != nil)
    #expect(await coordinator.auditDeliveryIsHealthy() == false)
}

@Test("shared audit sink serializes concurrent coordinator delivery")
func meaningPreviewAuditSinkSerializesSharedDelivery() async throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-meaning-preview-shared-audit")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let auditStore = try AuditStore(databaseURL: root.appending(path: "audit.sqlite"))
    let sink = MeaningPreviewAuditSink(store: auditStore)
    let first = try MeaningPreviewCoordinator(store: BoundaryMeaningPreviewStore(), auditSink: sink)
    let second = try MeaningPreviewCoordinator(store: BoundaryMeaningPreviewStore(), auditSink: sink)

    async let firstResult = first.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "first-audit", text: "Review first work") },
        now: .fixed
    )
    async let secondResult = second.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "second-audit", text: "Review second work") },
        now: .fixed
    )
    _ = try await (firstResult, secondResult)

    #expect(try auditStore.events().count == 2)
    try auditStore.close()
}

@Test("secret-like corrections fail before isolated persistence")
func meaningPreviewCorrectionRejectsSensitiveText() async throws {
    let store = BoundaryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let presentation = try await coordinator.requestPractical(
        access: .authorized,
        selection: { boundarySelection(id: "correction-secret", text: "Review the outline") },
        now: .fixed
    )
    let memoryID = try #require(presentation.glance.item?.id)
    let manifestURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Privacy/v1/manifest.json")
    let manifest = try PrivacyFixtureManifest.decode(Data(contentsOf: manifestURL))
    let restricted = manifest.fixtures.filter { $0.riskClass == .restricted }
    #expect(restricted.contains { $0.text.lowercased().contains("sk-") })

    for fixture in restricted {
        await #expect(throws: MeaningPreviewCoordinatorError.sensitiveCorrection) {
            _ = try await coordinator.mutate(
                .correct(memoryID: memoryID, replacement: fixture.text),
                expectedVersion: presentation.version
            )
        }
        #expect(!store.current.coreState.memory.contains { $0.text.contains(fixture.text) })
        #expect(store.current.revision == presentation.version)
    }
}

@Test("Meaning action possibilities are non-executing proposals and restrict outbound bytes")
func meaningActionPossibilitiesRemainProposalOnly() {
    let adapter = MeaningActionProposalAdapter()
    let restricted = adapter.propose(
        id: "restricted-web",
        kind: .external,
        description: "api_key=synthetic-credential-0000",
        requestedRole: .grok,
        stateVersion: 4
    )

    #expect(restricted.authority == .proposalOnly)
    #expect(restricted.outboundByteCount == 0)
    #expect(restricted.privacyDecision == .blocked)

    let publicProposal = adapter.propose(
        id: "public-web",
        kind: .external,
        description: "PUBLIC: Review published documentation.",
        requestedRole: .grok,
        stateVersion: 4
    )
    #expect(publicProposal.authority == .proposalOnly)
    #expect(publicProposal.privacyDecision == .proposal)
    #expect(publicProposal.outboundManifest?.redactedPayload == "PUBLIC: Review published documentation.")

    let mutating = adapter.propose(
        id: "local-mutation",
        kind: .mutating,
        description: "Update a local preview preference",
        stateVersion: 4
    )
    #expect(mutating.authority == .proposalOnly)
    #expect(mutating.privacyDecision == .localOnly)
    #expect(mutating.outboundByteCount == 0)
}

private func boundarySelection(id: String, text: String) -> MeaningContextSelection {
    MeaningContextSelection(
        purpose: "practical utility",
        domain: "work",
        capacity: .adequate,
        selectedItems: [
            MeaningContextItem(
                id: id,
                sourceID: "synthetic-source",
                derivedText: text,
                observedAt: .fixed,
                uncertainty: .supported
            ),
        ]
    )
}

private func boundaryEmptySelection() -> MeaningContextSelection {
    MeaningContextSelection(
        purpose: "practical utility",
        domain: "work",
        capacity: .adequate,
        selectedItems: []
    )
}

private final class BoundaryMeaningPreviewStore: MeaningPreviewStateStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = MeaningPreviewSnapshot()

    func load() throws -> MeaningPreviewSnapshot { lock.withLock { snapshot } }
    func save(_ snapshot: MeaningPreviewSnapshot) throws {
        lock.withLock { self.snapshot = snapshot }
    }

    var current: MeaningPreviewSnapshot { lock.withLock { snapshot } }
}

private struct FailingMeaningPreviewAuditRecorder: MeaningPreviewAuditRecording {
    func record(_ receipt: MeaningPreviewAuditReceipt) -> Bool { false }
}

private extension MeaningPreviewAccess {
    static let authorized = MeaningPreviewAccess(enabled: true, localDataGranted: true)
}
