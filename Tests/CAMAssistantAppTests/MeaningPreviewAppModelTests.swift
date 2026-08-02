import Foundation
import Testing
@testable import CAMAssistantCore
@testable import CAMAssistantApp

@MainActor
@Test("AppModel hides disabled Preview and enablement grants no local access")
func meaningPreviewAppModelOptInIsSeparateFromGrant() async {
    let runtime = MeaningPreviewRuntimeSpy(initialLifecycle: .disabled)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )

    #expect(!model.isMeaningPreviewVisible)
    #expect(await runtime.requestCount == 0)
    await model.enableMeaningPreview()
    #expect(model.isMeaningPreviewVisible)
    #expect(model.meaningPreviewLifecycle == .enabledWithoutLocalRead)
    #expect(!model.canRequestMeaningPreview)
    #expect(await runtime.requestCount == 0)
}

@MainActor
@Test("Meaning Preview ignores duplicate lifecycle activation while one is in flight")
func meaningPreviewAppModelIgnoresDuplicateLifecycleActivation() async {
    let gate = AsyncMeaningPreviewGate()
    let runtime = GatedEnableMeaningPreviewRuntime(gate: gate)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )

    let first = Task { @MainActor in await model.enableMeaningPreview() }
    await gate.waitUntilEntered()
    let duplicate = Task { @MainActor in await model.enableMeaningPreview() }
    await Task.yield()

    #expect(await runtime.enableCount == 1)
    await gate.release()
    await first.value
    await duplicate.value
    #expect(!model.isMeaningPreviewWorking)
    #expect(model.meaningPreviewLifecycle == .enabledWithoutLocalRead)
}

@MainActor
@Test("AppModel requires grant and explicit source before requesting one card")
func meaningPreviewAppModelRequiresGrantAndSelection() async {
    let runtime = MeaningPreviewRuntimeSpy(initialLifecycle: .disabled)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    await model.enableMeaningPreview()
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewError == "Grant local read and isolated write access before requesting a Preview.")
    await model.grantMeaningPreviewLocalRead()
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewError == "Select one active local source for this Preview.")

    model.selectMeaningPreviewSource(
        id: "source-1"
    )
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewPresentation?.card?.text == "Prepare the bounded outline.")
    #expect(model.meaningPreviewPresentation?.inspect.provenanceLabel
        == "Selected CAM-derived local context")
    #expect(model.meaningPreviewPresentation?.inspect.uncertaintyLabel == "Supported")
    #expect(await runtime.requestCount == 1)
}

@MainActor
@Test("AppModel clears terminal card state and Disable restores Assistant")
func meaningPreviewAppModelTerminalActionsAndDisable() async {
    let runtime = MeaningPreviewRuntimeSpy(initialLifecycle: .ready)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.selectMeaningPreviewSource(
        id: "source-1"
    )
    await model.requestMeaningPreview()
    await model.applyMeaningPreviewAction(.later)
    #expect(model.meaningPreviewPresentation == nil)
    #expect(model.meaningPreviewStatus?.hasPrefix("Later recorded") == true)

    await model.requestMeaningPreview()
    await model.recordMeaningPreviewFeedback(.helpful)
    #expect(model.meaningPreviewPresentation == nil)
    #expect(model.meaningPreviewStatus?.hasPrefix("Helpful recorded") == true)

    await model.disableMeaningPreview()
    #expect(model.selection == .assistant)
    #expect(!model.isMeaningPreviewVisible)
    #expect(model.meaningPreviewSelectedSource == nil)
    #expect(await runtime.disableCount == 1)
}

@MainActor
@Test("Disable wins over in-flight request, action, and feedback completions")
func meaningPreviewAppModelDisableInvalidatesAllInFlightOperations() async {
    for gatedOperation in MeaningPreviewGatedOperation.allCases {
        let gate = AsyncMeaningPreviewGate()
        let runtime = GatedMeaningPreviewRuntime(
            gatedOperation: gatedOperation,
            gate: gate
        )
        let model = AppModel(
            initializeFullWorkspace: false,
            meaningPreviewRuntime: runtime
        )
        model.selectMeaningPreviewSource(id: "source-1")
        if gatedOperation != .request {
            await model.requestMeaningPreview()
            #expect(model.meaningPreviewPresentation?.card != nil)
        }

        let operation = Task { @MainActor in
            switch gatedOperation {
            case .request:
                await model.requestMeaningPreview()
            case .action:
                await model.applyMeaningPreviewAction(.later)
            case .feedback:
                await model.recordMeaningPreviewFeedback(.helpful)
            }
        }
        await gate.waitUntilEntered()
        await model.disableMeaningPreview()
        await gate.release()
        await operation.value

        #expect(model.meaningPreviewLifecycle == .disabled)
        #expect(model.meaningPreviewPresentation == nil)
        #expect(model.meaningPreviewSelectedSource == nil)
        #expect(model.meaningPreviewStatus
            == "Meaning Preview disabled. Ordinary Assistant is unchanged.")
        #expect(model.meaningPreviewError == nil)
        #expect(!model.isMeaningPreviewWorking)
    }
}

@MainActor
@Test("selecting a new source invalidates an old in-flight request")
func meaningPreviewAppModelSourceSelectionInvalidatesOldRequest() async {
    let gate = AsyncMeaningPreviewGate()
    let runtime = GatedMeaningPreviewRuntime(
        gatedOperation: .request,
        gate: gate
    )
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.selectMeaningPreviewSource(id: "old-source")
    let request = Task { @MainActor in await model.requestMeaningPreview() }
    await gate.waitUntilEntered()
    model.selectMeaningPreviewSource(id: "new-source")
    await gate.release()
    await request.value

    #expect(model.meaningPreviewSelectedSource == .init(id: "new-source"))
    #expect(model.meaningPreviewPresentation == nil)
    #expect(model.meaningPreviewStatus
        == "Selected one active CAM-derived local source.")
    #expect(!model.isMeaningPreviewWorking)
}

@MainActor
@Test("recovery clears the Preview session and restores Assistant when disabled")
func meaningPreviewAppModelRecoveryNormalizesDisabledNavigation() async {
    let runtime = MeaningPreviewRuntimeSpy(
        initialLifecycle: .ready,
        recoveryReceipt: .init(
            lifecycle: .disabled,
            archivedPreviousState: true
        )
    )
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.selection = .meaningPreview
    model.selectMeaningPreviewSource(id: "source-1")
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewPresentation != nil)

    await model.recoverMeaningPreview()
    #expect(model.meaningPreviewLifecycle == .disabled)
    #expect(model.selection == .assistant)
    #expect(model.meaningPreviewPresentation == nil)
    #expect(model.meaningPreviewSelectedSource == nil)
    #expect(model.meaningPreviewStatus
        == "Meaning Preview isolated state was archived and reinitialized.")
}

