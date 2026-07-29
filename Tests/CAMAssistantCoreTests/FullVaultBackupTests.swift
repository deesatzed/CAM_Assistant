import Foundation
import Testing
@testable import CAMAssistantCore

@Test("full-vault manifest is versioned, typed, and deterministically sorted")
func fullVaultManifestIsVersionedTypedAndSorted() throws {
    let digestA = String(repeating: "a", count: 64)
    let digestB = String(repeating: "b", count: 64)
    let createdAt = Date(timeIntervalSince1970: 100)

    let manifest = try FullVaultManifest(
        createdAt: createdAt,
        sourceSchemaVersion: 8,
        entries: [
            FullVaultManifestEntry(
                relativePath: "models.json",
                role: .modelProfiles,
                byteCount: 20,
                sha256: digestB,
                isRequired: false
            ),
            FullVaultManifestEntry(
                relativePath: "vault.sqlite",
                role: .database,
                byteCount: 10,
                sha256: digestA,
                isRequired: true
            ),
        ]
    )

    #expect(manifest.schemaVersion == 1)
    #expect(manifest.productIdentifier == BuildIdentity.bundleIdentifier)
    #expect(manifest.createdAt == createdAt)
    #expect(manifest.sourceSchemaVersion == 8)
    #expect(manifest.entryCount == 2)
    #expect(manifest.entries.map(\.relativePath) == [
        "models.json",
        "vault.sqlite",
    ])
}

@Test("local vault paths own every recognized durable state location")
func localVaultPathsOwnEveryRecognizedDurableStateLocation() {
    let root = URL(filePath: "/tmp/CAMAssistant", directoryHint: .isDirectory)

    #expect(
        LocalVaultStateFile.allCases.map(\.rawValue) == [
            "approvals.json",
            "contradictions.json",
            "hotkeys.json",
            "knowledge-claims.json",
            "models.json",
            "module-state.json",
            "repository-sources.json",
            "research-packets.json",
            "research-plans.json",
            "watched-sources.json",
        ]
    )
    #expect(
        LocalVaultPaths.stateURL(.researchPackets, vaultRoot: root).path
            == "/tmp/CAMAssistant/research-packets.json"
    )
    #expect(
        LocalVaultPaths.coordinationURL(vaultRoot: root).path
            == "/tmp/CAMAssistant/coordination"
    )
    #expect(
        LocalVaultPaths.retrievalIndexURL(vaultRoot: root).path
            == "/tmp/CAMAssistant/retrieval-index"
    )
}

@Test("full-vault manifest rejects unsafe paths, invalid hashes, and duplicates")
func fullVaultManifestRejectsUnsafeEntries() {
    let digest = String(repeating: "a", count: 64)
    let database = FullVaultManifestEntry(
        relativePath: "vault.sqlite",
        role: .database,
        byteCount: 10,
        sha256: digest,
        isRequired: true
    )

    #expect(throws: FullVaultBackupError.unsafeRelativePath("../vault.sqlite")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [
                FullVaultManifestEntry(
                    relativePath: "../vault.sqlite",
                    role: .database,
                    byteCount: 10,
                    sha256: digest,
                    isRequired: true
                ),
            ]
        )
    }
    #expect(throws: FullVaultBackupError.invalidDigest("short")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [
                FullVaultManifestEntry(
                    relativePath: "vault.sqlite",
                    role: .database,
                    byteCount: 10,
                    sha256: "short",
                    isRequired: true
                ),
            ]
        )
    }
    #expect(throws: FullVaultBackupError.duplicateEntry("vault.sqlite")) {
        _ = try FullVaultManifest(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceSchemaVersion: 8,
            entries: [database, database]
        )
    }
}

