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

@Test("settings exposes every required user-facing group as a distinct selection")
func settingsExposesEveryRequiredGroup() {
    #expect(
        BarebonesSettingsSection.allCases.map(\.title)
            == [
                "Capture",
                "Local AI",
                "Backup & Restore",
                "Advanced",
            ]
    )
    #expect(Set(BarebonesSettingsSection.allCases.map(\.id)).count == 4)
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