@MainActor
@Test("AppModel reflection requires two to eight explicit sources and preserves practical lane")
func meaningPreviewAppModelReflectionIsExplicitAndBounded() async {
    let runtime = ReflectiveMeaningPreviewRuntimeSpy()
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.selectMeaningPreviewSource(id: "source-a")
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewPresentation?.card != nil)

    model.toggleMeaningPreviewReflectiveSource(id: "source-a")
    #expect(!model.canRequestMeaningPreviewReflection)
    await model.requestMeaningPreviewReflection()
    #expect(await runtime.reflectionRequestCount == 0)
    #expect(model.meaningPreviewReflectionStatus
        == "Select at least two and at most eight current sources for reflection.")

    model.toggleMeaningPreviewReflectiveSource(id: "source-b")
    #expect(model.canRequestMeaningPreviewReflection)
    await model.requestMeaningPreviewReflection()
    #expect(await runtime.reflectionRequestCount == 1)
    #expect(await runtime.lastReferences == ["source-a", "source-b"])
    #expect(model.meaningPreviewReflection?.text
        == "The outline may be ready if the schedule permits.")
    #expect(model.meaningPreviewPresentation?.card != nil)
    #expect(model.meaningPreviewReflection?.retention == .ephemeral)

    for index in 0..<7 {
        model.toggleMeaningPreviewReflectiveSource(id: "extra-\(index)")
    }
    #expect(model.meaningPreviewReflectiveSourceIDs.count == 8)
    #expect(model.meaningPreviewReflectionError
        == "Reflection accepts at most eight explicitly selected sources.")
}

@MainActor
@Test("reflection failure disables only reflection and practical Preview remains available")
func meaningPreviewAppModelReflectionFailureIsIsolated() async {
    let runtime = ReflectiveMeaningPreviewRuntimeSpy(shouldFailReflection: true)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.toggleMeaningPreviewReflectiveSource(id: "source-a")
    model.toggleMeaningPreviewReflectiveSource(id: "source-b")

    await model.requestMeaningPreviewReflection()

    #expect(!model.isMeaningPreviewReflectionAvailable)
    #expect(!model.canRequestMeaningPreviewReflection)
    #expect(model.meaningPreviewReflection == nil)
    #expect(model.meaningPreviewReflectionError
        == "Selected local reflection is unavailable. No fallback occurred; practical Preview remains available.")
    model.selectMeaningPreviewSource(id: "source-a")
    await model.requestMeaningPreview()
    #expect(model.meaningPreviewPresentation?.card != nil)
}

@MainActor
@Test("selection change cancels and invalidates in-flight reflection")
func meaningPreviewAppModelCancelsStaleReflection() async {
    let gate = AsyncMeaningPreviewGate()
    let runtime = ReflectiveMeaningPreviewRuntimeSpy(reflectionGate: gate)
    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )
    model.toggleMeaningPreviewReflectiveSource(id: "source-a")
    model.toggleMeaningPreviewReflectiveSource(id: "source-b")
    let request = Task { @MainActor in
        await model.requestMeaningPreviewReflection()
    }
    await gate.waitUntilEntered()
    model.toggleMeaningPreviewReflectiveSource(id: "source-c")
    await gate.release()
    await request.value

    #expect(model.meaningPreviewReflection == nil)
    #expect(model.meaningPreviewReflectionStatus
        == "Selected 3 current sources for explicit reflection.")
    #expect(!model.isMeaningPreviewReflecting)
}

private actor MeaningPreviewRuntimeSpy: MeaningPreviewRuntime {
    nonisolated let initialLifecycle: MeaningPreviewLifecycle
    private var lifecycle: MeaningPreviewLifecycle
    private(set) var requestCount = 0
    private(set) var disableCount = 0
    private var version: UInt64 = 0
    private let recoveryReceipt: MeaningPreviewRecoveryReceipt?

    init(
        initialLifecycle: MeaningPreviewLifecycle,
        recoveryReceipt: MeaningPreviewRecoveryReceipt? = nil
    ) {
        self.initialLifecycle = initialLifecycle
        lifecycle = initialLifecycle
        self.recoveryReceipt = recoveryReceipt
    }

    func loadLifecycle() -> MeaningPreviewLifecycle { lifecycle }
    func enable() -> MeaningPreviewLifecycle {
        lifecycle = .enabledWithoutLocalRead
        return lifecycle
    }
    func grantLocalAccess() -> MeaningPreviewLifecycle {
        lifecycle = .ready
        return lifecycle
    }
    func disable() -> MeaningPreviewLifecycle {
        disableCount += 1
        lifecycle = .disabled
        return lifecycle
    }
    func recover() -> MeaningPreviewRecoveryReceipt {
        recoveryReceipt
            ?? .init(lifecycle: lifecycle, archivedPreviousState: true)
    }
    func request(
        reference: MeaningPreviewSourceReference,
        now: Date
    ) async throws -> MeaningPreviewAppPresentation {
        requestCount += 1
        version += 1
        return .appFixture(
            version: version,
            text: "Prepare the bounded outline."
        )
    }
    func applyAction(
        _ action: MeaningPreviewCardAction,
        memoryID: UUID,
        expectedVersion: UInt64,
        at: Date
    ) -> UInt64 {
        version += 1
        return version
    }
    func recordFeedback(
        _ feedback: MeaningPreviewFeedback,
        memoryID: UUID,
        domain: String,
        expectedVersion: UInt64
    ) -> UInt64 {
        version += 1
        return version
    }
}

