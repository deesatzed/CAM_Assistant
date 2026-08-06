import CAMAssistantCore
import Foundation

enum BarebonesPackagedProofError: Error, Sendable {
    case invalidApplicationSupportRoot
    case primaryShell
    case primaryCopy
    case capture
    case restart
    case ask
    case keep
    case recovery
    case unexpectedModelRequest

    var safeCode: String {
        switch self {
        case .invalidApplicationSupportRoot: "invalid-application-support-root"
        case .primaryShell: "primary-shell"
        case .primaryCopy: "primary-copy"
        case .capture: "capture"
        case .restart: "restart"
        case .ask: "ask"
        case .keep: "keep"
        case .recovery: "recovery"
        case .unexpectedModelRequest: "unexpected-model-request"
        }
    }
}

struct BarebonesPackagedProofReceipt: Sendable {
    let summary: String
}

enum BarebonesPackagedProofOutcome: Sendable {
    case success(BarebonesPackagedProofReceipt)
    case failure(BarebonesPackagedProofError)
    case unexpectedFailure
}

/// Runs the repository-owned, model-free packaged journey against an isolated
/// Application Support root. It uses the same storage, capture, local-answer,
/// Keep, and recovery types as the app while granting no external authority.
enum BarebonesPackagedProof {
    static func runBlocking(
        applicationSupportRoot: URL
    ) -> BarebonesPackagedProofOutcome {
        let completed = DispatchSemaphore(value: 0)
        let outcome = ProofOutcomeBox()
        Task.detached {
            do {
                outcome.store(
                    .success(
                        try await run(
                            applicationSupportRoot: applicationSupportRoot
                        )
                    )
                )
            } catch let error as BarebonesPackagedProofError {
                outcome.store(.failure(error))
            } catch {
                outcome.store(.unexpectedFailure)
            }
            completed.signal()
        }
        completed.wait()
        return outcome.load()
    }

