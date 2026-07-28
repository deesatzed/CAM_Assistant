import Foundation

enum CaptureProcessingPolicy {
    static let deferralEnvironmentKey =
        "CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING"

    static func shouldDefer(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[deferralEnvironmentKey] == "1"
    }
}