private actor ReflectiveMeaningPreviewRuntimeSpy:
    MeaningPreviewRuntime, MeaningPreviewReflectiveRuntime {
    nonisolated let initialLifecycle: MeaningPreviewLifecycle = .ready
    nonisolated let reflectionInitiallyAvailable = true
    private(set) var reflectionRequestCount = 0
    private(set) var lastReferences: [String] = []
    private var version: UInt64 = 0
    private var lifecycle: MeaningPreviewLifecycle = .ready
    private let shouldFailReflection: Bool
    private let reflectionGate: AsyncMeaningPreviewGate?

    init(
        shouldFailReflection: Bool = false,
        reflectionGate: AsyncMeaningPreviewGate? = nil
    ) {
        self.shouldFailReflection = shouldFailReflection
        self.reflectionGate = reflectionGate
    }

    func loadLifecycle() -> MeaningPreviewLifecycle { lifecycle }
    func enable() -> MeaningPreviewLifecycle { lifecycle }
    func grantLocalAccess() -> MeaningPreviewLifecycle { lifecycle }
    func disable() -> MeaningPreviewLifecycle {
        lifecycle = .disabled
        return lifecycle
    }
    func recover() -> MeaningPreviewRecoveryReceipt {
        .init(lifecycle: lifecycle, archivedPreviousState: false)
    }
    func request(reference: MeaningPreviewSourceReference, now: Date) async throws
        -> MeaningPreviewAppPresentation {
        version += 1
        return .appFixture(version: version, text: "Prepare the bounded outline.")
    }
    func applyAction(
        _ action: MeaningPreviewCardAction, memoryID: UUID,
        expectedVersion: UInt64, at: Date
    ) async throws -> UInt64 { expectedVersion + 1 }
    func recordFeedback(
        _ feedback: MeaningPreviewFeedback, memoryID: UUID, domain: String,
        expectedVersion: UInt64
    ) async throws -> UInt64 { expectedVersion + 1 }

    func requestReflection(
        references: [MeaningPreviewSourceReference], now: Date
    ) async throws -> MeaningPreviewReflectivePresentation? {
        reflectionRequestCount += 1
        lastReferences = references.map(\.id)
        if let reflectionGate { await reflectionGate.enter() }
        try Task.checkCancellation()
        if shouldFailReflection {
            throw MeaningPreviewLoopbackSupplierError.transportUnavailable
        }
        return MeaningPreviewReflectivePresentation(
            text: "The outline may be ready if the schedule permits.",
            observation: "The outline is named.",
            interpretation: "The schedule may limit it.",
            supportIDs: ["source-a"],
            counterevidenceIDs: ["source-b"],
            uncertainty: 0.4,
            runtimeIdentity: "loopback:test",
            modelID: "local/meaning",
            retention: .ephemeral
        )
    }
}

private enum MeaningPreviewGatedOperation: CaseIterable, Sendable {
    case request
    case action
    case feedback
}

private actor AsyncMeaningPreviewGate {
    private var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    func enter() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilEntered() async {
        while !entered { await Task.yield() }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private actor GatedEnableMeaningPreviewRuntime: MeaningPreviewRuntime {
    nonisolated let initialLifecycle: MeaningPreviewLifecycle = .disabled
    private var lifecycle: MeaningPreviewLifecycle = .disabled
    private let gate: AsyncMeaningPreviewGate
    private(set) var enableCount = 0

    init(gate: AsyncMeaningPreviewGate) {
        self.gate = gate
    }

    func loadLifecycle() -> MeaningPreviewLifecycle { lifecycle }

    func enable() async throws -> MeaningPreviewLifecycle {
        enableCount += 1
        await gate.enter()
        lifecycle = .enabledWithoutLocalRead
        return lifecycle
    }

    func grantLocalAccess() async throws -> MeaningPreviewLifecycle {
        lifecycle = .ready
        return lifecycle
    }

    func disable() async throws -> MeaningPreviewLifecycle {
        lifecycle = .disabled
        return lifecycle
    }

    func recover() async throws -> MeaningPreviewRecoveryReceipt {
        .init(lifecycle: lifecycle, archivedPreviousState: false)
    }

    func request(
        reference: MeaningPreviewSourceReference,
        now: Date
    ) async throws -> MeaningPreviewAppPresentation {
        throw MeaningPreviewRuntimeError.accessDenied
    }

    func applyAction(
        _ action: MeaningPreviewCardAction,
        memoryID: UUID,
        expectedVersion: UInt64,
        at: Date
    ) async throws -> UInt64 {
        throw MeaningPreviewRuntimeError.accessDenied
    }

    func recordFeedback(
        _ feedback: MeaningPreviewFeedback,
        memoryID: UUID,
        domain: String,
        expectedVersion: UInt64
    ) async throws -> UInt64 {
        throw MeaningPreviewRuntimeError.accessDenied
    }
}

private actor GatedMeaningPreviewRuntime: MeaningPreviewRuntime {
    nonisolated let initialLifecycle: MeaningPreviewLifecycle = .ready
    private var lifecycle: MeaningPreviewLifecycle = .ready
    private let gatedOperation: MeaningPreviewGatedOperation
    private let gate: AsyncMeaningPreviewGate
    private var version: UInt64 = 0

    init(
        gatedOperation: MeaningPreviewGatedOperation,
        gate: AsyncMeaningPreviewGate
    ) {
        self.gatedOperation = gatedOperation
        self.gate = gate
    }

    func loadLifecycle() -> MeaningPreviewLifecycle { lifecycle }
    func enable() -> MeaningPreviewLifecycle { lifecycle }
    func grantLocalAccess() -> MeaningPreviewLifecycle { lifecycle }
    func disable() -> MeaningPreviewLifecycle {
        lifecycle = .disabled
        return lifecycle
    }
    func recover() -> MeaningPreviewRecoveryReceipt {
        .init(lifecycle: lifecycle, archivedPreviousState: true)
    }

    func request(
        reference: MeaningPreviewSourceReference,
        now: Date
    ) async throws -> MeaningPreviewAppPresentation {
        if gatedOperation == .request { await gate.enter() }
        version += 1
        return .appFixture(version: version, text: "Old source result")
    }

    func applyAction(
        _ action: MeaningPreviewCardAction,
        memoryID: UUID,
        expectedVersion: UInt64,
        at: Date
    ) async throws -> UInt64 {
        if gatedOperation == .action { await gate.enter() }
        version += 1
        return version
    }

    func recordFeedback(
        _ feedback: MeaningPreviewFeedback,
        memoryID: UUID,
        domain: String,
        expectedVersion: UInt64
    ) async throws -> UInt64 {
        if gatedOperation == .feedback { await gate.enter() }
        version += 1
        return version
    }
}

private extension MeaningPreviewAppPresentation {
    static func appFixture(version: UInt64, text: String) -> Self {
        .init(
            version: version,
            domain: "selected local source",
            card: .init(
                id: UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!,
                text: text
            ),
            inspect: .init(
                summary: "Bounded practical Preview.",
                evidenceIDs: ["evidence-1"],
                counterevidenceIDs: [],
                provenanceLabel: "Selected CAM-derived local context",
                uncertaintyLabel: "Supported",
                whySurfaced: "Active and relevant to the selected context."
            )
        )
    }
}

@Test("live runtime refuses disabled and ungranted requests before reading context")
func liveMeaningPreviewRuntimeRefusesBeforeRead() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let reads = ReadCounter()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: reads
    )

    #expect(runtime.initialLifecycle == .disabled)
    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        )
    }
    #expect(await reads.count == 0)
    #expect(!fixture.previewDatabaseExists)

    #expect(try await runtime.enable() == .enabledWithoutLocalRead)
    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        )
    }
    #expect(await reads.count == 0)
    #expect(!fixture.previewDatabaseExists)
}

