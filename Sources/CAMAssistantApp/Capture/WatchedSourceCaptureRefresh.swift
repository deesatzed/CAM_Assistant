import Foundation

@MainActor
struct WatchedSourceCaptureRefresh {
    static let successMessage =
        "Watched folder captured and indexed content locally."

    let setMessage: @MainActor (String) -> Void
    let reloadLibrary: @MainActor () -> Void

    func perform() {
        setMessage(Self.successMessage)
        reloadLibrary()
    }
}
