struct HomePresentation: Equatable {
    let title: String
    let primaryActionTitle: String
    let questionPrompt: String
    let privacyNote: String

    init(libraryItemCount: Int) {
        title = libraryItemCount == 0
            ? "Your private Library is empty"
            : "Your private memory"
        primaryActionTitle = "Save Clipboard"
        questionPrompt = "What are you looking for?"
        privacyNote = "Your saved content stays on this Mac."
    }

    static let empty = HomePresentation(libraryItemCount: 0)

    var visibleText: String {
        [title, primaryActionTitle, questionPrompt, privacyNote]
            .joined(separator: " ")
    }
}

enum LocalAssistantAvailability: Equatable {
    case available
    case unavailable

    var explanation: String {
        switch self {
        case .available:
            "Local AI is ready."
        case .unavailable:
            "Local AI is not running, so CAM will show matching passages from your Library."
        }
    }
}