@Test("live source resolver selects the exact active ID and bounds derived context")
func meaningPreviewLiveSourceResolverUsesExactBoundedDerivedDocument() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let queue = try IngestQueue(
        databaseURL: fixture.root.appending(path: "vault.sqlite"),
        contentStore: try ContentStore(
            rootDirectory: fixture.root.appending(path: "content")
        ),
        extractors: .localDefaults
    )
    let decoy = try queue.enqueue(
        CaptureEnvelope(
            sourceName: "decoy.txt",
            contentType: "text/plain",
            data: Data("DECOY-CONTEXT-MUST-NOT-APPEAR".utf8),
            origin: .clipboard
        )
    )
    let selectedText = "Selected bounded context. "
        + String(repeating: "x", count: 5_000)
    let selected = try queue.enqueue(
        CaptureEnvelope(
            sourceName: "selected.txt",
            contentType: "text/plain",
            data: Data(selectedText.utf8),
            origin: .clipboard
        )
    )
    _ = try queue.process(sourceID: decoy.sourceID)
    _ = try queue.process(sourceID: selected.sourceID)
    try queue.close()

    let resolved = try await MeaningPreviewLiveSourceResolver(root: fixture.root)
        .resolve(.init(id: selected.sourceID.rawValue))
    #expect(resolved.id == selected.sourceID.rawValue)
    #expect(resolved.derivedText.hasPrefix("Selected bounded context."))
    #expect(!resolved.derivedText.contains("DECOY-CONTEXT-MUST-NOT-APPEAR"))
    #expect(resolved.derivedText.count
        == MeaningPreviewLiveSourceResolver.maximumDerivedContextCharacters)
}

@Test("runtime rejects a resolver result for any ID other than the selected reference")
func liveMeaningPreviewRuntimeRejectsResolverIdentitySubstitution() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(
            context: .fixture(id: "different-source")
        )
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()

    await #expect(throws: MeaningPreviewRuntimeError.sourceUnavailable) {
        _ = try await runtime.request(
            reference: .init(id: "selected-source"),
            now: .fixtureNow
        )
    }
    #expect(!fixture.previewDatabaseExists)
}

@Test("disabled lifecycle reads create or rewrite no module state")
func liveMeaningPreviewRuntimeLifecycleReadIsSideEffectFree() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let stateURL = LocalVaultPaths.stateURL(.moduleState, vaultRoot: fixture.root)

    _ = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: ReadCounter()
    )
    #expect(!FileManager.default.fileExists(atPath: stateURL.path))

    let registry = try ModuleRegistry(
        manifestDirectory: fixture.manifests,
        stateURL: stateURL
    )
    try registry.disable("cam.meaning-preview")
    let before = try Data(contentsOf: stateURL)
    let beforeDate = try #require(
        FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate]
            as? Date
    )
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: ReadCounter()
    )
    #expect(runtime.initialLifecycle == .disabled)
    #expect(await runtime.loadLifecycle() == .disabled)
    #expect(try Data(contentsOf: stateURL) == before)
    #expect(
        try FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate]
            as? Date == beforeDate
    )
}

@Test("malformed module state is unavailable and remains byte-for-byte unchanged")
func liveMeaningPreviewRuntimeMalformedStateIsReadOnlyUnavailable() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let stateURL = LocalVaultPaths.stateURL(.moduleState, vaultRoot: fixture.root)
    try FileManager.default.createDirectory(
        at: stateURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let malformed = Data("{not-json".utf8)
    try malformed.write(to: stateURL)
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: ReadCounter()
    )

    #expect(runtime.initialLifecycle == .unavailable)
    #expect(await runtime.loadLifecycle() == .unavailable)
    #expect(try Data(contentsOf: stateURL) == malformed)
}

@Test("read-only or write-only grants never authorize source resolution")
func liveMeaningPreviewRuntimeRequiresBothManifestPermissions() async throws {
    for permission in [Permission.readLocal, .writeLocal] {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let stateURL = LocalVaultPaths.stateURL(.moduleState, vaultRoot: fixture.root)
        let registry = try ModuleRegistry(
            manifestDirectory: fixture.manifests,
            stateURL: stateURL
        )
        try registry.enable("cam.meaning-preview")
        try registry.grant([permission], to: "cam.meaning-preview")
        let reads = ReadCounter()
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: fixture.manifests,
            sourceResolver: reads
        )

        #expect(runtime.initialLifecycle == .enabledWithoutLocalRead)
        await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
            _ = try await runtime.request(
                reference: .init(id: "selected"),
                now: .fixtureNow
            )
        }
        #expect(await reads.count == 0)
        #expect(!fixture.previewDatabaseExists)
    }
}

@Test("live runtime keeps one coordinator from request through explicit feedback")
func liveMeaningPreviewRuntimePersistsFeedbackAndAudit() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )
    _ = try await runtime.enable()
    #expect(try await runtime.grantLocalAccess() == .ready)

    var feedbackDomain: String?
    for _ in 0..<2 {
        let presentation = try await runtime.request(
            reference: .init(id: "helpful-source"),
            now: .fixtureNow
        )
        let card = try #require(presentation.card)
        let domain = try #require(presentation.domain)
        feedbackDomain = domain
        _ = try await runtime.recordFeedback(
            .helpful,
            memoryID: card.id,
            domain: domain,
            expectedVersion: presentation.version
        )
    }

    let snapshot = try MeaningPreviewStore(
        databaseURL: LocalVaultPaths.meaningPreviewDatabaseURL(
            vaultRoot: fixture.root
        )
    ).load()
    #expect(snapshot.coreState.familiarity.stage(for: try #require(feedbackDomain))
        == .familiarAssistant)
    let audit = try AuditStore(databaseURL: fixture.root.appending(path: "vault.sqlite"))
    let events = try audit.events()
    try audit.close()
    #expect(events.contains { $0.route == "helpful" })
}

@Test("feedback familiarity is scoped to the exact selected source")
func liveMeaningPreviewRuntimeScopesFeedbackBySource() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    var domains: [String] = []
    for sourceID in ["source-a", "source-b"] {
        let presentation = try await runtime.request(
            reference: .init(id: sourceID),
            now: .fixtureNow
        )
        let card = try #require(presentation.card)
        let domain = try #require(presentation.domain)
        domains.append(domain)
        _ = try await runtime.recordFeedback(
            .helpful,
            memoryID: card.id,
            domain: domain,
            expectedVersion: presentation.version
        )
    }
    #expect(domains[0] != domains[1])
    let snapshot = try fixture.loadSnapshot()
    #expect(domains.allSatisfy {
        snapshot.coreState.familiarity.stage(for: $0) == .usefulStranger
    })
}

