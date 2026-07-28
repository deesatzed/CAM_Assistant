import AppKit
import Foundation
import Testing
@testable import CAMAssistantCore

@Test("library presentation summarizes derived local documents by modality")
func libraryPresentationSummarizesDerivedLocalDocumentsByModality() {
    let documents = [
        DerivedDocument(sourceID: ContentID(rawValue: "a"), text: "One", modality: .text, extractorID: "test", capturedAt: .distantPast),
        DerivedDocument(sourceID: ContentID(rawValue: "b"), text: "Two", modality: .code, extractorID: "test", capturedAt: .distantPast),
    ]
    let presentation = LibraryPresentation(documents: documents)

    #expect(presentation.documentCount == 2)
    #expect(presentation.modalityCounts[.text] == 1)
    #expect(presentation.modalityCounts[.code] == 1)
}

@Test("library source detail preserves citation identity and every capture provenance")
func librarySourceDetailPreservesCitationIdentityAndCaptureProvenance() {
    let sourceID = ContentID(rawValue: "source-a")
    let capturedAt = Date(timeIntervalSince1970: 10)
    let document = DerivedDocument(
        sourceID: sourceID,
        text: "A local note explains the approval boundary.",
        modality: .markdown,
        extractorID: "markdown-v1",
        capturedAt: capturedAt
    )
    let provenance = [
        CaptureProvenance(
            captureID: UUID(),
            sourceID: sourceID,
            capturedAt: capturedAt,
            sourceName: "note.md",
            contentType: "text/markdown",
            origin: .watchedFolder(path: "/approved/notes")
        ),
        CaptureProvenance(
            captureID: UUID(),
            sourceID: sourceID,
            capturedAt: Date(timeIntervalSince1970: 20),
            sourceName: "Clipboard",
            contentType: "text/plain",
            origin: .clipboard
        ),
    ]

    let presentation = LibraryPresentation(
        documents: [document],
        provenanceBySource: [sourceID: provenance]
    )

    #expect(presentation.rows.count == 1)
    #expect(presentation.rows[0].id == "source-a")
    #expect(presentation.rows[0].passageID == "source-a#0")
    #expect(presentation.rows[0].preview == document.text)
    #expect(presentation.rows[0].modalityLabel == "Markdown")
    #expect(presentation.rows[0].extractorID == "markdown-v1")
    #expect(presentation.rows[0].captures.map(\.originLabel) == [
        "Watched folder: /approved/notes",
        "Clipboard",
    ])
    #expect(presentation.rows[0].captures.map(\.sourceName) == ["note.md", "Clipboard"])
    #expect(
        presentation.row(
            for: Citation(
                sourceID: "source-a",
                passageID: "source-a#0",
                quote: "approval boundary"
            )
        )?.id == "source-a"
    )
    #expect(
        presentation.row(
            for: Citation(
                sourceID: "missing",
                passageID: "missing#0",
                quote: "not local"
            )
        ) == nil
    )
}

@Test("library presentation separates hidden sources and resolves citations only to active sources")
func libraryPresentationSeparatesHiddenSourcesFromCitationNavigation() {
    let active = DerivedDocument(
        sourceID: ContentID(rawValue: "active-source"),
        text: "Active local evidence.",
        modality: .text,
        extractorID: "plain-text-v1",
        capturedAt: .distantPast
    )
    let hidden = DerivedDocument(
        sourceID: ContentID(rawValue: "hidden-source"),
        text: "Hidden local evidence.",
        modality: .markdown,
        extractorID: "markdown-v1",
        capturedAt: .distantPast
    )

    let presentation = LibraryPresentation(
        documents: [active],
        hiddenDocuments: [hidden],
        provenanceBySource: [:]
    )

    #expect(presentation.documentCount == 1)
    #expect(presentation.hiddenCount == 1)
    #expect(presentation.rows.map(\.id) == ["active-source"])
    #expect(presentation.hiddenRows.map(\.id) == ["hidden-source"])
    #expect(presentation.rows[0].lifecycle == .active)
    #expect(presentation.rows[0].lifecycleActionLabel == "Hide from Library & Chat")
    #expect(presentation.hiddenRows[0].lifecycle == .hidden)
    #expect(presentation.hiddenRows[0].lifecycleActionLabel == "Restore to Library & Chat")
    #expect(
        presentation.row(
            for: Citation(
                sourceID: "hidden-source",
                passageID: "hidden-source#0",
                quote: "Hidden local evidence."
            )
        ) == nil
    )
}

