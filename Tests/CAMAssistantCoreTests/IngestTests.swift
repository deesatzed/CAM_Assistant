import AppKit
import Foundation
import Testing
@testable import CAMAssistantCore

@MainActor
@Test("clipboard and folder inputs ingest every required local modality")
func clipboardAndFolderIngestEveryRequiredModality() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let fixtures = repositoryRootForIngest()
        .appending(path: "Tests/Fixtures/Ingest")
    let watched = harness.root.appending(path: "watched")
    try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)

    for name in [
        "plain.txt",
        "note.md",
        "sample.swift",
        "settings.toml",
        "interview.transcript.txt",
    ] {
        try FileManager.default.copyItem(
            at: fixtures.appending(path: name),
            to: watched.appending(path: name)
        )
    }
    try decodedFixture(named: "pixel.png.base64")
        .write(to: watched.appending(path: "pixel.png"))
    try decodedFixture(named: "silence.wav.base64")
        .write(to: watched.appending(path: "silence.wav"))
    let pdfText = try String(
        contentsOf: fixtures.appending(path: "pdf-source.txt"),
        encoding: .utf8
    )
    try makePDF(text: pdfText).write(to: watched.appending(path: "source.pdf"))

    let clipboard = ClipboardCapture.envelope(
        text: "Clipboard capture is automatic.",
        capturedAt: Date(timeIntervalSince1970: 1)
    )
    _ = try harness.service.capture(clipboard)
    let watcher = FolderWatcher(directoryURL: watched)
    for envelope in try watcher.scanChanges() {
        _ = try harness.service.capture(envelope)
    }

    let results = try harness.queue.processAll()
    let documents = try harness.queue.documents()
    let modalities = Set(documents.map(\.modality))

    #expect(results.count == 9)
    #expect(results.allSatisfy { $0.status == .completed })
    #expect(try harness.contentStore.objectCount() == 9)
    #expect(modalities.isSuperset(of: [
        .text,
        .markdown,
        .code,
        .configuration,
        .transcript,
        .pdf,
        .image,
        .audio,
    ]))
    #expect(documents.contains { $0.text.contains("PDF capture preserves") })
}

@Test("duplicate bytes create one source and retain every provenance event")
func duplicateBytesCreateOneSourceWithAllProvenance() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let first = ClipboardCapture.envelope(
        text: "same bytes",
        capturedAt: Date(timeIntervalSince1970: 1)
    )
    let second = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 2),
        sourceName: "duplicate.txt",
        contentType: "text/plain",
        data: first.data,
        origin: .watchedFolder(path: "/approved/duplicate.txt")
    )

    let firstReceipt = try harness.service.capture(first)
    let secondReceipt = try harness.service.capture(second)
    _ = try harness.queue.processAll()

    #expect(!firstReceipt.wasDuplicateSource)
    #expect(secondReceipt.wasDuplicateSource)
    #expect(firstReceipt.sourceID == secondReceipt.sourceID)
    #expect(try harness.contentStore.objectCount() == 1)
    #expect(try harness.queue.sourceCount() == 1)
    #expect(try harness.queue.jobCount() == 1)
    #expect(try harness.queue.provenance(for: firstReceipt.sourceID).count == 2)
}

@Test("malformed media warns after retry and does not halt the queue")
func malformedMediaWarnsWithoutHaltingQueue() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let malformed = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 1),
        sourceName: "broken.png",
        contentType: "image/png",
        data: Data("not a png".utf8),
        origin: .watchedFolder(path: "/approved/broken.png")
    )
    let valid = ClipboardCapture.envelope(
        text: "the next item still runs",
        capturedAt: Date(timeIntervalSince1970: 2)
    )
    let malformedReceipt = try harness.service.capture(malformed)
    let validReceipt = try harness.service.capture(valid)

    _ = try harness.queue.processAll()
    let warnings = try harness.queue.warnings()

    #expect(try harness.queue.jobStatus(for: malformedReceipt.sourceID) == .failed)
    #expect(try harness.queue.jobStatus(for: validReceipt.sourceID) == .completed)
    #expect(warnings.count == 2, "The malformed source should receive its bounded retry")
    #expect(warnings.allSatisfy { $0.sourceID == malformedReceipt.sourceID })
    #expect(try harness.contentStore.data(for: malformedReceipt.sourceID) == malformed.data)
}

