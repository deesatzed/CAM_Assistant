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

