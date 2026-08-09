import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("What these shortcuts do") {
                Text(
                    "Both shortcuts use Command–Option plus one letter (or Space). "
                        + "They work while CAM is running in this session."
                )
                .foregroundStyle(.secondary)
                LabeledContent("Open CAM") {
                    Text("Command–Option–\(displayKey(model.hotkeyOpenKey))")
                        .font(.body.monospaced())
                }
                LabeledContent("Save Clipboard") {
                    Text("Command–Option–\(displayKey(model.hotkeyCaptureKey))")
                        .font(.body.monospaced())
                }
            }

            Section("Change keys") {
                Text("Enter a single letter (A–Z) or Space for each action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "Open CAM key (letter or Space)",
                    text: $model.hotkeyOpenKey
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.hotkeyOpenKey) { _, newValue in
                    model.hotkeyOpenKey = Self.normalizeKeyField(newValue)
                }
                TextField(
                    "Save Clipboard key (letter or Space)",
                    text: $model.hotkeyCaptureKey
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.hotkeyCaptureKey) { _, newValue in
                    model.hotkeyCaptureKey = Self.normalizeKeyField(newValue)
                }
                if model.hotkeyOpenKey == model.hotkeyCaptureKey,
                   !model.hotkeyOpenKey.isEmpty
                {
                    Text("Use two different keys so the shortcuts do not conflict.")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Button("Save and turn on shortcuts") {
                    model.saveAndRegisterHotkeys()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.hotkeyOpenKey.isEmpty
                        || model.hotkeyCaptureKey.isEmpty
                        || model.hotkeyOpenKey == model.hotkeyCaptureKey
                )
                Text(model.hotkeyStatus.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = model.hotkeyError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("Tip") {
                Text(
                    "If a shortcut does not fire, check System Settings → Privacy "
                        + "& Security for Accessibility, then press Save again."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(
            "Global hotkeys. Command Option plus a letter. Escape or Done closes Advanced."
        )
    }

    private func displayKey(_ raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return "?" }
        if key == " " || key.lowercased() == "space" { return "Space" }
        return key.uppercased()
    }

    nonisolated static func normalizeKeyField(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "space" { return " " }
        if trimmed == " " { return " " }
        guard let first = trimmed.first else { return "" }
        if first.isLetter {
            return String(first).lowercased()
        }
        return String(first)
    }
}