@Test("full-vault package captures database, immutable objects, and recognized state")
func fullVaultPackageCapturesRecognizedState() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let packageURL = workspace.appending(path: "Daily.camvault")
    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    let contentStore = try ContentStore(
        rootDirectory: vaultRoot.appending(path: "content")
    )
    let payload = Data("immutable backup fixture".utf8)
    let stored = try contentStore.put(payload)
    let modelState = Data(#"{"schemaVersion":1,"profiles":[]}"#.utf8)
    try modelState.write(
        to: vaultRoot.appending(path: "models.json"),
        options: .atomic
    )
    let retrievalRoot = vaultRoot.appending(path: "retrieval-index")
    try FileManager.default.createDirectory(
        at: retrievalRoot,
        withIntermediateDirectories: true
    )
    try Data("derived".utf8).write(
        to: retrievalRoot.appending(path: "active-generation.json")
    )
    let coordinationRoot = vaultRoot.appending(path: "coordination")
    try FileManager.default.createDirectory(
        at: coordinationRoot,
        withIntermediateDirectories: true
    )
    try Data().write(to: coordinationRoot.appending(path: "active.lock"))

    let receipt = try FullVaultBackupService().createPackage(
        from: vaultRoot,
        to: packageURL,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    try database.close()

    let manifest = try JSONDecoder().decode(
        FullVaultManifest.self,
        from: Data(contentsOf: packageURL.appending(path: "manifest.json"))
    )
    let objectPath =
        "content/objects/"
        + String(stored.id.rawValue.prefix(2))
        + "/"
        + String(stored.id.rawValue.dropFirst(2).prefix(2))
        + "/"
        + stored.id.rawValue

    #expect(receipt.entryCount == 3)
    #expect(receipt.totalByteCount > payload.count + modelState.count)
    #expect(receipt.manifestSHA256.count == 64)
    #expect(manifest.sourceSchemaVersion == Migrations.currentVersion)
    #expect(manifest.entries.map(\.relativePath) == [
        objectPath,
        "models.json",
        "vault.sqlite",
    ])
    #expect(
        try Data(
            contentsOf: packageURL
                .appending(path: "payload")
                .appending(path: objectPath)
        ) == payload
    )
    #expect(
        try Data(
            contentsOf: packageURL
                .appending(path: "payload")
                .appending(path: "models.json")
        ) == modelState
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: packageURL
                .appending(path: "payload/retrieval-index")
                .path
        )
    )
    #expect(
        !FileManager.default.fileExists(
            atPath: packageURL
                .appending(path: "payload/coordination/active.lock")
                .path
        )
    )
}

@Test("full-vault package refuses missing database and existing destination")
func fullVaultPackageRefusesMissingDatabaseAndExistingDestination() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let packageURL = workspace.appending(path: "Existing.camvault")
    try FileManager.default.createDirectory(
        at: vaultRoot,
        withIntermediateDirectories: true
    )

    #expect(throws: FullVaultBackupError.missingDatabase) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: packageURL
        )
    }

    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    try FileManager.default.createDirectory(
        at: packageURL,
        withIntermediateDirectories: true
    )
    #expect(throws: FullVaultBackupError.destinationExists) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: packageURL
        )
    }
    try database.close()
}

@Test("full-vault package rejects symlinked state and invalid immutable object names")
func fullVaultPackageRejectsUnsafeSourceFiles() throws {
    let workspace = try makeBackupTestDirectory()
    defer { try? FileManager.default.removeItem(at: workspace) }
    let vaultRoot = workspace.appending(path: "CAMAssistant")
    let database = try SQLiteStore(
        databaseURL: vaultRoot.appending(path: "vault.sqlite")
    )
    let external = workspace.appending(path: "external.json")
    try Data("{}".utf8).write(to: external)
    let modelURL = vaultRoot.appending(path: "models.json")
    try FileManager.default.createSymbolicLink(
        at: modelURL,
        withDestinationURL: external
    )

    #expect(throws: FullVaultBackupError.symlinkRejected("models.json")) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: workspace.appending(path: "Symlink.camvault")
        )
    }

    try FileManager.default.removeItem(at: modelURL)
    let invalidObject = vaultRoot
        .appending(path: "content/objects/aa/bb/not-a-content-id")
    try FileManager.default.createDirectory(
        at: invalidObject.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("bad".utf8).write(to: invalidObject)
    #expect(
        throws: FullVaultBackupError.invalidContentObject(
            "content/objects/aa/bb/not-a-content-id"
        )
    ) {
        try FullVaultBackupService().createPackage(
            from: vaultRoot,
            to: workspace.appending(path: "Invalid.camvault")
        )
    }
    try database.close()
}

private func makeBackupTestDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-backup-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
    )
    return url
}