@MainActor
@Test("source lifecycle survives restart and never changes immutable bytes or provenance")
func sourceLifecycleSurvivesRestartWithoutChangingImmutableSource() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let payload = Data("Lifecycle evidence remains immutable.".utf8)
    let envelope = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 10),
        sourceName: "lifecycle.txt",
        contentType: "text/plain",
        data: payload,
        origin: .clipboard
    )
    let receipt = try harness.service.capture(envelope)
    _ = try harness.queue.processNext()
    let originalProvenance = try harness.queue.provenance(
        for: receipt.sourceID
    )

    try harness.queue.setLifecycle(.hidden, for: receipt.sourceID)

    #expect(try harness.queue.documents().isEmpty)
    #expect(
        try harness.queue.hiddenDocuments().map(\.sourceID)
            == [receipt.sourceID]
    )
    #expect(try harness.contentStore.data(for: receipt.sourceID) == payload)
    #expect(
        try harness.queue.provenance(for: receipt.sourceID)
            == originalProvenance
    )

    let restarted = try IngestQueue(
        databaseURL: harness.databaseURL,
        contentStore: harness.contentStore,
        extractors: .localDefaults
    )
    #expect(
        try restarted.lifecycle(for: receipt.sourceID) == .hidden
    )
    #expect(try restarted.documents().isEmpty)

    try restarted.setLifecycle(.active, for: receipt.sourceID)

    #expect(try restarted.documents().map(\.sourceID) == [receipt.sourceID])
    #expect(try harness.contentStore.data(for: receipt.sourceID) == payload)
    #expect(try harness.contentStore.objectCount() == 1)
}

@MainActor
@Test("raw source inspection verifies identity and bounds text even while hidden")
func rawSourceInspectionVerifiesAndBoundsHiddenText() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let payload = Data("Immutable local evidence for inspection.".utf8)
    let envelope = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 10),
        sourceName: "inspection.txt",
        contentType: "text/plain",
        data: payload,
        origin: .clipboard
    )
    let receipt = try harness.service.capture(envelope)
    try harness.queue.setLifecycle(.hidden, for: receipt.sourceID)

    let inspection = try harness.queue.inspectRawSource(
        for: receipt.sourceID,
        previewCharacterLimit: 15
    )

    #expect(inspection.sourceID == receipt.sourceID)
    #expect(inspection.verifiedSHA256 == receipt.sourceID.rawValue)
    #expect(inspection.byteCount == payload.count)
    #expect(inspection.sourceName == "inspection.txt")
    #expect(inspection.contentType == "text/plain")
    #expect(inspection.lifecycle == .hidden)
    #expect(inspection.previewAvailability == .text)
    #expect(inspection.preview == "Immutable local")
    #expect(inspection.isPreviewTruncated)
}

@MainActor
@Test("raw source inspection refuses to render binary bytes as text")
func rawSourceInspectionRefusesBinaryTextRendering() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let payload = Data([0x00, 0xff, 0x10, 0x80])
    let envelope = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 10),
        sourceName: "pixel.png",
        contentType: "image/png",
        data: payload,
        origin: .clipboard
    )
    let receipt = try harness.service.capture(envelope)

    let inspection = try harness.queue.inspectRawSource(
        for: receipt.sourceID,
        previewCharacterLimit: 100
    )

    #expect(inspection.byteCount == payload.count)
    #expect(inspection.previewAvailability == .binaryUnavailable)
    #expect(inspection.preview == nil)
    #expect(!inspection.isPreviewTruncated)
    #expect(try harness.contentStore.data(for: receipt.sourceID) == payload)
}

