import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section("Global hotkeys") {
                TextField("Open key", text: $model.hotkeyOpenKey)
                TextField("Capture key", text: $model.hotkeyCaptureKey)
                Text("Uses Command-Option plus a single letter or space. Registration is session-only.").font(.caption).foregroundStyle(.secondary)
                Button("Save and Register", action: model.saveAndRegisterHotkeys)
                Text(model.hotkeyStatus.label).font(.caption)
                if let error = model.hotkeyError { Text(error).foregroundStyle(.red) }
            }
        }.formStyle(.grouped)
    }
}
