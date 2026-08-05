import Foundation

enum CaptureNotice: Equatable {
    case saved(String)
    case alreadySaved(String)
    case queued(String)
    case emptyClipboard
    case failed(itemName: String, technicalDetails: String)

    var message: String {
        switch self {
        case let .saved(itemName):
            "Saved \(itemName) to your Library."
        case let .alreadySaved(itemName):
            "\(itemName) is already in your Library."
        case let .queued(itemName):
            "\(itemName) will appear in your Library when processing finishes."
        case .emptyClipboard:
            "Copy some text, then try Save Clipboard again."
        case let .failed(itemName, _):
            "CAM couldn't save \(itemName). You can try again."
        }
    }

    var canRetry: Bool {
        switch self {
        case .emptyClipboard, .failed:
            true
        case .saved, .alreadySaved, .queued:
            false
        }
    }

    var contentSafetyMessage: String? {
        switch self {
        case .failed:
            "Your original content was not changed."
        case .saved, .alreadySaved, .queued, .emptyClipboard:
            nil
        }
    }

    var technicalDetails: String? {
        guard case let .failed(_, details) = self else { return nil }
        return details
    }
}
