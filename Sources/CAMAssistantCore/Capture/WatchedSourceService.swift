import Foundation

public enum WatchedSourceServiceError: Error, Equatable {
    case sourceNotFound(UUID)
}

public final class WatchedSourceService: @unchecked Sendable {
    private let store: WatchedSourceConfigurationStore
    private let manager: WatchedSourceManager
    private let lock = NSLock()
    private var sources: [WatchedSource] = []

    public init(store: WatchedSourceConfigurationStore, manager: WatchedSourceManager) {
        self.store = store
        self.manager = manager
    }

    public func reload() throws {
        let loaded = try store.load()
        try manager.reconcile(loaded)
        lock.lock()
        sources = loaded
        lock.unlock()
    }

    @discardableResult
    public func add(path: String) throws -> WatchedSource {
        let source = try WatchedSource(path: path, isEnabled: false)
        try update { $0.append(source) }
        return source
    }

    public func setEnabled(_ isEnabled: Bool, for sourceID: UUID) throws {
        try update { sources in
            guard let index = sources.firstIndex(where: { $0.id == sourceID }) else {
                throw WatchedSourceServiceError.sourceNotFound(sourceID)
            }
            sources[index].isEnabled = isEnabled
        }
    }

    public func remove(_ sourceID: UUID) throws {
        try update { sources in
            guard sources.contains(where: { $0.id == sourceID }) else {
                throw WatchedSourceServiceError.sourceNotFound(sourceID)
            }
            sources.removeAll { $0.id == sourceID }
        }
    }

    public func presentations() -> [WatchedSourcePresentation] {
        lock.lock()
        let snapshot = sources
        lock.unlock()
        return snapshot.map {
            WatchedSourcePresentation(
                source: $0,
                runtimeState: manager.runtimeState(for: $0.id) ?? .paused
            )
        }
    }

    private func update(_ change: (inout [WatchedSource]) throws -> Void) throws {
        lock.lock()
        var next = sources
        lock.unlock()
        try change(&next)
        try store.save(next)
        try manager.reconcile(next)
        lock.lock()
        sources = next
        lock.unlock()
    }
}
