import Foundation
import Testing
@testable import CAMAssistantApp

@Test("ordinary Settings has four friendly groups")
func ordinarySettingsHasFourFriendlyGroups() {
    #expect(
        BarebonesSettingsSection.allCases
            == [.capture, .localAI, .backupRestore, .advanced]
    )
    #expect(
        BarebonesSettingsSection.allCases.map(\.title)
            == ["Capture", "Local AI", "Backup & Restore", "Advanced"]
    )
}

@Test("ordinary Settings copy does not expose provider configuration")
func ordinarySettingsHidesProviderConfiguration() {
    let visible = BarebonesSettingsPresentation.primaryText.lowercased()
    let forbidden = [
        "endpoint", "api key", "openrouter", "route role", "manifest",
        "source id", "sha-256",
    ]

    #expect(forbidden.allSatisfy { !visible.contains($0) })
    #expect(visible.contains("folders"))
    #expect(visible.contains("stays on this mac"))
}

@Test("primary Settings routes each deeper task without restoring specialist navigation")
func primarySettingsUsesProgressiveDisclosure() throws {
    let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let assistantWindow = try String(
        contentsOf: root.appending(
            path: "Sources/CAMAssistantApp/Views/AssistantWindow.swift"
        ),
        encoding: .utf8
    )
    let settings = try String(
        contentsOf: root.appending(
            path: "Sources/CAMAssistantApp/Views/BarebonesSettingsView.swift"
        ),
        encoding: .utf8
    )

    #expect(assistantWindow.contains("BarebonesSettingsView(model: model)"))
    #expect(settings.contains("Manage Folders"))
    #expect(settings.contains("Check Again"))
    #expect(settings.contains("Open Backup & Restore"))
    #expect(settings.contains("Open Advanced Settings"))
}
