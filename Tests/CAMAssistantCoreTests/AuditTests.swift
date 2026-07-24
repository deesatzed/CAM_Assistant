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

private func makeAuditTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-audit-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
