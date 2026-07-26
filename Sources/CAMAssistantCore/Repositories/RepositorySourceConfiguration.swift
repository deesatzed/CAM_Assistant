import Foundation

/// A user-selected repository source. Saving this record does not inspect the
/// path, access Git, index files, or grant any mining authority.
public struct RepositorySource: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let canonicalPath: String

    public init(id: UUID = UUID(), path: String) throws {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RepositorySourceConfigurationError.emptyPath }
        self.id = id
        canonicalPath = URL(filePath: trimmed).standardizedFileURL.path
    }
}

public enum RepositorySourceConfigurationError: Error, Equatable {
    case emptyPath
    case duplicatePath(String)
    case duplicateID(UUID)
    case sourceNotFound(UUID)
}

public final class RepositorySourceConfigurationStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> [RepositorySource] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([RepositorySource].self, from: Data(contentsOf: url))
    }

    public func save(_ sources: [RepositorySource]) throws {
        var paths = Set<String>()
        var ids = Set<UUID>()
        for source in sources {
            guard ids.insert(source.id).inserted else {
                throw RepositorySourceConfigurationError.duplicateID(source.id)
            }
            guard paths.insert(source.canonicalPath).inserted else {
                throw RepositorySourceConfigurationError.duplicatePath(source.canonicalPath)
            }
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(sources).write(to: url, options: .atomic)
    }
}

/// Local source selection service. It deliberately stores only the explicit
/// path selection, leaving inspection, indexing, and mining as separate user
/// actions with their own authority checks.
public final class RepositorySourceService {
    private let store: RepositorySourceConfigurationStore
    private var sources: [RepositorySource] = []

    public init(store: RepositorySourceConfigurationStore) {
        self.store = store
    }

    @discardableResult
    public func reload() throws -> [RepositorySource] {
        sources = try store.load()
        return sources
    }

    @discardableResult
    public func add(path: String) throws -> RepositorySource {
        let source = try RepositorySource(path: path)
        try update { $0.append(source) }
        return source
    }

    public func remove(_ sourceID: UUID) throws {
        try update { sources in
            guard sources.contains(where: { $0.id == sourceID }) else {
                throw RepositorySourceConfigurationError.sourceNotFound(sourceID)
            }
            sources.removeAll { $0.id == sourceID }
        }
    }

    private func update(_ change: (inout [RepositorySource]) throws -> Void) throws {
        var next = sources
        try change(&next)
        try store.save(next)
        sources = next
    }
}
