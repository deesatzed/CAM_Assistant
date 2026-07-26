import Foundation

public enum CaptureOrigin: Equatable, Sendable {
    case clipboard
    case watchedFolder(path: String)
    case repository(canonicalPath: String, commit: String)

    var storedKind: String {
        return switch self {
        case .clipboard:
            "clipboard"
        case .watchedFolder:
            "watchedFolder"
        case .repository:
            "repository"
        }
    }

    var storedDetail: String? {
        switch self {
        case .clipboard:
            return nil
        case let .watchedFolder(path):
            return path
        case let .repository(canonicalPath, commit):
            let detail = RepositoryCaptureOriginDetail(canonicalPath: canonicalPath, commit: commit)
            return (try? JSONEncoder().encode(detail))
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    static func stored(kind: String, detail: String?) -> CaptureOrigin {
        switch kind {
        case "watchedFolder":
            return .watchedFolder(path: detail ?? "")
        case "repository":
            guard let detail,
                  let decoded = try? JSONDecoder().decode(
                    RepositoryCaptureOriginDetail.self,
                    from: Data(detail.utf8)
                  ) else {
                return .clipboard
            }
            return .repository(canonicalPath: decoded.canonicalPath, commit: decoded.commit)
        default:
            return .clipboard
        }
    }
}

private struct RepositoryCaptureOriginDetail: Codable {
    let canonicalPath: String
    let commit: String
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
