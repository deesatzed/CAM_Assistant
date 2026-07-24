import Testing
@testable import CAMAssistantCore

@Test("offline state preserves deterministic local capabilities")
func offlineStatePreservesDeterministicLocalCapabilities() {
    let health = AppHealth.evaluate(
        localModelAvailable: false,
        camRuntimeAvailable: false,
        networkAvailable: false
    )

    #expect(health.mode == .offline)
    #expect(health.canCapture)
    #expect(health.canSearchLocalContent)
    #expect(!health.canAnswerWithLocalModel)
    #expect(!health.canUseCAM)
    #expect(!health.canUseCloud)
}

@Test("CAM outage is explicit and never triggers cloud escalation")
func camOutageIsExplicitAndNeverTriggersCloudEscalation() {
    let health = AppHealth.evaluate(
        localModelAvailable: true,
        camRuntimeAvailable: false,
        networkAvailable: true
    )

    #expect(health.mode == .localReady)
    #expect(health.canAnswerWithLocalModel)
    #expect(!health.canUseCAM)
    #expect(!health.cloudWasAutoSelected)
    #expect(health.statusMessage == "CAM tools are unavailable. Local answers remain ready.")
}

@Test("local readiness does not require network access")
func localReadinessDoesNotRequireNetworkAccess() {
    let health = AppHealth.evaluate(
        localModelAvailable: true,
        camRuntimeAvailable: true,
        networkAvailable: false
    )

    #expect(health.mode == .localReady)
    #expect(health.canUseCAM)
    #expect(!health.canUseCloud)
    #expect(health.statusMessage == "Local intelligence is ready.")
}
