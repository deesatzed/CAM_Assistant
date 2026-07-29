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

@Test("settings exposes every required local pane as a distinct selection")
func settingsExposesEveryRequiredPane() {
    #expect(
        SettingsPane.allCases.map(\.title)
            == [
                "Models",
                "Hotkeys",
                "Capture Sources",
                "Backup & Recovery",
            ]
    )
    #expect(Set(SettingsPane.allCases.map(\.id)).count == 4)
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