@Test("live runtime applies each action from a fresh request and refuses stale reuse")
func liveMeaningPreviewRuntimeActionsAreOneShot() async throws {
    for action in MeaningPreviewCardAction.allCases {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: fixture.manifests,
            sourceResolver: MeaningPreviewStaticSourceResolver()
        )
        _ = try await runtime.enable()
        _ = try await runtime.grantLocalAccess()
        let presentation = try await runtime.request(
            reference: .init(id: action.rawValue),
            now: .fixtureNow
        )
        let card = try #require(presentation.card)

        await #expect(throws: MeaningPreviewRuntimeError.stalePresentation) {
            _ = try await runtime.applyAction(
                action,
                memoryID: card.id,
                expectedVersion: presentation.version + 1,
                at: .fixtureNow
            )
        }
        #expect(
            try await runtime.applyAction(
                action,
                memoryID: card.id,
                expectedVersion: presentation.version,
                at: .fixtureNow
            ) == presentation.version + 1
        )
        await #expect(throws: MeaningPreviewRuntimeError.noActivePresentation) {
            _ = try await runtime.applyAction(
                action,
                memoryID: card.id,
                expectedVersion: presentation.version + 1,
                at: .fixtureNow
            )
        }
    }
}

@Test("live runtime records Not helpful without advancing familiarity")
func liveMeaningPreviewRuntimePersistsNotHelpful() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let presentation = try await runtime.request(
        reference: .init(id: "not-helpful"),
        now: .fixtureNow
    )
    let card = try #require(presentation.card)
    let domain = try #require(presentation.domain)
    _ = try await runtime.recordFeedback(
        .notHelpful,
        memoryID: card.id,
        domain: domain,
        expectedVersion: presentation.version
    )

    let snapshot = try fixture.loadSnapshot()
    #expect(snapshot.coreState.familiarity.stage(for: domain) == .usefulStranger)
    let events = try fixture.auditEvents()
    #expect(events.contains { $0.route == "not-helpful" })
}

@Test("restricted selected context produces silence and status-only exclusion")
func liveMeaningPreviewRuntimeExcludesRestrictedContext() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let secret = "api_key=synthetic-credential-0000"
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(
            context: .fixture(
                id: "restricted",
                derivedText: secret,
                sensitivity: .restricted
            )
        )
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let presentation = try await runtime.request(
        reference: .init(id: "restricted"),
        now: .fixtureNow
    )

    #expect(presentation.card == nil)
    #expect(presentation.inspect.exclusionLabels == ["restricted"])
    let snapshotJSON = String(
        decoding: try JSONEncoder().encode(fixture.loadSnapshot()),
        as: UTF8.self
    )
    #expect(try fixture.loadSnapshot().coreState.memory.isEmpty)
    #expect(try fixture.loadSnapshot().provenance.isEmpty)
    #expect(!snapshotJSON.contains(secret))
    #expect(try fixture.auditEvents().allSatisfy { ($0.outboundByteCount ?? 0) == 0 })
}

@Test("trusted metadata exclusions remain silent and status-only")
func liveMeaningPreviewRuntimeHonorsResolvedMetadata() async throws {
    let cases: [(MeaningPreviewResolvedContext, MeaningContextExclusion)] = [
        (.fixture(id: "restricted", sensitivity: .restricted), .restricted),
        (.fixture(id: "secret", derivedText: "api_key=synthetic-only"), .secretLike),
        (.fixture(id: "inactive", isActive: false), .inactive),
        (.fixture(id: "hidden", isVisible: false), .hidden),
        (.fixture(id: "unsupported", isSupported: false), .unsupported),
        (
            .fixture(
                id: "stale",
                observedAt: .fixtureNow.addingTimeInterval(
                    -CAMMeaningContextAdapter.maximumAge - 1
                )
            ),
            .stale
        ),
        (.fixture(id: "not-permitted", permittedUses: []), .notPermitted),
        (.fixture(id: "missing", derivedText: ""), .missing),
    ]

    for (context, expected) in cases {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: fixture.manifests,
            sourceResolver: MeaningPreviewStaticSourceResolver(context: context)
        )
        _ = try await runtime.enable()
        _ = try await runtime.grantLocalAccess()
        let presentation = try await runtime.request(
            reference: .init(id: context.id),
            now: .fixtureNow
        )
        #expect(presentation.card == nil)
        #expect(presentation.inspect.exclusionLabels == [expected.rawValue])
        #expect(try fixture.auditEvents().allSatisfy {
            ($0.outboundByteCount ?? 0) == 0 && $0.payloadSHA256 == nil
        })
    }
}

@Test("eligible context persists exact bounded provenance metadata")
func liveMeaningPreviewRuntimePersistsResolvedProvenance() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let observedAt = Date.fixtureNow.addingTimeInterval(-120)
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(
            context: .fixture(
                id: "provenance-source",
                observedAt: observedAt,
                uncertainty: .tentative
            )
        )
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    _ = try await runtime.request(
        reference: .init(id: "provenance-source"),
        now: .fixtureNow
    )

    let provenance = try #require(fixture.loadSnapshot().provenance.first)
    #expect(provenance.itemID == "provenance-source")
    #expect(provenance.sourceID == "provenance-source")
    #expect(provenance.observedAt == observedAt)
    #expect(provenance.uncertainty == .tentative)
    #expect(provenance.permittedUse == .meaningPreview)
}

@Test("source resolver exposes only bounded derived context to persisted snapshots")
func liveMeaningPreviewRuntimeDoesNotPersistProviderRawSource() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let rawMarker = "RAW-IMMUTABLE-SOURCE-DO-NOT-PERSIST-42"
    let resolver = DerivedOnlyResolver(
        rawSource: rawMarker,
        derivedText: "Prepare the bounded outline."
    )
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: resolver
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    _ = try await runtime.request(
        reference: .init(id: "derived-only"),
        now: .fixtureNow
    )

    let decoded = try fixture.loadSnapshot()
    let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
    #expect(!encoded.contains(rawMarker))
    #expect(encoded.contains("Prepare the bounded outline."))
}

@Test("Disable immediately before save prevents Preview and audit persistence")
func liveMeaningPreviewRuntimeClosesSaveAuthorizationRace() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let barrier = SynchronousSaveBarrier()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(),
        beforePreviewSave: { barrier.blockBeforeSave() }
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let request = Task {
        try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        )
    }
    await barrier.waitUntilBlocked()
    #expect(try await runtime.disable() == .disabled)
    barrier.release()

    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await request.value
    }
    #expect(try fixture.loadSnapshot().revision == 0)
    #expect(try fixture.auditEvents().isEmpty)
}

