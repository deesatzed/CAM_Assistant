import Foundation

public enum CaptureOrigin: Equatable, Sendable {
    case clipboard
    case watchedFolder(path: String)

    var storedKind: String {
        switch self {
        case .clipboard:
            "clipboard"
        case .watchedFolder:
            "watchedFolder"
        }
    }

    var storedDetail: String? {
        switch self {
        case .clipboard:
            nil
        case let .watchedFolder(path):
            path
        }
    }

    static func stored(kind: String, detail: String?) -> CaptureOrigin {
        switch kind {
        case "watchedFolder":
            .watchedFolder(path: detail ?? "")
        default:
            .clipboard
        }
    }
}

public struct CaptureEnvelope: Equatable, Sendable {
    public let id: UUID
    public let capturedAt: Date
    public let sourceName: String
    public let contentType: String
    public let data: Data
    public let origin: CaptureOrigin

    public init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        sourceName: String,
        contentType: String,
        data: Data,
        origin: CaptureOrigin
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.sourceName = sourceName
        self.contentType = contentType
        self.data = data
        self.origin = origin
    }
}

public struct CaptureReceipt: Equatable, Sendable {
    public let captureID: UUID
    public let sourceID: ContentID
    public let wasDuplicateSource: Bool
}

public final class CaptureService {
    private let queue: IngestQueue

    public init(queue: IngestQueue) {
        self.queue = queue
    }

    public func capture(_ envelope: CaptureEnvelope) throws -> CaptureReceipt {
        try queue.enqueue(envelope)
    }
}
