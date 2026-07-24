import CAMAssistantCore
import Darwin
import SwiftUI

@main
struct CAMAssistantApp: App {
    @StateObject private var model = AppModel()

    init() {
        if CommandLine.arguments.contains("--smoke-offline") {
            let health = AppHealth.evaluate(
                localModelAvailable: false,
                camRuntimeAvailable: false,
                networkAvailable: false
            )
            print(
                "CAM_ASSISTANT_SMOKE mode=\(health.mode.rawValue)"
                    + " capture=\(health.canCapture)"
                    + " local_search=\(health.canSearchLocalContent)"
                    + " cloud_auto=\(health.cloudWasAutoSelected)"
            )
            Darwin.exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        WindowGroup(BuildIdentity.productName, id: "assistant") {
            AssistantWindow(model: model)
                .frame(minWidth: 720, minHeight: 480)
        }

        MenuBarExtra(
            BuildIdentity.productName,
            systemImage: model.health.mode == .localReady
                ? "sparkles"
                : "sparkles.rectangle.stack"
        ) {
            MenuBarPanel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.health.statusMessage, systemImage: model.health.symbolName)
                .font(.headline)
                .accessibilityLabel("System status: \(model.health.statusMessage)")

            Button("Open Assistant") {
                openWindow(id: "assistant")
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Opens the main CAM Assistant window")

            Divider()

            Text("Capture and local search stay available when intelligence services are offline.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 340)
    }
}

private extension AppHealth {
    var symbolName: String {
        switch mode {
        case .localReady:
            "checkmark.circle.fill"
        case .degraded:
            "exclamationmark.triangle.fill"
        case .offline:
            "wifi.slash"
        }
    }
}
