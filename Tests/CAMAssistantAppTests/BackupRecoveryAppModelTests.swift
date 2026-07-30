import Foundation
import Testing
@testable import CAMAssistantApp
@testable import CAMAssistantCore

@MainActor
@Test("app model runs backup validation and fresh-root restore off the main actor")
func appModelRunsVaultRecoveryOperations() async throws {
    let sourceRoot = URL(filePath: "/tmp/SourceVault")
    let packageURL = URL(filePath: "/tmp/Backup.camvault")
    let destinationRoot = URL(filePath: "/tmp/RestoredVault")
    let digest = String(repeating: "a", count: 64)
    let operations = VaultRecoveryOperations(
        create: { source, package in
            #expect(source == sourceRoot)
            #expect(package == packageURL)
            return FullVaultBackupReceipt(
                packageURL: package,
                createdAt: Date(timeIntervalSince1970: 10),
                entryCount: 7,
                totalByteCount: 70,
                manifestSHA256: digest
            )
        },
        validate: { package in
            #expect(package == packageURL)
            return FullVaultValidationReceipt(
                packageURL: package,
                entryCount: 7,
                totalByteCount: 70,
                manifestSHA256: digest,
                sourceSchemaVersion: 8
            )
        },
        restore: { package, destination in
            #expect(package == packageURL)
            #expect(destination == destinationRoot)
            return FullVaultRestoreReceipt(
                destinationURL: destination,
                restoredAt: Date(timeIntervalSince1970: 20),
                entryCount: 7,
                totalByteCount: 70,
                manifestSHA256: digest,
                watchedSourcesPaused: 2,
                authorityRecordsQuarantined: 1
            )
        }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        vaultRecoveryOperations: operations,
        vaultRootProvider: { sourceRoot }
    )

    model.createVaultBackup(to: packageURL)
    await waitForVaultRecovery(model)
    #expect(model.vaultRecoveryStatus?.contains("Backup created") == true)
    #expect(model.vaultRecoveryStatus?.contains("7 entries") == true)
    #expect(model.vaultRecoveryError == nil)

    model.validateVaultBackup(at: packageURL)
    await waitForVaultRecovery(model)
    #expect(model.vaultRecoveryStatus?.contains("Backup validated") == true)
    #expect(model.vaultRecoveryStatus?.contains("schema 8") == true)

    model.restoreVaultBackup(
        at: packageURL,
        to: destinationRoot
    )
    await waitForVaultRecovery(model)
    #expect(model.vaultRecoveryStatus?.contains("New vault restored") == true)
    #expect(model.vaultRecoveryStatus?.contains("2 watched sources paused") == true)
    #expect(
        model.vaultRecoveryStatus?
            .contains("1 authority record quarantined") == true
    )
}

@MainActor
@Test("app model reports vault recovery failures without exposing error content")
func appModelReportsVaultRecoveryFailuresSafely() async {
    let operations = VaultRecoveryOperations(
        create: { _, _ in
            throw FullVaultBackupError.payloadEntryMismatch(
                "private-file-name"
            )
        },
        validate: { _ in
            throw FullVaultBackupError.databaseIntegrityFailed
        },
        restore: { _, _ in
            throw FullVaultBackupError.restoreDestinationExists
        }
    )
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        vaultRecoveryOperations: operations,
        vaultRootProvider: { URL(filePath: "/tmp/SourceVault") }
    )

    model.createVaultBackup(to: URL(filePath: "/tmp/Backup.camvault"))
    await waitForVaultRecovery(model)

    #expect(
        model.vaultRecoveryError
            == "The local backup could not be created. No existing vault was changed."
    )
    #expect(model.vaultRecoveryStatus == nil)
    #expect(model.vaultRecoveryError?.contains("private-file-name") == false)
}

@MainActor
private func waitForVaultRecovery(_ model: AppModel) async {
    for _ in 0..<100 where model.isVaultRecoveryRunning {
        await Task.yield()
    }
}

@MainActor
@Test("app model keeps packaged module authority explicit across removal and reload")
func appModelRunsPackagedModuleLifecycle() throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "CAMAssistantAppModule-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let coreMarker = root.appending(path: "content/core-memory-marker.txt")
    try FileManager.default.createDirectory(
        at: coreMarker.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("keep".utf8).write(to: coreMarker)
    let model = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        vaultRootProvider: { root }
    )

    model.reloadPackagedTextSummaryModule()
    #expect(!model.packagedTextSummaryPresentation.isInstalled)
    model.installPackagedTextSummaryModule()
    #expect(model.packagedTextSummaryPresentation.isInstalled)
    #expect(!model.packagedTextSummaryPresentation.isEnabled)
    #expect(!model.packagedTextSummaryPresentation.hasLocalTextGrant)

    model.enablePackagedTextSummaryModule()
    #expect(model.packagedTextSummaryPresentation.isEnabled)
    model.packagedTextSummaryInput = "one two two"
    model.summarizeWithPackagedTextSummaryModule()
    #expect(model.packagedTextSummaryResult == nil)

    model.grantPackagedTextSummaryLocalRead()
    #expect(model.packagedTextSummaryPresentation.hasLocalTextGrant)
    model.summarizeWithPackagedTextSummaryModule()
    #expect(
        model.packagedTextSummaryResult
            == PackagedTextSummary(wordCount: 3, characterCount: 11)
    )

    model.disablePackagedTextSummaryModule()
    #expect(!model.packagedTextSummaryPresentation.isEnabled)
    #expect(!model.packagedTextSummaryPresentation.hasLocalTextGrant)
    model.removePackagedTextSummaryModule()
    #expect(!model.packagedTextSummaryPresentation.isInstalled)
    #expect(try Data(contentsOf: coreMarker) == Data("keep".utf8))

    let reloaded = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        vaultRootProvider: { root }
    )
    reloaded.reloadPackagedTextSummaryModule()
    #expect(!reloaded.packagedTextSummaryPresentation.isInstalled)
    #expect(!reloaded.packagedTextSummaryPresentation.hasLocalTextGrant)
}
