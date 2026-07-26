import Foundation

public struct WatchedSource: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let canonicalPath: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), path: String, isEnabled: Bool) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WatchedSourceConfigurationError.emptyPath }
        self.id = id
        canonicalPath = URL(filePath: trimmed).standardizedFileURL.path
        self.isEnabled = isEnabled
    }
}

public enum WatchedSourceConfigurationError: Error, Equatable {
    case emptyPath
    case duplicatePath(String)
    case duplicateID(UUID)
}

public struct WatchedSourcePresentation: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let canonicalPath: String
    public let isEnabled: Bool
    public let statusLabel: String

    public init(source: WatchedSource, runtimeState: WatchedSourceRuntimeState) {
        id = source.id
        canonicalPath = source.canonicalPath
        isEnabled = source.isEnabled
        statusLabel = switch runtimeState {
        case .paused: "Paused"
        case .running: "Watching locally"
        case .failed: "Could not start local watcher"
        }
    }
}

public final class WatchedSourceConfigurationStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> [WatchedSource] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([WatchedSource].self, from: Data(contentsOf: url))
    }

    public func save(_ sources: [WatchedSource]) throws {
        var paths = Set<String>()
        var ids = Set<UUID>()
        for source in sources {
            guard ids.insert(source.id).inserted else {
                throw WatchedSourceConfigurationError.duplicateID(source.id)
            }
            guard paths.insert(source.canonicalPath).inserted else {
                throw WatchedSourceConfigurationError.duplicatePath(source.canonicalPath)
            }
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(sources).write(to: url, options: .atomic)
    }
}
