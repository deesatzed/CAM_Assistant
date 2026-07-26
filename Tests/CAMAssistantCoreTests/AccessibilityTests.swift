import Foundation
import Testing
@testable import CAMAssistantCore

@Test("hotkey configuration requires distinct nonempty shortcuts")
func hotkeyConfigurationRequiresDistinctNonemptyShortcuts() throws {
    let configuration = try HotkeyConfiguration(
        openAssistant: HotkeyShortcut(key: "space", modifiers: [.command, .option]),
        captureClipboard: HotkeyShortcut(key: "c", modifiers: [.command, .option])
    )

    #expect(configuration.openAssistant.key == "space")
    #expect(throws: HotkeyConfigurationError.duplicateShortcut) {
        _ = try HotkeyConfiguration(
            openAssistant: HotkeyShortcut(key: "space", modifiers: [.command]),
            captureClipboard: HotkeyShortcut(key: "space", modifiers: [.command])
        )
    }
}

@Test("accessibility status preserves an explicit offline explanation")
func accessibilityStatusPreservesOfflineExplanation() {
    let status = AccessibilityStatus(health: .evaluate(localModelAvailable: false, camRuntimeAvailable: false, networkAvailable: false))

    #expect(status.label.contains("offline"))
    #expect(status.hint.contains("local"))
}

@Test("global hotkey status exposes registration without implying action proof")
func globalHotkeyStatusExposesRegistrationWithoutImplyingActionProof() {
    #expect(GlobalHotkeyStatus.active.label == "Global hotkeys active")
    #expect(GlobalHotkeyStatus.active.hint.contains("registered"))
    #expect(GlobalHotkeyStatus.unavailable.label == "Global hotkeys unavailable")
}

@Test("hotkey configuration persists atomically across restart")
func hotkeyConfigurationPersistsAtomicallyAcrossRestart() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    let configuration = try HotkeyConfiguration(openAssistant: HotkeyShortcut(key: "space", modifiers: [.command, .option]), captureClipboard: HotkeyShortcut(key: "c", modifiers: [.command, .option]))

    try HotkeyConfigurationStore(url: url).save(configuration)
    #expect(try HotkeyConfigurationStore(url: url).load() == configuration)
}
