import Foundation
import Testing
@testable import CAMAssistantCore

@Test("content IDs are stable SHA-256 addresses and writes are idempotent")
func contentIDsAreStableAndWritesAreIdempotent() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try ContentStore(rootDirectory: root)
    let payload = Data("hello".utf8)

    let first = try store.put(payload)
    let second = try store.put(payload)

    #expect(first.id.rawValue == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    #expect(first == second)
    #expect(try store.data(for: first.id) == payload)
    #expect(try store.objectCount() == 1)
}

@Test("content survives restart and leaves no partial writes")
func contentSurvivesRestartWithoutPartialWrites() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let payload = Data("restart-safe".utf8)
    let stored: StoredContent

    do {
        let store = try ContentStore(rootDirectory: root)
        stored = try store.put(payload)
    }

    let restarted = try ContentStore(rootDirectory: root)
    #expect(try restarted.data(for: stored.id) == payload)
    #expect(
        try restarted.temporaryWriteFiles().isEmpty,
        "Atomic writes must not leave temporary object files"
    )
}

@Test("content reads reject unsafe object identities")
func contentReadsRejectUnsafeObjectIdentities() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try ContentStore(rootDirectory: root)
    let unsafeID = ContentID(rawValue: "../../outside")

    #expect(throws: ContentStoreError.invalidContentID(unsafeID)) {
        try store.data(for: unsafeID)
    }
}

@Test("content reads detect immutable object tampering")
func contentReadsDetectImmutableObjectTampering() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try ContentStore(rootDirectory: root)
    let stored = try store.put(Data("trusted bytes".utf8))

    try Data("tampered bytes".utf8).write(to: stored.fileURL, options: [.atomic])

    #expect(throws: ContentStoreError.integrityMismatch(stored.id)) {
        try store.data(for: stored.id)
    }
}

@Test("content backup restores exact immutable bytes")
func contentBackupRestoresExactBytes() throws {
    let workspace = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let sourceRoot = workspace.appending(path: "source")
    let backupRoot = workspace.appending(path: "backup")
    let restoreRoot = workspace.appending(path: "restore")
    let source = try ContentStore(rootDirectory: sourceRoot)
    let payload = Data([0x00, 0x01, 0x7f, 0xff])
    let stored = try source.put(payload)

    try source.backup(to: backupRoot)
    let restored = try ContentStore(rootDirectory: restoreRoot)
    try restored.restore(from: backupRoot)

    #expect(try restored.data(for: stored.id) == payload)
}

@Test("SQLite migrations are transactional and durable across restart")
func sqliteMigrationsAreDurableAcrossRestart() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "cam.sqlite")

    do {
        let database = try SQLiteStore(databaseURL: databaseURL)
        #expect(try database.schemaVersion() == Migrations.currentVersion)
        try database.close()
    }

    let reopened = try SQLiteStore(databaseURL: databaseURL)
    #expect(try reopened.schemaVersion() == Migrations.currentVersion)
    try reopened.close()
}

@Test("application support can be isolated for packaged app verification")
func applicationSupportCanBeIsolatedForPackagedVerification() throws {
    let isolatedRoot = URL(filePath: "/tmp/cam-assistant-isolated-support")
    let environment = [
        LocalVaultPaths.applicationSupportRootEnvironmentKey:
            isolatedRoot.path
    ]

    #expect(
        try LocalVaultPaths.rootURL(environment: environment).path
            == "/tmp/cam-assistant-isolated-support/CAMAssistant"
    )
    #expect(
        try ModelProfileStorage.defaultStateURL(environment: environment).path
            == "/tmp/cam-assistant-isolated-support/CAMAssistant/models.json"
    )
}

@Test("application support isolation rejects ambiguous paths")
func applicationSupportIsolationRejectsAmbiguousPaths() {
    let key = LocalVaultPaths.applicationSupportRootEnvironmentKey

    #expect(throws: LocalVaultPathsError.invalidApplicationSupportRoot) {
        try LocalVaultPaths.rootURL(environment: [key: "relative/path"])
    }
    #expect(throws: LocalVaultPathsError.invalidApplicationSupportRoot) {
        try LocalVaultPaths.rootURL(environment: [key: ""])
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