@MainActor
@Test("hidden sources leave local conversation context until explicitly restored")
func hiddenSourcesLeaveLocalConversationContextUntilRestored() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let envelope = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 10),
        sourceName: "context.txt",
        contentType: "text/plain",
        data: Data("The lifecycle phrase is locally searchable.".utf8),
        origin: .clipboard
    )
    let receipt = try harness.service.capture(envelope)
    _ = try harness.queue.processNext()
    let provider = LocalConversationContextProvider(
        databaseURL: harness.databaseURL
    )

    #expect(
        try provider.context(for: "lifecycle phrase").passages
            .map(\.sourceID) == [receipt.sourceID.rawValue]
    )

    try harness.queue.setLifecycle(.hidden, for: receipt.sourceID)
    #expect(
        try provider.context(for: "lifecycle phrase").passages.isEmpty
    )

    try harness.queue.setLifecycle(.active, for: receipt.sourceID)
    #expect(
        try provider.context(for: "lifecycle phrase").passages
            .map(\.sourceID) == [receipt.sourceID.rawValue]
    )
}

@MainActor
@Test("database conversation context uses the persistent retrieval generation")
func databaseConversationContextUsesPersistentRetrievalGeneration() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let envelope = CaptureEnvelope(
        id: UUID(),
        capturedAt: Date(timeIntervalSince1970: 10),
        sourceName: "grounding.txt",
        contentType: "text/plain",
        data: Data(
            "CAM Assistant keeps raw vault material and secrets local.".utf8
        ),
        origin: .clipboard
    )
    let receipt = try harness.service.capture(envelope)
    _ = try harness.queue.processNext()

    let context = try LocalConversationContextProvider(
        databaseURL: harness.databaseURL
    ).context(
        for: "Does CAM Assistant keep raw vault material and secrets local?"
    )

    #expect(context.passages.map(\.sourceID) == [receipt.sourceID.rawValue])
    #expect(
        FileManager.default.fileExists(
            atPath: harness.root
                .appending(path: "retrieval-index")
                .appending(path: "active-generation.json")
                .path
        )
    )
}

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

@Test("ingest activity lists persisted jobs without source bytes")
func ingestActivityListsPersistedJobs() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let receipt = try harness.service.capture(
        ClipboardCapture.envelope(
            text: "activity metadata only",
            capturedAt: Date(timeIntervalSince1970: 10)
        )
    )

    let job = try #require(try harness.queue.jobs().first)

    #expect(job.sourceID == receipt.sourceID)
    #expect(job.status == .pending)
    #expect(job.sourceName == "Clipboard.txt")
    #expect(job.contentType == "text/plain")
    #expect(job.attempts == 0)
}

@Test("explicit ingest cancellation prevents pending processing")
func explicitIngestCancellationPreventsPendingProcessing() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let receipt = try harness.service.capture(
        ClipboardCapture.envelope(
            text: "cancel before extraction",
            capturedAt: Date(timeIntervalSince1970: 11)
        )
    )

    try harness.queue.cancel(receipt.sourceID)

    #expect(try harness.queue.jobStatus(for: receipt.sourceID) == .cancelled)
    #expect(try harness.queue.processNext() == nil)
    #expect(
        try harness.contentStore.data(for: receipt.sourceID)
            == Data("cancel before extraction".utf8)
    )
}

@Test("resume processes the exact cancelled ingest job")
func resumeProcessesExactCancelledIngestJob() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let first = try harness.service.capture(
        ClipboardCapture.envelope(
            text: "first remains pending",
            capturedAt: Date(timeIntervalSince1970: 12)
        )
    )
    let second = try harness.service.capture(
        ClipboardCapture.envelope(
            text: "second resumes directly",
            capturedAt: Date(timeIntervalSince1970: 13)
        )
    )
    try harness.queue.cancel(second.sourceID)

    let resumed = try harness.queue.resume(second.sourceID)

    #expect(resumed.status == .completed)
    #expect(resumed.sourceID == second.sourceID)
    #expect(try harness.queue.jobStatus(for: first.sourceID) == .pending)
    #expect(try harness.queue.jobStatus(for: second.sourceID) == .completed)
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

