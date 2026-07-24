public enum AppOperatingMode: String, Sendable {
    case offline
    case degraded
    case localReady
}

public struct AppHealth: Equatable, Sendable {
    public let mode: AppOperatingMode
    public let canCapture: Bool
    public let canSearchLocalContent: Bool
    public let canAnswerWithLocalModel: Bool
    public let canUseCAM: Bool
    public let canUseCloud: Bool
    public let cloudWasAutoSelected: Bool
    public let statusMessage: String

    public static func evaluate(
        localModelAvailable: Bool,
        camRuntimeAvailable: Bool,
        networkAvailable: Bool
    ) -> AppHealth {
        let mode: AppOperatingMode
        let statusMessage: String

        if localModelAvailable {
            mode = .localReady
            statusMessage = camRuntimeAvailable
                ? "Local intelligence is ready."
                : "CAM tools are unavailable. Local answers remain ready."
        } else if networkAvailable || camRuntimeAvailable {
            mode = .degraded
            statusMessage = "The local model is unavailable. Capture and local search remain ready."
        } else {
            mode = .offline
            statusMessage = "Offline. Capture and local search remain ready."
        }

        return AppHealth(
            mode: mode,
            canCapture: true,
            canSearchLocalContent: true,
            canAnswerWithLocalModel: localModelAvailable,
            canUseCAM: camRuntimeAvailable,
            canUseCloud: networkAvailable,
            cloudWasAutoSelected: false,
            statusMessage: statusMessage
        )
    }
}
