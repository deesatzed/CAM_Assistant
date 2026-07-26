import Dispatch
import Foundation

public protocol WatchedSourceWatching: AnyObject {
    func start(handler: @escaping @Sendable ([CaptureEnvelope]) -> Void) throws
    func stop()
}

public enum WatchedSourceRuntimeState: Equatable, Sendable {
    case paused
    case running
    case failed
}

extension FolderWatcher: WatchedSourceWatching {
    public func start(handler: @escaping @Sendable ([CaptureEnvelope]) -> Void) throws {
        try start(
            queue: DispatchQueue(label: "cam-assistant.watched-source"),
            handler: handler
        )
    }
}

public final class WatchedSourceManager: @unchecked Sendable {
    public typealias WatcherFactory = (WatchedSource) -> any WatchedSourceWatching
    public typealias CaptureHandler = @Sendable (CaptureEnvelope) -> Void

    private let makeWatcher: WatcherFactory
    private let capture: CaptureHandler
    private let lock = NSLock()
    private var active: [UUID: any WatchedSourceWatching] = [:]
    private var states: [UUID: WatchedSourceRuntimeState] = [:]

    public init(
        makeWatcher: @escaping WatcherFactory = { FolderWatcher(directoryURL: URL(filePath: $0.canonicalPath)) },
        capture: @escaping CaptureHandler
    ) {
        self.makeWatcher = makeWatcher
        self.capture = capture
    }

    deinit {
        lock.lock()
        defer { lock.unlock() }
        active.values.forEach { $0.stop() }
    }

    public func reconcile(_ sources: [WatchedSource]) throws {
        lock.lock()
        defer { lock.unlock() }

        let enabled = sources.filter(\.isEnabled)
        let enabledIDs = Set(enabled.map(\.id))
        for id in active.keys where !enabledIDs.contains(id) {
            active.removeValue(forKey: id)?.stop()
            states[id] = .paused
        }
        for source in sources where !source.isEnabled {
            states[source.id] = .paused
        }
        for source in enabled where active[source.id] == nil {
            let watcher = makeWatcher(source)
            do {
                try watcher.start { [capture] envelopes in
                    envelopes.forEach(capture)
                }
                active[source.id] = watcher
                states[source.id] = .running
            } catch {
                states[source.id] = .failed
            }
        }
    }

    public func runtimeState(for sourceID: UUID) -> WatchedSourceRuntimeState? {
        lock.lock()
        defer { lock.unlock() }
        return states[sourceID]
    }
}