    static func run(
        applicationSupportRoot: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> BarebonesPackagedProofReceipt {
        let supportRoot = applicationSupportRoot.standardizedFileURL
        let configuredSupportRoot = environment[
            LocalVaultPaths.applicationSupportRootEnvironmentKey
        ].map {
            URL(filePath: $0, directoryHint: .isDirectory).standardizedFileURL
        }
        guard supportRoot.path.hasPrefix("/"),
              configuredSupportRoot == supportRoot else {
            throw BarebonesPackagedProofError.invalidApplicationSupportRoot
        }
        let vaultRoot = try LocalVaultPaths.rootURL(
            environment: [
                LocalVaultPaths.applicationSupportRootEnvironmentKey:
                    supportRoot.path,
            ]
        )
        try FileManager.default.createDirectory(
            at: vaultRoot,
            withIntermediateDirectories: true
        )

        guard AppExperience.productionDefault == .primary,
              AppExperience.primary.visibleSections
                == [.home, .library, .settings] else {
            throw BarebonesPackagedProofError.primaryShell
        }

        let databaseURL = vaultRoot.appending(path: "vault.sqlite")
        let contentStore = try ContentStore(
            rootDirectory: vaultRoot.appending(
                path: "content",
                directoryHint: .isDirectory
            )
        )
        let queue = try IngestQueue(
            databaseURL: databaseURL,
            contentStore: contentStore,
            extractors: .localDefaults
        )
        let capture = CaptureService(queue: queue)
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let firstEnvelope = ClipboardCapture.envelope(
            text: "The appointment is Tuesday at 10.",
            capturedAt: capturedAt,
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        )
        let secondEnvelope = ClipboardCapture.envelope(
            text: "The appointment is Tuesday at 10.",
            capturedAt: capturedAt.addingTimeInterval(1),
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        )
        let first = try capture.capture(firstEnvelope)
        let duplicate = try capture.capture(secondEnvelope)
        let processed = try queue.processAll()
        let documents = try queue.documents()
        let provenance = try queue.provenance(for: first.sourceID)
        guard !first.wasDuplicateSource,
              duplicate.wasDuplicateSource,
              first.sourceID == duplicate.sourceID,
              processed.count == 1,
              processed[0].status == .completed,
              try queue.sourceCount() == 1,
              documents.count == 1,
              provenance.count == 2 else {
            throw BarebonesPackagedProofError.capture
        }
        let library = LibraryPresentation(
            documents: documents,
            provenanceBySource: [first.sourceID: provenance]
        )
        guard let libraryRow = library.rows.first else {
            throw BarebonesPackagedProofError.capture
        }
        let libraryItem = LibraryItemPresentation(row: libraryRow)
        let primaryCopy = [
            HomePresentation.empty.visibleText,
            BarebonesSettingsPresentation.primaryText,
            libraryItem.primaryText,
        ].joined(separator: " ")
        let bannedPrimaryTerms = [
            "OpenRouter", "endpoint", "route", "provider", "manifest",
            "passage ID", "ingest",
        ]
        guard libraryItem.title != first.sourceID.rawValue,
              bannedPrimaryTerms.allSatisfy({
                  !primaryCopy.localizedCaseInsensitiveContains($0)
              }) else {
            throw BarebonesPackagedProofError.primaryCopy
        }
        try queue.close()

        let restartedQueue = try IngestQueue(
            databaseURL: databaseURL,
            contentStore: contentStore,
            extractors: .localDefaults
        )
        guard try restartedQueue.sourceCount() == 1,
              try restartedQueue.documents().count == 1 else {
            throw BarebonesPackagedProofError.restart
        }

        let modelRequests = ProofRequestCounter()
        let answer = try await LocalAnswerCoordinator(
            loadContext: { question in
                try LocalConversationContextProvider(databaseURL: databaseURL)
                    .context(for: question)
            },
            isModelAvailable: false,
            generate: { _, _ in
                await modelRequests.record()
                throw LocalModelInferenceError.transportUnavailable
            }
        ).answer("appointment Tuesday")
        let networkRequestCount = await modelRequests.value
        guard answer.mode == .matchingPassages,
              answer.response.citations.count == 1 else {
            throw BarebonesPackagedProofError.ask
        }
        guard networkRequestCount == 0 else {
            throw BarebonesPackagedProofError.unexpectedModelRequest
        }

        let keptURL = LocalVaultPaths.stateURL(
            .keptMemories,
            vaultRoot: vaultRoot
        )
        let keptStore = KeptMemoryStore(url: keptURL)
        let kept = try keptStore.keep(
            answer: answer.response,
            now: capturedAt.addingTimeInterval(2)
        )
        let restartedKeptStore = KeptMemoryStore(url: keptURL)
        guard try restartedKeptStore.all() == [kept.memory] else {
            throw BarebonesPackagedProofError.keep
        }
        try restartedKeptStore.undo(receipt: kept.undoReceipt)
        guard try restartedKeptStore.all().isEmpty else {
            throw BarebonesPackagedProofError.keep
        }
        _ = try restartedKeptStore.keep(
            answer: answer.response,
            now: capturedAt.addingTimeInterval(3)
        )

        let watchedStore = WatchedSourceConfigurationStore(
            url: LocalVaultPaths.stateURL(.watchedSources, vaultRoot: vaultRoot)
        )
        try watchedStore.save([
            try WatchedSource(
                id: UUID(
                    uuidString: "00000000-0000-0000-0000-000000000103"
                )!,
                path: supportRoot.appending(path: "Watched").path,
                isEnabled: true
            ),
        ])
        try restartedQueue.close()

        let packageURL = supportRoot.appending(path: "Barebones.camvault")
        let restoredRoot = supportRoot.appending(
            path: "RestoredCAMAssistant",
            directoryHint: .isDirectory
        )
        let backup = FullVaultBackupService()
        let created = try backup.createPackage(
            from: vaultRoot,
            to: packageURL,
            createdAt: capturedAt.addingTimeInterval(4)
        )
        let validated = try backup.validatePackage(at: packageURL)
        let restored = try backup.restorePackage(
            at: packageURL,
            to: restoredRoot,
            restoredAt: capturedAt.addingTimeInterval(5)
        )
        let restoredWatched = try WatchedSourceConfigurationStore(
            url: LocalVaultPaths.stateURL(
                .watchedSources,
                vaultRoot: restoredRoot
            )
        ).load()
        let restoredMemories = try KeptMemoryStore(
            url: LocalVaultPaths.stateURL(
                .keptMemories,
                vaultRoot: restoredRoot
            )
        ).all()
        let restoredQueue = try IngestQueue(
            databaseURL: restoredRoot.appending(path: "vault.sqlite"),
            contentStore: try ContentStore(
                rootDirectory: restoredRoot.appending(
                    path: "content",
                    directoryHint: .isDirectory
                )
            ),
            extractors: .localDefaults
        )
        defer { try? restoredQueue.close() }
        guard created.entryCount == validated.entryCount,
              restored.entryCount == validated.entryCount,
              restored.watchedSourcesPaused == 1,
              restoredWatched.count == 1,
              !restoredWatched[0].isEnabled,
              restoredMemories.count == 1,
              try restoredQueue.sourceCount() == 1,
              try restoredQueue.documents().count == 1 else {
            throw BarebonesPackagedProofError.recovery
        }

        return BarebonesPackagedProofReceipt(
            summary: [
                "shell=Home,Library,Settings",
                "capture=true duplicate=true restart=true",
                "ask=matchingPassages citations=1",
                "keep_restart=true undo=true",
                "backup=true restore=true watched_paused=true",
                "network_requests=0",
            ].joined(separator: " ")
        )
    }
}

private actor ProofRequestCounter {
    private(set) var value = 0

    func record() {
        value += 1
    }
}

private final class ProofOutcomeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: BarebonesPackagedProofOutcome?

    func store(_ value: BarebonesPackagedProofOutcome) {
        lock.lock()
        outcome = value
        lock.unlock()
    }

    func load() -> BarebonesPackagedProofOutcome {
        lock.lock()
        defer { lock.unlock() }
        return outcome ?? .unexpectedFailure
    }
}
