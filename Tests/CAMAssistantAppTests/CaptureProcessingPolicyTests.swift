import Testing
@testable import CAMAssistantApp

@Test("capture processing remains automatic unless the proof harness explicitly defers it")
func captureProcessingDefaultsToAutomatic() {
    #expect(
        CaptureProcessingPolicy.shouldDefer(environment: [:]) == false
    )
    #expect(
        CaptureProcessingPolicy.shouldDefer(
            environment: ["CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING": "0"]
        ) == false
    )
    #expect(
        CaptureProcessingPolicy.shouldDefer(
            environment: ["CAM_ASSISTANT_DEFER_CAPTURE_PROCESSING": "1"]
        )
    )
}
