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

