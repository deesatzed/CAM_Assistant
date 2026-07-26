import Foundation
import Testing
@testable import CAMAssistantCore

@Test("frozen privacy fixtures classify and sanitize deterministically")
func frozenPrivacyFixturesClassifyAndSanitizeDeterministically() throws {
    let manifest = try PrivacyFixtureManifest.decode(
        Data(contentsOf: privacyFixtureURL())
    )
    let classifier = DataClassifier()

    #expect(manifest.schemaVersion == 1)
    #expect(manifest.fixtures.count == 10)
    for fixture in manifest.fixtures {
        let result = classifier.classify(fixture.text)
        #expect(result.riskClass == fixture.riskClass, "fixture: \(fixture.id)")
        #expect(result.signals == fixture.signals, "fixture: \(fixture.id)")
        if fixture.riskClass == .restricted {
            #expect(result.sanitizedText == "[REDACTED:RESTRICTED]", "fixture: \(fixture.id)")
            #expect(!result.sanitizedText.contains(fixture.text), "fixture: \(fixture.id)")
        }
    }
}

@Test("aggregate privacy risk never falls below its most protected fragment")
func aggregatePrivacyRiskNeverFallsBelowProtectedFragments() {
    let result = DataClassifier().classify([
        "PUBLIC: Approved summary.",
        "api_key=synthetic-credential-0000",
    ])

    #expect(result.riskClass == .restricted)
    #expect(result.signals == [.credential])
    #expect(result.sanitizedText == "[REDACTED:RESTRICTED]")
}

@Test("outbound policy permits local work and makes only safe payloads proposals")
func outboundPolicyPermitsLocalAndSanitizedSafeProposal() {
    let policy = OutboundPolicy()
    let local = policy.evaluate(
        OutboundRequest(
            operation: "local-answer",
            requestedRole: .local,
            fragments: ["Explain the local index."],
            stateVersion: 3,
            explicitlyRequestedWeb: false
        )
    )
    let publicWeb = policy.evaluate(
        OutboundRequest(
            operation: "web-research",
            requestedRole: .grok,
            fragments: ["PUBLIC: Find public documentation."],
            stateVersion: 3,
            explicitlyRequestedWeb: true
        )
    )

    #expect(local == .localOnly(riskClass: .generic))
    guard case let .proposal(manifest) = publicWeb else {
        Issue.record("Expected a safe outbound proposal")
        return
    }
    #expect(manifest.riskClass == .public)
    #expect(manifest.requestedRole == .grok)
    #expect(manifest.outboundByteCount == Data(manifest.redactedPayload.utf8).count)
    #expect(manifest.redactedPayload == "PUBLIC: Find public documentation.")
}

@Test("restricted data creates zero-byte block even for explicit web intent")
func restrictedDataBlocksExplicitWebWithZeroOutboundBytes() {
    let decision = OutboundPolicy().evaluate(
        OutboundRequest(
            operation: "web-research",
            requestedRole: .grok,
            fragments: ["api_key=synthetic-credential-0000"],
            stateVersion: 9,
            explicitlyRequestedWeb: true
        )
    )

    #expect(
        decision == .blocked(
            OutboundBlock(
                riskClass: .restricted,
                reasons: [.credential],
                outboundByteCount: 0
            )
        )
    )
}

@Test("every frozen restricted fixture produces a zero-byte outbound block")
func everyRestrictedFixtureProducesZeroOutboundBytes() throws {
    let manifest = try PrivacyFixtureManifest.decode(Data(contentsOf: privacyFixtureURL()))
    for fixture in manifest.fixtures where fixture.riskClass == .restricted {
        let decision = OutboundPolicy().evaluate(
            OutboundRequest(
                operation: "web-research",
                requestedRole: .grok,
                fragments: [fixture.text],
                stateVersion: 1,
                explicitlyRequestedWeb: true
            )
        )
        guard case let .blocked(block) = decision else {
            Issue.record("Expected block for \(fixture.id)")
            continue
        }
        #expect(block.outboundByteCount == 0, "fixture: \(fixture.id)")
        #expect(block.reasons == fixture.signals, "fixture: \(fixture.id)")
    }
}

