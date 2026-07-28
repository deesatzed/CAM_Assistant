import Testing
@testable import CAMAssistantApp

@MainActor
@Test("global open hotkey activates the app before raising its window")
func globalOpenHotkeyActivatesBeforeRaisingWindow() {
    var events: [String] = []
    let activation = AssistantForegroundActivation(
        prepare: { events.append("prepare") },
        activate: { events.append("activate") },
        raiseWindow: { events.append("raise") }
    )

    activation.perform()

    #expect(events == ["prepare", "activate", "raise"])
}

@Test("settings exposes models hotkeys and capture sources as distinct panes")
func settingsExposesEveryRequiredPane() {
    #expect(
        SettingsPane.allCases.map(\.title)
            == ["Models", "Hotkeys", "Capture Sources"]
    )
    #expect(Set(SettingsPane.allCases.map(\.id)).count == 3)
}

@Test("default open hotkey avoids the macOS Finder search collision")
func defaultOpenHotkeyAvoidsFinderSearchCollision() {
    #expect(AssistantHotkeyDefaults.openKey == "k")
    #expect(AssistantHotkeyDefaults.openKey != "space")
    #expect(AssistantHotkeyDefaults.captureKey == "c")
}

@Test("letter hotkeys use the real macOS virtual key codes")
func letterHotkeysUseMacVirtualKeyCodes() {
    #expect(HotkeyManager.keyCode(for: "a") == 0)
    #expect(HotkeyManager.keyCode(for: "c") == 8)
    #expect(HotkeyManager.keyCode(for: "k") == 40)
    #expect(HotkeyManager.keyCode(for: "z") == 6)
}
