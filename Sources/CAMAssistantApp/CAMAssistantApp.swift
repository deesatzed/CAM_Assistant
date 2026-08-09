import CAMAssistantCore
import Darwin
import SwiftUI

@main
struct CAMAssistantApp: App {
    /// Constructed in `init` (not a property default) to avoid a SILGen crash
    /// on some Swift 6.1 toolchains when default-arg `AppModel()` is stored in
    /// `@StateObject` at property init time.
    @StateObject private var model: AppModel

    init() {
        if let proofRoot = Self.barebonesProofRoot() {
            let holdSeconds = Self.barebonesProofHoldSeconds()
            switch BarebonesPackagedProof.runBlocking(
                applicationSupportRoot: proofRoot
            ) {
            case let .success(receipt):
                print(
                    "CAM_ASSISTANT_BAREBONES_PROOF status=pass "
                        + receipt.summary
                )
                fflush(stdout)
                if holdSeconds > 0 {
                    Thread.sleep(forTimeInterval: holdSeconds)
                }
                Darwin.exit(EXIT_SUCCESS)
            case let .failure(error):
                print(
                    "CAM_ASSISTANT_BAREBONES_PROOF status=fail reason="
                        + error.safeCode
                )
                fflush(stdout)
                Darwin.exit(EXIT_FAILURE)
            case .unexpectedFailure:
                print(
                    "CAM_ASSISTANT_BAREBONES_PROOF status=fail "
                        + "reason=unexpected"
                )
                fflush(stdout)
                Darwin.exit(EXIT_FAILURE)
            }
        }
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
        _model = StateObject(
            wrappedValue: AppModel(initializeFullWorkspace: true)
        )
    }

    private static func barebonesProofRoot() -> URL? {
        guard let optionIndex = CommandLine.arguments.firstIndex(
            of: "--barebones-proof"
        ), CommandLine.arguments.indices.contains(optionIndex + 1) else {
            return nil
        }
        let path = CommandLine.arguments[optionIndex + 1]
        guard path.hasPrefix("/") else { return nil }
        return URL(filePath: path, directoryHint: .isDirectory)
            .standardizedFileURL
    }

    private static func barebonesProofHoldSeconds() -> Double {
        let value = ProcessInfo.processInfo.environment[
            "CAM_ASSISTANT_BAREBONES_PROOF_HOLD_SECONDS"
        ].flatMap(Double.init) ?? 0
        return min(max(value, 0), 10)
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
