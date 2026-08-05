import Foundation

@MainActor
struct WatchedSourceCaptureRefresh {
    static let successMessage =
        "Saved new items from your watched folder to your Library."

    let setMessage: @MainActor (String) -> Void
    let reloadLibrary: @MainActor () -> Void

    func perform() {
        setMessage(Self.successMessage)
        reloadLibrary()
    }
}