@Test("corrupted isolated store is typed then archived and reinitialized")
func liveMeaningPreviewRuntimeRecoversCorruptedStore() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    try fixture.configureModuleReady()
    let databaseURL = LocalVaultPaths.meaningPreviewDatabaseURL(
        vaultRoot: fixture.root
    )
    try FileManager.default.createDirectory(
        at: databaseURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let corrupted = Data("not-a-sqlite-database".utf8)
    try corrupted.write(to: databaseURL)
    let ordinarySentinel = fixture.root.appending(path: "ordinary-cam-sentinel")
    let ordinaryBytes = Data("ordinary-cam-unchanged".utf8)
    try ordinaryBytes.write(to: ordinarySentinel)
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )

    #expect(runtime.initialLifecycle == .corruptedStore)
    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        )
    }
    let receipt = try await runtime.recover()
    #expect(receipt == .init(lifecycle: .ready, archivedPreviousState: true))
    #expect(try fixture.loadSnapshot().revision == 0)
    #expect(try Data(contentsOf: ordinarySentinel) == ordinaryBytes)

    let archiveRoot = fixture.root.appending(path: "meaning-preview-archive")
    let archivedDirectory = try #require(
        FileManager.default.contentsOfDirectory(
            at: archiveRoot,
            includingPropertiesForKeys: nil
        ).first
    )
    #expect(
        try Data(contentsOf: archivedDirectory.appending(path: "MeaningPreview.sqlite"))
            == corrupted
    )
    #expect(
        try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        ).card != nil
    )
}

@Test("recovery refuses disabled and enable-only states without filesystem mutation")
func liveMeaningPreviewRuntimeRecoveryRequiresAuthorizedBrokenStore() async throws {
    for shouldEnable in [false, true] {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: fixture.manifests,
            sourceResolver: MeaningPreviewStaticSourceResolver()
        )
        if shouldEnable { _ = try await runtime.enable() }
        let expected: MeaningPreviewLifecycle = shouldEnable
            ? .enabledWithoutLocalRead : .disabled
        #expect(await runtime.loadLifecycle() == expected)
        await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
            _ = try await runtime.recover()
        }
        #expect(await runtime.loadLifecycle() == expected)
        #expect(!fixture.previewDatabaseExists)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.root.appending(path: "meaning-preview-archive").path
        ))
    }
}

@Test("non-corruption SQLite open failure is unavailable and cannot archive")
func liveMeaningPreviewRuntimeDoesNotMislabelIOFailureAsCorruption() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    try fixture.configureModuleReady()
    let databaseURL = LocalVaultPaths.meaningPreviewDatabaseURL(
        vaultRoot: fixture.root
    )
    try FileManager.default.createDirectory(
        at: databaseURL,
        withIntermediateDirectories: true
    )
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )
    #expect(runtime.initialLifecycle == .unavailable)
    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.recover()
    }
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(
        atPath: databaseURL.path,
        isDirectory: &isDirectory
    ))
    #expect(isDirectory.boolValue)
    #expect(!FileManager.default.fileExists(
        atPath: fixture.root.appending(path: "meaning-preview-archive").path
    ))
}

@Test("unsupported isolated schema is typed as incompatible")
func liveMeaningPreviewRuntimeDetectsIncompatibleStore() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    try fixture.configureModuleReady()
    let databaseURL = LocalVaultPaths.meaningPreviewDatabaseURL(
        vaultRoot: fixture.root
    )
    _ = try MeaningPreviewStore(databaseURL: databaseURL)
    let database = try SQLiteStore(databaseURL: databaseURL, migrations: [])
    let incompatible = Data("{\"schemaVersion\":999}".utf8).base64EncodedString()
    try database.execute(
        "INSERT INTO meaning_preview_state(singleton, snapshot_json) VALUES (1, ?)",
        bindings: [incompatible]
    )
    try database.close()

    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver()
    )
    #expect(runtime.initialLifecycle == .incompatibleStore)
    #expect(await runtime.loadLifecycle() == .incompatibleStore)
}

@Test("manifest permission drift fails unavailable before source access")
func liveMeaningPreviewRuntimeRejectsManifestPermissionDrift() async throws {
    for permissions in [
        [Permission](),
        [.readLocal],
        [.writeLocal],
        [.readLocal, .writeLocal, .network],
    ] {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let manifests = try fixture.driftedManifestDirectory(
            permissions: permissions
        )
        let reads = ReadCounter()
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: manifests,
            sourceResolver: reads
        )
        #expect(runtime.initialLifecycle == .unavailable)
        await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
            _ = try await runtime.request(
                reference: .init(id: "selected"),
                now: .fixtureNow
            )
        }
        #expect(await reads.count == 0)
    }
}

@Test("Disable before real action or feedback save prevents mutation persistence")
func liveMeaningPreviewRuntimeClosesMutationSaveRaces() async throws {
    for mutation in MeaningPreviewGatedOperation.allCases where mutation != .request {
        let fixture = try LiveRuntimeFixture()
        defer { fixture.remove() }
        let barrier = SynchronousSaveBarrier(targetSave: 2)
        let runtime = MeaningPreviewLiveRuntime(
            root: fixture.root,
            manifestDirectory: fixture.manifests,
            sourceResolver: MeaningPreviewStaticSourceResolver(),
            beforePreviewSave: { barrier.blockBeforeSave() }
        )
        _ = try await runtime.enable()
        _ = try await runtime.grantLocalAccess()
        let presentation = try await runtime.request(
            reference: .init(id: "selected"),
            now: .fixtureNow
        )
        let card = try #require(presentation.card)
        let domain = try #require(presentation.domain)
        let operation = Task {
            switch mutation {
            case .action:
                return try await runtime.applyAction(
                    .later,
                    memoryID: card.id,
                    expectedVersion: presentation.version,
                    at: .fixtureNow
                )
            case .feedback:
                return try await runtime.recordFeedback(
                    .helpful,
                    memoryID: card.id,
                    domain: domain,
                    expectedVersion: presentation.version
                )
            case .request:
                return 0
            }
        }
        await barrier.waitUntilBlocked()
        #expect(try await runtime.disable() == .disabled)
        barrier.release()
        await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
            _ = try await operation.value
        }
        #expect(try fixture.loadSnapshot().revision == presentation.version)
        let routes = try fixture.auditEvents().compactMap(\.route)
        #expect(!routes.contains("later"))
        #expect(!routes.contains("helpful"))
    }
}

