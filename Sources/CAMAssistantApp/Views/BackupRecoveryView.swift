import AppKit
import SwiftUI

struct BackupRecoveryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Local vault backup") {
                Text(
                    "Create one integrity-checked local package. "
                    + "The package contains app-owned vault state and never "
                    + "uploads data."
                )
                .foregroundStyle(.secondary)
                Button("Create Backup…", action: chooseBackupDestination)
                    .disabled(model.isVaultRecoveryRunning)
                    .accessibilityHint(
                        "Selects one local destination and creates a validated CAM vault package."
                    )
                Button("Validate Backup…", action: chooseBackupToValidate)
                    .disabled(model.isVaultRecoveryRunning)
                    .accessibilityHint(
                        "Checks manifest, hashes, content identities, and SQLite integrity without restoring."
                    )
            }

            Section("Fresh-root recovery") {
                Text(
                    "Restore creates a separate new CAMAssistant vault inside "
                    + "a folder you select. It never overwrites or merges the "
                    + "vault currently in use."
                )
                .foregroundStyle(.secondary)
                Text(
                    "Restored watched folders remain paused. Approval and "
                    + "module records are quarantined for review rather than "
                    + "regaining authority."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Button(
                    "Restore to New Vault…",
                    action: chooseBackupAndRestoreDestination
                )
                .disabled(model.isVaultRecoveryRunning)
                .accessibilityHint(
                    "Validates a local package and restores it only to a new CAMAssistant vault."
                )
            }

            Section("Operation status") {
                if model.isVaultRecoveryRunning {
                    ProgressView("Working locally…")
                } else if let status = model.vaultRecoveryStatus {
                    Text(status)
                        .textSelection(.enabled)
                        .accessibilityLabel("Backup operation succeeded. \(status)")
                } else if let error = model.vaultRecoveryError {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Backup operation failed. \(error)")
                } else {
                    Text("No backup or restore operation has run in this session.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Backup and Recovery. Local integrity-checked packages and fresh-root restore."
        )
    }

    private func chooseBackupDestination() {
        let panel = NSSavePanel()
        panel.title = "Create CAM Assistant Backup"
        panel.nameFieldStringValue = "CAM-Assistant-Backup.camvault"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let packageURL = url.pathExtension.lowercased() == "camvault"
            ? url
            : url.appendingPathExtension("camvault")
        model.createVaultBackup(to: packageURL)
    }

    private func chooseBackupToValidate() {
        guard let packageURL = chooseBackupPackage(
            title: "Validate CAM Assistant Backup"
        ) else {
            return
        }
        model.validateVaultBackup(at: packageURL)
    }

    private func chooseBackupAndRestoreDestination() {
        guard let packageURL = chooseBackupPackage(
            title: "Choose CAM Assistant Backup to Restore"
        ) else {
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Choose New Application-Support Folder"
        panel.prompt = "Restore Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        model.restoreVaultBackup(
            at: packageURL,
            to: parent.appending(
                path: "CAMAssistant",
                directoryHint: .isDirectory
            )
        )
    }

    private func chooseBackupPackage(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              url.pathExtension.lowercased() == "camvault" else {
            return nil
        }
        return url
    }
}

