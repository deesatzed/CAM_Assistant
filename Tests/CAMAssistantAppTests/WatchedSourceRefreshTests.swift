import Testing
@testable import CAMAssistantApp

@MainActor
@Test("successful watched capture refreshes the native Library after status")
func successfulWatchedCaptureRefreshesLibrary() {
    var events: [String] = []
    let refresh = WatchedSourceCaptureRefresh(
        setMessage: { events.append("message:\($0)") },
        reloadLibrary: { events.append("reload") }
    )

    refresh.perform()

    #expect(
        events == [
            "message:\(WatchedSourceCaptureRefresh.successMessage)",
            "reload",
        ]
    )
}