@Test("permission revocation during lazy selection refuses before Preview storage")
func liveMeaningPreviewRuntimeClosesRevocationRace() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let gate = SelectionGate()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: gate
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let request = Task {
        try await runtime.request(
            reference: .init(id: "gated"),
            now: .fixtureNow
        )
    }
    await gate.waitUntilRequested()
    let registry = try ModuleRegistry(
        manifestDirectory: fixture.manifests,
        stateURL: LocalVaultPaths.stateURL(.moduleState, vaultRoot: fixture.root)
    )
    try registry.grant([], to: "cam.meaning-preview")
    await gate.resume()

    await #expect(throws: MeaningPreviewRuntimeError.disabledDuringRequest) {
        _ = try await request.value
    }
    #expect(!fixture.previewDatabaseExists)
}

@Test("Disable during lazy selection discards the in-flight result and session")
func liveMeaningPreviewRuntimeDisablesDuringFlight() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let gate = SelectionGate()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: gate
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let request = Task {
        try await runtime.request(
            reference: .init(id: "gated"),
            now: .fixtureNow
        )
    }
    await gate.waitUntilRequested()
    #expect(try await runtime.disable() == .disabled)
    await gate.resume()

    await #expect(throws: MeaningPreviewRuntimeError.disabledDuringRequest) {
        _ = try await request.value
    }
    #expect(await runtime.loadLifecycle() == .disabled)
    #expect(!fixture.previewDatabaseExists)
}

@Test("reflective runtime refuses before admission and permission without source reads")
func liveReflectionRefusesBeforeResolvingContext() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let reads = ReadCounter()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: reads,
        reflectionReportURL: fixture.root.appending(path: "missing-report.json"),
        reflectionAssignmentProvider: { try reflectionAssignmentFixture() }
    )

    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.requestReflection(
            references: [.init(id: "a"), .init(id: "b")],
            now: .fixtureNow
        )
    }
    #expect(await reads.count == 0)
}

@MainActor
@Test("AppModel recognizes live runtime only with an injected current admitted report")
func appModelRecognizesAdmittedLiveReflection() throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let reportURL = fixture.root.appending(path: "named-report.json")
    let reportHash = try writePassingReflectionReport(
        to: reportURL,
        evaluatedAt: Date()
    )
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(),
        reflectionReportURL: reportURL,
        reflectionReportHash: reportHash,
        reflectionAssignmentProvider: { try reflectionAssignmentFixture() }
    )

    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )

    #expect(model.isMeaningPreviewReflectionAvailable)
}

@Test("disable during reflective model await suppresses candidate after revocation")
func liveReflectionDisableWinsAfterModelAwait() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let reportURL = fixture.root.appending(path: "named-report.json")
    let reportHash = try writePassingReflectionReport(
        to: reportURL,
        evaluatedAt: .fixtureNow
    )
    let transport = GatedReflectionTransport()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: MeaningPreviewStaticSourceResolver(),
        reflectionReportURL: reportURL,
        reflectionReportHash: reportHash,
        reflectionAssignmentProvider: { try reflectionAssignmentFixture() },
        reflectionTransport: transport
    )
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    let request = Task {
        try await runtime.requestReflection(
            references: [.init(id: "source-a"), .init(id: "source-b")],
            now: .fixtureNow
        )
    }
    await transport.waitUntilCandidateRequested()
    #expect(try await runtime.disable() == .disabled)
    await transport.resumeCandidate()

    await #expect(throws: MeaningPreviewRuntimeError.disabledDuringRequest) {
        _ = try await request.value
    }
    #expect(await runtime.loadLifecycle() == .disabled)
    if fixture.previewDatabaseExists {
        let encoded = try JSONEncoder().encode(fixture.loadSnapshot())
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(!text.contains("The bounded outline may remain a preparation"))
    }
}

private func reflectionAssignmentFixture() throws -> ModelAssignment {
    try ModelAssignment(
        provider: .local,
        modelID: "local/meaning",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )
}

@MainActor
@Test("live reflection rejects a passing report changed after its build-bound digest")
func liveReflectionRejectsTamperedAdmittedReport() async throws {
    let fixture = try LiveRuntimeFixture()
    defer { fixture.remove() }
    let reportURL = fixture.root.appending(path: "named-report.json")
    let reportHash = try writePassingReflectionReport(
        to: reportURL,
        evaluatedAt: Date()
    )
    _ = try writePassingReflectionReport(
        to: reportURL,
        evaluatedAt: Date().addingTimeInterval(1)
    )
    let reads = ReadCounter()
    let transport = UnexpectedReflectionTransport()
    let runtime = MeaningPreviewLiveRuntime(
        root: fixture.root,
        manifestDirectory: fixture.manifests,
        sourceResolver: reads,
        reflectionReportURL: reportURL,
        reflectionReportHash: reportHash,
        reflectionAssignmentProvider: { try reflectionAssignmentFixture() },
        reflectionTransport: transport
    )

    let model = AppModel(
        initializeFullWorkspace: false,
        meaningPreviewRuntime: runtime
    )

    #expect(!model.isMeaningPreviewReflectionAvailable)
    _ = try await runtime.enable()
    _ = try await runtime.grantLocalAccess()
    await #expect(throws: MeaningPreviewRuntimeError.accessDenied) {
        _ = try await runtime.requestReflection(
            references: [.init(id: "source-a"), .init(id: "source-b")],
            now: Date()
        )
    }
    #expect(await reads.count == 0)
    #expect(await transport.requestCount == 0)
}

private func writePassingReflectionReport(
    to url: URL,
    evaluatedAt: Date
) throws -> String {
    let manifestURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/MeaningPreview/v1/manifest.json")
    let manifest = try MeaningPreviewEvaluationManifest.decode(
        Data(contentsOf: manifestURL)
    )
    let runtimeIdentity = "loopback:http://127.0.0.1:8080/v1"
    let evaluation = MeaningPreviewEvaluationReport(
        evaluatorVersion: "meaning-preview-evaluator-v1",
        evaluationMode: .namedModel,
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        runtimeIdentity: runtimeIdentity,
        modelID: "local/meaning",
        caseCount: 22,
        surfaceCaseCount: 7,
        silenceCaseCount: 15,
        decisionAccuracy: 1,
        supportRecall: 1,
        evidencePrecision: 1,
        counterevidenceRecall: 1,
        abstentionAccuracy: 1,
        prohibitedBehaviorAccuracy: 1,
        failedCaseIDs: [],
        unansweredCaseIDs: [],
        prohibitedFindings: [],
        caseResults: manifest.cases.map {
            MeaningPreviewEvaluationCaseResult(
                caseID: $0.id,
                expectedDecision: $0.expectedDecision,
                actualDecision: $0.expectedDecision,
                selectedSupportIDs: $0.requiredSupportIDs,
                selectedCounterevidenceIDs: $0.requiredCounterevidenceIDs,
                prohibitedBehaviorIDs: [],
                passed: true,
                errorCode: nil
            )
        },
        thresholds: manifest.thresholds,
        meetsFrozenThresholds: true,
        namedModelEligible: true
    )
    let report = MeaningPreviewNamedModelReport(
        reportVersion: "meaning-preview-named-model-report-v1",
        evaluatedAt: evaluatedAt,
        manifestHash: MeaningPreviewNamedModelEvaluator.canonicalManifestHash,
        runtimeAvailable: true,
        reflectionEnabled: true,
        runtimeIdentity: runtimeIdentity,
        modelID: "local/meaning",
        errorCode: nil,
        evaluation: evaluation
    )
    let data = try JSONEncoder().encode(report)
    try data.write(to: url, options: .atomic)
    return MeaningPreviewEvaluationManifest.sha256(of: data)
}

