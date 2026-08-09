import AppKit
import CAMAssistantCore
import SwiftUI

struct CaptureSourcesView: View {
    @ObservedObject var model: AppModel
    @State private var folderPendingRemoval: WatchedSourcePresentation?

    var body: some View {
        Form {
            Section("Watched folders") {
                Text(
                    "Folders are local-only and paused until you explicitly enable them."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if model.watchedSourcePresentation.isEmpty {
                    Text("No folders are configured for automatic local capture.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.watchedSourcePresentation) { source in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.canonicalPath).textSelection(.enabled)
                        Text(source.statusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(source.isEnabled ? "Pause" : "Enable") {
                                model.setWatchedSourceEnabled(
                                    !source.isEnabled,
                                    sourceID: source.id
                                )
                            }
                            Button("Remove…", role: .destructive) {
                                folderPendingRemoval = source
                            }
                        }
                    }
                }
                Button("Add Folder…", action: chooseFolder)
                if model.isUpdatingWatchedSources {
                    ProgressView("Updating local watched sources…")
                }
                if let error = model.watchedSourceError {
                    Text(error).foregroundStyle(.red)
                }
                Text("Press Escape or Done when you are finished here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.isUpdatingWatchedSources)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Watched folders. Folders remain local and require explicit enablement before capture. Press Escape or Done to close."
        )
        .confirmationDialog(
            "Stop watching this folder?",
            isPresented: Binding(
                get: { folderPendingRemoval != nil },
                set: { if !$0 { folderPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove folder", role: .destructive) {
                if let source = folderPendingRemoval {
                    model.removeWatchedSource(source.id)
                }
                folderPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                folderPendingRemoval = nil
            }
        } message: {
            Text(removeMessage)
        }
    }

    private var removeMessage: String {
        guard let source = folderPendingRemoval else { return "" }
        return """
            CAM will stop watching “\(source.canonicalPath)”. \
            Items already in your Library stay saved.
            """
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.addWatchedSource(path: url.path)
    }
}