@Test("audit storage and export omit every frozen restricted fixture")
func auditStorageAndExportOmitEveryFrozenRestrictedFixture() throws {
    let root = try privacyTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "audit.sqlite")
    let store = try AuditStore(databaseURL: databaseURL)
    let manifest = try PrivacyFixtureManifest.decode(Data(contentsOf: privacyFixtureURL()))
    let restricted = manifest.fixtures.filter { $0.riskClass == .restricted }
    for fixture in restricted {
        try store.append(
            AuditEvent(
                operation: .actionProposal,
                status: .denied,
                resourceID: fixture.id,
                route: "local",
                privacyRisk: .restricted,
                privacyDecision: .blocked,
                payloadSHA256: String(repeating: "0", count: 64),
                outboundByteCount: 0
            )
        )
    }
    let export = try store.exportJSON()
    try store.close()

    let databaseText = String(decoding: try Data(contentsOf: databaseURL), as: UTF8.self)
    let exportText = String(decoding: export, as: UTF8.self)
    for fixture in restricted {
        #expect(!databaseText.contains(fixture.text), "fixture: \(fixture.id)")
        #expect(!exportText.contains(fixture.text), "fixture: \(fixture.id)")
    }
}

@Test("exact approval binds an action card to its payload and state version")
func exactApprovalBindsActionCardToPayloadAndStateVersion() throws {
    let root = try privacyTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let card = try privacyActionCard(
        stateVersion: 7,
        expiresAt: Date(timeIntervalSince1970: 100)
    )
    let store = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))

    #expect(try store.approvals().isEmpty, "A proposal has not executed or approved anything.")
    let approval = try store.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))
    let receipt = try store.consume(
        approvalID: approval.id,
        for: card,
        now: Date(timeIntervalSince1970: 20)
    )

    #expect(approval.payloadSHA256 == card.outboundManifest.payloadSHA256)
    #expect(approval.stateVersion == 7)
    #expect(receipt.approvalID == approval.id)
    #expect(try store.approvals().first?.status == .consumed)
}

@Test("exact approval rejects reused expired and stale cards")
func exactApprovalRejectsReusedExpiredAndStaleCards() throws {
    let root = try privacyTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))
    let card = try privacyActionCard(
        stateVersion: 7,
        expiresAt: Date(timeIntervalSince1970: 100)
    )
    let approval = try store.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))
    _ = try store.consume(approvalID: approval.id, for: card, now: Date(timeIntervalSince1970: 20))

    #expect(throws: ApprovalStoreError.alreadyConsumed(approval.id)) {
        _ = try store.consume(approvalID: approval.id, for: card, now: Date(timeIntervalSince1970: 21))
    }

    let expiring = try privacyActionCard(
        stateVersion: 7,
        expiresAt: Date(timeIntervalSince1970: 30)
    )
    let expiredApproval = try store.approve(expiring, source: "user", now: Date(timeIntervalSince1970: 10))
    #expect(throws: ApprovalStoreError.expired(expiredApproval.id)) {
        _ = try store.consume(approvalID: expiredApproval.id, for: expiring, now: Date(timeIntervalSince1970: 31))
    }

    let stale = try privacyActionCard(
        id: card.id,
        stateVersion: 8,
        expiresAt: Date(timeIntervalSince1970: 100)
    )
    let staleApproval = try store.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))
    #expect(throws: ApprovalStoreError.mismatchedBinding(staleApproval.id)) {
        _ = try store.consume(approvalID: staleApproval.id, for: stale, now: Date(timeIntervalSince1970: 20))
    }
}

private func privacyFixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/Privacy/v1/manifest.json")
}

private func privacyActionCard(
    id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
    stateVersion: Int,
    expiresAt: Date
) throws -> ActionCard {
    let decision = OutboundPolicy().evaluate(
        OutboundRequest(
            operation: "web-research",
            requestedRole: .grok,
            fragments: ["PUBLIC: Find public documentation."],
            stateVersion: stateVersion,
            explicitlyRequestedWeb: true
        )
    )
    guard case let .proposal(manifest) = decision else {
        throw PrivacyTestError.expectedProposal
    }
    return try ActionCard(
        id: id,
        goal: "Find public documentation",
        moduleID: "cam.research",
        target: "public documentation",
        accessedResources: ["public web search"],
        excludedResources: ["local vault"],
        riskReason: "Public request contains no protected local data.",
        outboundManifest: manifest,
        expiresAt: expiresAt,
        rollbackDescription: "No external action has occurred."
    )
}

private enum PrivacyTestError: Error {
    case expectedProposal
}

private func privacyTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-privacy-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
