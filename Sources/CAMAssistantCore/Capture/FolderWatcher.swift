import CoreServices
import CryptoKit
import Dispatch
import Foundation

public enum FolderWatcherError: Error {
    case alreadyRunning
    case streamCreationFailed(String)
    case streamStartFailed(String)
}

public final class FolderWatcher: @unchecked Sendable {
    public let directoryURL: URL
    private let lock = NSRecursiveLock()
    private var fingerprints: [String: String] = [:]
    private var stream: FSEventStreamRef?
    private var callbackBox: Unmanaged<FolderWatcherCallbackBox>?

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func scanChanges(capturedAt: Date = Date()) throws -> [CaptureEnvelope] {
        lock.lock()
        defer { lock.unlock() }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var changed: [CaptureEnvelope] = []
        var current: [String: String] = [:]

        for url in urls.sorted(by: { $0.path < $1.path }) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let data = try Data(contentsOf: url)
            let reportedURL = directoryURL.appending(path: url.lastPathComponent)
            let fingerprint = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            current[url.path] = fingerprint
            guard fingerprints[url.path] != fingerprint else { continue }
            changed.append(
                CaptureEnvelope(
                    capturedAt: capturedAt,
                    sourceName: url.lastPathComponent,
                    contentType: Self.contentType(for: url),
                    data: data,
                    origin: .watchedFolder(path: reportedURL.path)
                )
            )
        }

        fingerprints = current
        return changed
    }

    public func start(
        queue: DispatchQueue = DispatchQueue(label: "cam-assistant.folder-watcher"),
        handler: @escaping @Sendable ([CaptureEnvelope]) -> Void
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard stream == nil else { throw FolderWatcherError.alreadyRunning }

        let box = FolderWatcherCallbackBox(watcher: self, handler: handler)
        let unmanagedBox = Unmanaged.passRetained(box)
        var context = FSEventStreamContext(
            version: 0,
            info: unmanagedBox.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot
        )
        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            folderWatcherCallback,
            &context,
            [directoryURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05,
            flags
        ) else {
            unmanagedBox.release()
            throw FolderWatcherError.streamCreationFailed(directoryURL.path)
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            unmanagedBox.release()
            throw FolderWatcherError.streamStartFailed(directoryURL.path)
        }

        callbackBox = unmanagedBox
        stream = created
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        callbackBox?.release()
        callbackBox = nil
    }

    deinit {
        stop()
    }

    private static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "txt":
            url.lastPathComponent.hasSuffix(".transcript.txt")
                ? "text/x-transcript"
                : "text/plain"
        case "md", "markdown":
            "text/markdown"
        case "swift", "py", "js", "ts", "rb", "go", "rs", "c", "h", "cpp":
            "text/x-source-code"
        case "json", "toml", "yaml", "yml", "env":
            "text/x-configuration"
        case "pdf":
            "application/pdf"
        case "png":
            "image/png"
        case "jpg", "jpeg":
            "image/jpeg"
        case "wav":
            "audio/wav"
        case "m4a":
            "audio/mp4"
        case "mp3":
            "audio/mpeg"
        default:
            "application/octet-stream"
        }
    }
}

private final class FolderWatcherCallbackBox: @unchecked Sendable {
    weak var watcher: FolderWatcher?
    let handler: @Sendable ([CaptureEnvelope]) -> Void

    init(
        watcher: FolderWatcher,
        handler: @escaping @Sendable ([CaptureEnvelope]) -> Void
    ) {
        self.watcher = watcher
        self.handler = handler
    }

    func receiveEvent() {
        guard let watcher,
              let envelopes = try? watcher.scanChanges(),
              !envelopes.isEmpty else {
            return
        }
        handler(envelopes)
    }
}

private let folderWatcherCallback: FSEventStreamCallback = {
    _, clientInfo, _, _, _, _ in
    guard let clientInfo else { return }
    Unmanaged<FolderWatcherCallbackBox>
        .fromOpaque(clientInfo)
        .takeUnretainedValue()
        .receiveEvent()
}