@Test("cancelled ingestion keeps source bytes and can be resumed")
func cancelledIngestionCanBeResumed() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let receipt = try harness.service.capture(
        ClipboardCapture.envelope(
            text: "resume me",
            capturedAt: Date(timeIntervalSince1970: 1)
        )
    )

    let cancelled = try #require(
        try harness.queue.processNext(isCancelled: { true })
    )
    #expect(cancelled.status == .cancelled)
    #expect(try harness.queue.jobStatus(for: receipt.sourceID) == .cancelled)
    #expect(try harness.contentStore.data(for: receipt.sourceID) == Data("resume me".utf8))

    try harness.queue.retry(receipt.sourceID)
    let resumed = try #require(try harness.queue.processNext())
    #expect(resumed.status == .completed)
}

@Test("pending queue and provenance survive restart")
func pendingQueueAndProvenanceSurviveRestart() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let envelope = CaptureEnvelope(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        capturedAt: Date(timeIntervalSince1970: 5),
        sourceName: "restart.md",
        contentType: "text/markdown",
        data: Data("# restart-safe".utf8),
        origin: .watchedFolder(path: "/approved/restart.md")
    )
    let receipt = try harness.service.capture(envelope)
    try harness.queue.close()

    let restarted = try IngestQueue(
        databaseURL: harness.databaseURL,
        contentStore: harness.contentStore,
        extractors: .localDefaults
    )
    let result = try #require(try restarted.processNext())
    let provenance = try restarted.provenance(for: receipt.sourceID)
    try restarted.close()

    #expect(result.status == .completed)
    #expect(provenance.count == 1)
    #expect(provenance[0].captureID == envelope.id)
    #expect(provenance[0].origin == envelope.origin)
}

@Test("folder watcher emits a capture envelope without manual rescanning")
func folderWatcherEmitsAutomatically() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-watcher-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let received = CaptureEnvelopeBox()
    let signal = DispatchSemaphore(value: 0)
    let watcher = FolderWatcher(directoryURL: root)
    _ = try watcher.scanChanges()

    try watcher.start { envelopes in
        if let first = envelopes.first(where: { $0.sourceName == "automatic.md" }) {
            received.value = first
            signal.signal()
        }
    }
    defer { watcher.stop() }
    try Data("# automatic".utf8).write(to: root.appending(path: "automatic.md"))

    #expect(signal.wait(timeout: .now() + 5) == .success)
    #expect(received.value?.data == Data("# automatic".utf8))
    #expect(received.value?.origin == .watchedFolder(path: root.appending(path: "automatic.md").path))
}

private final class IngestHarness {
    let root: URL
    let databaseURL: URL
    let contentStore: ContentStore
    let queue: IngestQueue
    let service: CaptureService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "cam-assistant-ingest-tests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        databaseURL = root.appending(path: "cam.sqlite")
        contentStore = try ContentStore(rootDirectory: root.appending(path: "content"))
        queue = try IngestQueue(
            databaseURL: databaseURL,
            contentStore: contentStore,
            extractors: .localDefaults
        )
        service = CaptureService(queue: queue)
    }

    func remove() {
        try? queue.close()
        try? FileManager.default.removeItem(at: root)
    }
}

private final class CaptureEnvelopeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: CaptureEnvelope?

    var value: CaptureEnvelope? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedValue = newValue
        }
    }
}

private func repositoryRootForIngest() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func decodedFixture(named name: String) throws -> Data {
    let fixture = repositoryRootForIngest()
        .appending(path: "Tests/Fixtures/Ingest")
        .appending(path: name)
    let encoded = try String(contentsOf: fixture, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return try #require(Data(base64Encoded: encoded))
}

@MainActor
private func makePDF(text: String) -> Data {
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
    view.string = text
    return view.dataWithPDF(inside: view.bounds)
}
