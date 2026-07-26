import Foundation
import Testing
@testable import CAMAssistantCore

@Test("audit persists typed status events without raw secrets")
func auditPersistsStatusWithoutRawSecrets() throws {
    let root = try makeAuditTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "audit.sqlite")
    let secret = "sk-or-v1-this-must-never-be-written"
    let store = try AuditStore(databaseURL: databaseURL)
    let event = AuditEvent(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        timestamp: Date(timeIntervalSince1970: 0),
        operation: .modelRequest,
        status: .denied,
        resourceID: secret,
        route: "local"
    )

    try store.append(event)
    let events = try store.events()
    let export = try store.exportJSON()
    let fixtureURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "docs/evidence/fixtures/task-03-audit-export.json")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let fixtureEvents = try decoder.decode(
        [AuditEvent].self,
        from: Data(contentsOf: fixtureURL)
    )
    try store.close()
    let databaseBytes = try Data(contentsOf: databaseURL)
    let databaseText = String(decoding: databaseBytes, as: Unicode.UTF8.self)
    let exportText = String(decoding: export, as: UTF8.self)

    #expect(events.count == 1)
    #expect(events[0].operation == .modelRequest)
    #expect(events[0].status == .denied)
    #expect(events[0].resourceID == "[REDACTED]")
    #expect(fixtureEvents == events)
    #expect(!databaseText.contains(secret))
    #expect(!exportText.contains(secret))
    #expect(exportText.contains("[REDACTED]"))
}

@Test("audit database backup reopens with the same receipt")
func auditBackupReopensWithSameReceipt() throws {
    let root = try makeAuditTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "audit.sqlite")
    let backupURL = root.appending(path: "audit-backup.sqlite")
    let event = AuditEvent(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        timestamp: Date(timeIntervalSince1970: 10),
        operation: .capture,
        status: .succeeded,
        resourceID: "2cf24dba5fb0a30e",
        route: nil
    )
    let store = try AuditStore(databaseURL: databaseURL)
    try store.append(event)

    try store.backup(to: backupURL)
    try store.close()

    let restored = try AuditStore(databaseURL: backupURL)
    let events = try restored.events()
    try restored.close()

    #expect(events == [event])
}

@Test("privacy audit receipts export status facts without restricted payload text")
func privacyAuditReceiptsRemainStatusOnly() throws {
    let root = try makeAuditTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "audit.sqlite")
    let restrictedPayload = "api_key=synthetic-credential-0000"
    let event = AuditEvent(
        timestamp: Date(timeIntervalSince1970: 10),
        operation: .actionProposal,
        status: .denied,
        resourceID: "research-request",
        route: "grok",
        privacyRisk: .restricted,
        privacyDecision: .blocked,
        payloadSHA256: "a" + String(repeating: "0", count: 63),
        outboundByteCount: 0
    )
    let store = try AuditStore(databaseURL: databaseURL)
    try store.append(event)
    let events = try store.events()
    let export = try store.exportJSON()
    try store.close()

    let databaseText = String(decoding: try Data(contentsOf: databaseURL), as: UTF8.self)
    let exportText = String(decoding: export, as: UTF8.self)

    #expect(events == [event])
    #expect(events[0].privacyRisk == .restricted)
    #expect(events[0].privacyDecision == .blocked)
    #expect(events[0].outboundByteCount == 0)
    #expect(!databaseText.contains(restrictedPayload))
    #expect(!exportText.contains(restrictedPayload))
    #expect(exportText.contains("\"outboundByteCount\" : 0"))
}

private func makeAuditTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-audit-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