@Test("completed ingestion builds a restart-safe derived retrieval generation")
func completedIngestionBuildsDerivedRetrievalGeneration() throws {
    let harness = try IngestHarness()
    defer { harness.remove() }
    let envelope = ClipboardCapture.envelope(
        text: "A completed capture can be searched through a derived generation.",
        capturedAt: Date(timeIntervalSince1970: 10)
    )
    let receipt = try harness.service.capture(envelope)
    _ = try harness.queue.processAll()
    let builder = try RetrievalIndexBuilder(
        rootDirectory: harness.root.appending(path: "retrieval-index"),
        baseFingerprint: IndexFingerprint(
            schemaVersion: 1,
            sourceManifestHash: "pending",
            tokenizer: "unicode61",
            preprocessing: "lowercase-stopwords-v1",
            chunking: "words-200-v1",
            semanticProvider: "none",
            semanticModel: "none",
            semanticDimensions: 0,
            fusionVersion: "hybrid-v1"
        )
    )

    _ = try builder.rebuild(documents: harness.queue.documents())
    let index = try builder.openActive()
    let results = try index.search("completed capture searched", limit: 10)
    try index.close()

    #expect(results.first?.sourceID == receipt.sourceID.rawValue)
    #expect(try harness.contentStore.data(for: receipt.sourceID) == envelope.data)
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

@Test("watched source configuration persists independent source states")
func watchedSourceConfigurationPersistsIndependentSourceStates() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-watched-source-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let storeURL = root.appending(path: "watched-sources.json")
    let first = try WatchedSource(path: "/tmp/cam-first", isEnabled: true)
    let second = try WatchedSource(path: "/tmp/cam-second", isEnabled: false)

    try WatchedSourceConfigurationStore(url: storeURL).save([first, second])
    let restored = try WatchedSourceConfigurationStore(url: storeURL).load()

    #expect(restored == [first, second])
    #expect(restored[0].isEnabled)
    #expect(!restored[1].isEnabled)
}

@Test("watched source configuration rejects duplicate canonical paths")
func watchedSourceConfigurationRejectsDuplicateCanonicalPaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-watched-source-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let duplicate = try WatchedSource(path: "/tmp/cam-duplicate", isEnabled: false)
    let samePath = try WatchedSource(path: "/tmp/cam-duplicate", isEnabled: true)

    #expect(throws: WatchedSourceConfigurationError.duplicatePath("/tmp/cam-duplicate")) {
        try WatchedSourceConfigurationStore(url: root.appending(path: "watched-sources.json"))
            .save([duplicate, samePath])
    }
}

@Test("watched source configuration rejects duplicate source identifiers")
func watchedSourceConfigurationRejectsDuplicateSourceIdentifiers() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-watched-source-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID()
    let first = try WatchedSource(id: id, path: "/tmp/cam-first", isEnabled: false)
    let second = try WatchedSource(id: id, path: "/tmp/cam-second", isEnabled: false)

    #expect(throws: WatchedSourceConfigurationError.duplicateID(id)) {
        try WatchedSourceConfigurationStore(url: root.appending(path: "watched-sources.json"))
            .save([first, second])
    }
}

@Test("watched source manager starts enabled sources and stops paused sources")
func watchedSourceManagerStartsEnabledSourcesAndStopsPausedSources() throws {
    let enabled = try WatchedSource(path: "/tmp/cam-enabled", isEnabled: true)
    let paused = try WatchedSource(path: "/tmp/cam-paused", isEnabled: false)
    let factory = TestWatchedSourceFactory()
    let manager = WatchedSourceManager(makeWatcher: factory.make, capture: { _ in })

    try manager.reconcile([enabled, paused])

    #expect(factory.watcher(for: enabled.id)?.started == true)
    #expect(factory.watcher(for: paused.id) == nil)

    var pausedEnabled = paused
    pausedEnabled.isEnabled = true
    try manager.reconcile([enabled, pausedEnabled])
    try manager.reconcile([enabled])

    #expect(factory.watcher(for: enabled.id)?.stopped == false)
    #expect(factory.watcher(for: paused.id)?.stopped == true)
}

@Test("watched source manager forwards only watcher envelopes to local capture")
func watchedSourceManagerForwardsWatcherEnvelopesToLocalCapture() throws {
    let source = try WatchedSource(path: "/tmp/cam-capture", isEnabled: true)
    let factory = TestWatchedSourceFactory()
    let captured = CaptureEnvelopeBox()
    let manager = WatchedSourceManager(makeWatcher: factory.make) { envelope in
        captured.value = envelope
    }
    let envelope = CaptureEnvelope(
        sourceName: "note.md",
        contentType: "text/markdown",
        data: Data("# local".utf8),
        origin: .watchedFolder(path: "/tmp/cam-capture/note.md")
    )

    try manager.reconcile([source])
    factory.watcher(for: source.id)?.emit([envelope])

    #expect(captured.value == envelope)
}