private actor GatedReflectionTransport: LocalModelTransport {
    private var requested = false
    private var continuation: CheckedContinuation<Void, Never>?

    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        if request.method == .get {
            return .init(
                statusCode: 200,
                data: Data(#"{"data":[{"id":"local/meaning"}]}"#.utf8)
            )
        }
        requested = true
        await withCheckedContinuation { continuation = $0 }
        let content = #"{"domain":"explicit reflection|sources:source-a,source-b","decision":"surface","observation":"Prepare the bounded outline.","interpretation":"The bounded outline may need preparation.","opening":"The bounded outline may remain a preparation.","support_ids":["source-a"],"counterevidence_ids":["source-b"],"uncertainty":0.4}"#
        let envelope = try JSONSerialization.data(withJSONObject: [
            "model": "local/meaning",
            "choices": [[
                "message": ["role": "assistant", "content": content],
            ]],
        ])
        return .init(statusCode: 200, data: envelope)
    }

    func waitUntilCandidateRequested() async {
        while !requested { await Task.yield() }
    }

    func resumeCandidate() {
        continuation?.resume()
        continuation = nil
    }
}

private actor UnexpectedReflectionTransport: LocalModelTransport {
    private(set) var requestCount = 0

    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        requestCount += 1
        throw LocalModelInferenceError.transportUnavailable
    }
}

private actor ReadCounter: MeaningPreviewSourceResolving {
    private(set) var count = 0
    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext {
        count += 1
        return .fixture(id: reference.id)
    }
}

private actor SelectionGate: MeaningPreviewSourceResolving {
    private var requested = false
    private var continuation: CheckedContinuation<Void, Never>?

    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext {
        requested = true
        await withCheckedContinuation { continuation = $0 }
        return .fixture(id: reference.id)
    }

    func waitUntilRequested() async {
        while !requested { await Task.yield() }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private struct LiveRuntimeFixture {
    let root: URL
    let manifests: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "cam-meaning-preview-app-runtime")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        manifests = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Modules/Core", directoryHint: .isDirectory)
    }

    var previewDatabaseExists: Bool {
        FileManager.default.fileExists(
            atPath: LocalVaultPaths.meaningPreviewDatabaseURL(
                vaultRoot: root
            ).path
        )
    }

    func loadSnapshot() throws -> MeaningPreviewSnapshot {
        try MeaningPreviewStore(
            databaseURL: LocalVaultPaths.meaningPreviewDatabaseURL(
                vaultRoot: root
            )
        ).load()
    }

    func auditEvents() throws -> [AuditEvent] {
        let store = try AuditStore(databaseURL: root.appending(path: "vault.sqlite"))
        let events = try store.events()
        try store.close()
        return events
    }

    func configureModuleReady() throws {
        let registry = try ModuleRegistry(
            manifestDirectory: manifests,
            stateURL: LocalVaultPaths.stateURL(.moduleState, vaultRoot: root)
        )
        try registry.enable("cam.meaning-preview")
        try registry.grant(
            [.readLocal, .writeLocal],
            to: "cam.meaning-preview"
        )
    }

    func driftedManifestDirectory(
        permissions: [Permission]
    ) throws -> URL {
        let directory = root.appending(
            path: "drifted-manifests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let source = manifests.appending(path: "meaning-preview.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: source))
                as? [String: Any]
        )
        object["permissions"] = permissions.map(\.rawValue)
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: directory.appending(path: "meaning-preview.json"))
        return directory
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private extension Date {
    static let fixtureNow = Date(timeIntervalSince1970: 1_750_000_000)
}

private struct MeaningPreviewStaticSourceResolver:
    MeaningPreviewSourceResolving {
    let context: MeaningPreviewResolvedContext?

    init(context: MeaningPreviewResolvedContext? = nil) {
        self.context = context
    }

    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext {
        context ?? .fixture(id: reference.id)
    }
}

private struct DerivedOnlyResolver: MeaningPreviewSourceResolving {
    private let rawSource: String
    private let derivedText: String

    init(rawSource: String, derivedText: String) {
        self.rawSource = rawSource
        self.derivedText = derivedText
    }

    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext {
        _ = rawSource
        return .fixture(id: reference.id, derivedText: derivedText)
    }
}

private final class SynchronousSaveBarrier: @unchecked Sendable {
    private let signal = SaveBarrierSignal()
    private let released = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private let targetSave: Int
    private var saveCount = 0

    init(targetSave: Int = 1) {
        self.targetSave = targetSave
    }

    func blockBeforeSave() {
        lock.lock()
        saveCount += 1
        let shouldBlock = saveCount == targetSave
        lock.unlock()
        guard shouldBlock else { return }
        Task { await signal.markEntered() }
        released.wait()
    }

    func waitUntilBlocked() async {
        await signal.waitUntilEntered()
    }

    func release() {
        released.signal()
    }
}

private actor SaveBarrierSignal {
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func markEntered() {
        entered = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private extension MeaningPreviewResolvedContext {
    static func fixture(
        id: String = "selected",
        derivedText: String = "Prepare the bounded outline.",
        observedAt: Date = .fixtureNow,
        uncertainty: MeaningContextUncertainty = .supported,
        sensitivity: MeaningContextSensitivity = .ordinary,
        permittedUses: Set<MeaningContextPermittedUse> = [.meaningPreview],
        isVisible: Bool = true,
        isActive: Bool = true,
        isSupported: Bool = true
    ) -> Self {
        .init(
            id: id,
            derivedText: derivedText,
            observedAt: observedAt,
            domain: "selected local source",
            uncertainty: uncertainty,
            sensitivity: sensitivity,
            permittedUses: permittedUses,
            isVisible: isVisible,
            isActive: isActive,
            isSupported: isSupported
        )
    }
}
