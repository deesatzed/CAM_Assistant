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
    case rollbackFailed
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
    private let lifecycleStore: (any RepositorySourceLifecycleWriting)?
    private var sources: [RepositorySource] = []

    public init(
        store: RepositorySourceConfigurationStore,
        lifecycleStore: (any RepositorySourceLifecycleWriting)? = nil
    ) {
        self.store = store
        self.lifecycleStore = lifecycleStore
    }

    @discardableResult
    public func reload() throws -> [RepositorySource] {
        let configured = try store.load()
        guard let lifecycleStore else {
            sources = configured
            return sources
        }
        let lifecycle = try lifecycleStore.all()
        if lifecycle.isEmpty {
            for source in configured {
                _ = try lifecycleStore.record(
                    source,
                    status: .active,
                    at: Date()
                )
            }
            sources = configured
            return sources
        }
        let active = try lifecycle
            .filter { $0.status == .active }
            .map {
                try RepositorySource(
                    id: $0.sourceID,
                    path: $0.canonicalPath
                )
            }
        if active != configured {
            try store.save(active)
        }
        sources = active
        return sources
    }

    @discardableResult
    public func add(path: String) throws -> RepositorySource {
        let source = try RepositorySource(path: path)
        let previous = sources
        var next = previous
        next.append(source)
        guard let lifecycleStore else {
            try store.save(next)
            sources = next
            return source
        }
        guard !previous.contains(where: {
            $0.canonicalPath == source.canonicalPath
        }) else {
            throw RepositorySourceConfigurationError.duplicatePath(
                source.canonicalPath
            )
        }
        _ = try lifecycleStore.record(
            source,
            status: .active,
            at: Date()
        )
        do {
            try store.save(next)
        } catch {
            do {
                _ = try lifecycleStore.record(
                    source,
                    status: .removed,
                    at: Date()
                )
            } catch {
                throw RepositorySourceConfigurationError.rollbackFailed
            }
            throw error
        }
        sources = next
        return source
    }

    public func remove(_ sourceID: UUID) throws {
        guard let source = sources.first(where: { $0.id == sourceID }) else {
            throw RepositorySourceConfigurationError.sourceNotFound(sourceID)
        }
        let next = sources.filter { $0.id != sourceID }
        guard let lifecycleStore else {
            try store.save(next)
            sources = next
            return
        }
        _ = try lifecycleStore.record(
            source,
            status: .removed,
            at: Date()
        )
        do {
            try store.save(next)
        } catch {
            do {
                _ = try lifecycleStore.record(
                    source,
                    status: .active,
                    at: Date()
                )
            } catch {
                throw RepositorySourceConfigurationError.rollbackFailed
            }
            throw error
        }
        sources = next
    }
}