@Test("watched source manager records a start failure without stopping other sources")
func watchedSourceManagerRecordsStartFailureWithoutStoppingOtherSources() throws {
    let working = try WatchedSource(path: "/tmp/cam-working", isEnabled: true)
    let failing = try WatchedSource(path: "/tmp/cam-failing", isEnabled: true)
    let factory = TestWatchedSourceFactory(failingIDs: [failing.id])
    let manager = WatchedSourceManager(makeWatcher: factory.make, capture: { _ in })

    try manager.reconcile([working, failing])

    #expect(manager.runtimeState(for: working.id) == .running)
    #expect(manager.runtimeState(for: failing.id) == .failed)
    #expect(factory.watcher(for: working.id)?.stopped == false)
}

@Test("watched source presentation distinguishes configured runtime states")
func watchedSourcePresentationDistinguishesConfiguredRuntimeStates() throws {
    let source = try WatchedSource(path: "/tmp/cam-presentation", isEnabled: true)

    #expect(WatchedSourcePresentation(source: source, runtimeState: .running).statusLabel == "Watching locally")
    #expect(WatchedSourcePresentation(source: source, runtimeState: .failed).statusLabel == "Could not start local watcher")
    #expect(WatchedSourcePresentation(source: source, runtimeState: .paused).statusLabel == "Paused")
}

@Test("watched source service persists controls and reconciles local lifecycle")
func watchedSourceServicePersistsControlsAndReconcilesLocalLifecycle() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-watched-source-tests")
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let factory = TestWatchedSourceFactory()
    let service = WatchedSourceService(
        store: WatchedSourceConfigurationStore(url: root.appending(path: "watched-sources.json")),
        manager: WatchedSourceManager(makeWatcher: factory.make, capture: { _ in })
    )

    let source = try service.add(path: "/tmp/cam-service")
    #expect(service.presentations().map(\.statusLabel) == ["Paused"])

    try service.setEnabled(true, for: source.id)
    #expect(service.presentations().map(\.statusLabel) == ["Watching locally"])

    try service.remove(source.id)
    #expect(service.presentations().isEmpty)
    #expect(factory.watcher(for: source.id)?.stopped == true)
    #expect(try WatchedSourceConfigurationStore(url: root.appending(path: "watched-sources.json")).load().isEmpty)
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

private final class TestWatchedSourceFactory: @unchecked Sendable {
    private var watchers: [UUID: TestWatchedSourceWatcher] = [:]
    private let failingIDs: Set<UUID>

    init(failingIDs: Set<UUID> = []) {
        self.failingIDs = failingIDs
    }

    func make(_ source: WatchedSource) -> any WatchedSourceWatching {
        let watcher = TestWatchedSourceWatcher(shouldFailOnStart: failingIDs.contains(source.id))
        watchers[source.id] = watcher
        return watcher
    }

    func watcher(for id: UUID) -> TestWatchedSourceWatcher? {
        watchers[id]
    }
}

private final class TestWatchedSourceWatcher: WatchedSourceWatching, @unchecked Sendable {
    private(set) var started = false
    private(set) var stopped = false
    private var handler: (@Sendable ([CaptureEnvelope]) -> Void)?
    private let shouldFailOnStart: Bool

    init(shouldFailOnStart: Bool = false) {
        self.shouldFailOnStart = shouldFailOnStart
    }

    func start(handler: @escaping @Sendable ([CaptureEnvelope]) -> Void) throws {
        if shouldFailOnStart { throw TestWatchedSourceWatcherError.startFailed }
        started = true
        self.handler = handler
    }

    func stop() {
        stopped = true
    }

    func emit(_ envelopes: [CaptureEnvelope]) {
        handler?(envelopes)
    }
}

private enum TestWatchedSourceWatcherError: Error {
    case startFailed
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
