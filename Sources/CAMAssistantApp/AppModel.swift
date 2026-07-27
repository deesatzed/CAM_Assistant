import CAMAssistantCore
import AppKit
import SwiftUI

enum AssistantSection: String, CaseIterable, Identifiable {
    case assistant = "Assistant"
    case library = "Library"
    case activity = "Activity"
    case tasks = "Tasks"
    case cam = "CAM"
    case research = "Research"
    case repositories = "Repositories"
    case macCare = "Mac Care"
    case settings = "Settings"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .assistant:
            "sparkles"
        case .library:
            "books.vertical"
        case .activity:
            "clock.arrow.circlepath"
        case .tasks:
            "checklist"
        case .cam:
            "point.3.connected.trianglepath.dotted"
        case .research:
            "text.magnifyingglass"
        case .repositories:
            "folder.badge.gearshape"
        case .macCare:
            "desktopcomputer"
        case .settings:
            "gearshape"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: AssistantSection = .assistant
    @Published private(set) var health: AppHealth
    @Published private(set) var modelSettings: ModelSettingsState?
    @Published private(set) var modelSettingsError: String?
    @Published private(set) var localModelHealth: LocalModelHealth?
    @Published private(set) var localModelHealthError: String?
    @Published private(set) var isCheckingLocalModel = false
    @Published private(set) var isGeneratingLocalModelAnswer = false
    @Published private(set) var pendingActionCard: ActionCard?
    @Published private(set) var camStatus = CAMIntegrationStatus.unavailableCAMv1
    @Published private(set) var researchPresentation = ResearchPresentation.notStarted
    @Published private(set) var currentResearchRun: ResearchRun?
    @Published private(set) var retainedResearchPlans: [StoredResearchPlan] = []
    @Published var researchQuery = ""
    @Published private(set) var researchError: String?
    @Published var conversationQuestion = ""
    @Published private(set) var conversationResponse: ConversationResponse?
    @Published private(set) var conversationRecord: ConversationRecord?
    @Published private(set) var conversationError: String?
    @Published private(set) var knowledgeClaims: [KnowledgeClaim] = []
    @Published private(set) var contradictionCandidates: [ContradictionCandidate] = []
    @Published var contradictionLeftID = ""
    @Published var contradictionRightID = ""
    @Published var contradictionSteelman = ""
    @Published var contradictionBridgeSuggestion = ""
    @Published private(set) var knowledgeError: String?
    @Published private(set) var promotedTask: TaskProposal?
    @Published private(set) var taskPresentation = TaskListPresentation(records: [])
    @Published private(set) var taskError: String?
    @Published private(set) var libraryPresentation = LibraryPresentation(documents: [])
    @Published var selectedLibrarySourceID: String?
    @Published private(set) var rawSourceInspection: RawSourceInspection?
    @Published private(set) var libraryError: String?
    @Published private(set) var isRefreshingWorkspace = false
    @Published private(set) var isUpdatingLibraryLifecycle = false
    @Published private(set) var isInspectingRawSource = false
    @Published private(set) var captureMessage: String?
    @Published private(set) var hotkeyError: String?
    @Published private(set) var hotkeyStatus: GlobalHotkeyStatus = .unregistered
    @Published var hotkeyOpenKey = "space"
    @Published var hotkeyCaptureKey = "c"
    @Published var repositoryPath = ""
    @Published private(set) var repositoryPresentation: RepositoryPresentation?
    @Published private(set) var repositoryIndexPresentation: RepositoryIndexPresentation?
    @Published private(set) var repositoryError: String?
    @Published private(set) var isRepositoryIndexing = false
    @Published private(set) var repositoryObservations: [RepositoryObservationPresentation] = []
    @Published var selectedRepositoryObservationID: String?
    @Published private(set) var isScanningRepositoryObservations = false
    @Published var repositoryIdeaTitle = ""
    @Published var repositoryIdeaCounterevidence = ""
    @Published var repositoryIdeaValidationExperiment = ""
    @Published private(set) var repositoryIdeaProposal: RepositoryIdeaProposal?
    @Published private(set) var repositoryIdeaTask: TaskProposal?
    @Published private(set) var repositoryIdeaResearchPlan: ResearchRun?
    @Published private(set) var repositoryIdeaCodexPlan: TaskProposal?
    @Published private(set) var repositoryIdeaDisposition: RepositoryIdeaDisposition?
    @Published private(set) var repositoryIdeaHistory = RepositoryIdeaListPresentation(records: [])
    @Published private(set) var repositorySources: [RepositorySource] = []
    @Published private(set) var macCarePresentation: MacCarePresentation?
    @Published private(set) var macCareError: String?
    @Published private(set) var isMacCareAssessing = false
    @Published private(set) var watchedSourcePresentation: [WatchedSourcePresentation] = []
    @Published private(set) var watchedSourceError: String?
    @Published private(set) var isUpdatingWatchedSources = false
    private let hotkeyManager = HotkeyManager()
    private let watchedSourceService: WatchedSourceService?
    private let repositorySourceService: RepositorySourceService?
    private var repositorySnapshot: RepositorySnapshot?
    private var repositoryObservationEvidence: [RepositoryObservation] = []
    private var repositoryIdeaCard: RepositoryIdeaCard?
    private var repositoryIndexCancellation: RepositoryIndexCancellation?

    init(
        health: AppHealth = .evaluate(
            localModelAvailable: false,
            camRuntimeAvailable: false,
            networkAvailable: false
        )
    ) {
        self.health = health
        watchedSourceService = Self.makeWatchedSourceService()
        repositorySourceService = Self.makeRepositorySourceService()
        loadHotkeyConfiguration()
        reloadModelSettings()
        reloadTasks()
        reloadLibrary()
        reloadWatchedSources()
        reloadRepositoryIdeaHistory()
        reloadRepositorySources()
        reloadRetainedResearchPlans()
        reloadKnowledgeClaims()
        reloadContradictionCandidates()
    }

    func updateHealth(
        localModelAvailable: Bool,
        camRuntimeAvailable: Bool,
        networkAvailable: Bool
    ) {
        health = .evaluate(
            localModelAvailable: localModelAvailable,
            camRuntimeAvailable: camRuntimeAvailable,
            networkAvailable: networkAvailable
        )
    }

    func beginLocalResearch() {
        do {
            let run = try ResearchCoordinator().begin(id: UUID().uuidString, queries: [researchQuery], stateVersion: 0)
            currentResearchRun = run
            researchPresentation = ResearchPresentation(run: run)
            researchError = nil
        } catch { researchError = "Enter one unique local research question." }
    }

    func keepLocalResearchPlan() {
        guard let currentResearchRun else { return }
        do {
            try ResearchPlanStore(url: try Self.researchPlanStoreURL()).keep(currentResearchRun)
            reloadRetainedResearchPlans()
            researchError = nil
        } catch {
            researchError = "The local research plan could not be kept."
        }
    }

    func resumeLocalResearchPlan(_ plan: StoredResearchPlan) {
        do {
            let resumed = try ResearchCoordinator().resume(
                plan.run,
                expectedStateVersion: plan.run.checkpoint.stateVersion
            )
            currentResearchRun = resumed
            researchPresentation = ResearchPresentation(run: resumed)
            try ResearchPlanStore(url: try Self.researchPlanStoreURL()).keep(resumed)
            reloadRetainedResearchPlans()
            researchError = nil
        } catch {
            researchError = "The local research plan could not be resumed."
        }
    }

    func reloadRetainedResearchPlans() {
        do {
            retainedResearchPlans = try ResearchPlanStore(url: try Self.researchPlanStoreURL()).load()
        } catch {
            retainedResearchPlans = []
            researchError = "Kept local research plans could not be read."
        }
    }

    func reloadModelSettings() {
        do {
            let registry = try ModelRegistry(
                stateURL: ModelProfileStorage.defaultStateURL()
            )
            modelSettings = try ModelSettingsState(registry: registry)
            modelSettingsError = nil
            localModelHealth = nil
            localModelHealthError = nil
        } catch {
            modelSettings = nil
            modelSettingsError = "Local model profile state could not be read."
            localModelHealth = nil
        }
    }

    func checkSelectedLocalModel() {
        let assignment: ModelAssignment
        do {
            assignment = try activeLocalModelAssignment()
        } catch {
            localModelHealth = nil
            localModelHealthError = "Select an active local model profile first."
            return
        }
        isCheckingLocalModel = true
        localModelHealthError = nil
        Task { [weak self] in
            do {
                let health = try await LocalModelClient(
                    assignment: assignment
                ).health()
                self?.localModelHealth = health
                self?.localModelHealthError = nil
                self?.updateHealth(
                    localModelAvailable: true,
                    camRuntimeAvailable: self?.health.canUseCAM ?? false,
                    networkAvailable: self?.health.canUseCloud ?? false
                )
            } catch {
                self?.localModelHealth = nil
                self?.localModelHealthError =
                    "The selected local model endpoint is unavailable or does not expose the selected model."
                self?.updateHealth(
                    localModelAvailable: false,
                    camRuntimeAvailable: self?.health.canUseCAM ?? false,
                    networkAvailable: self?.health.canUseCloud ?? false
                )
            }
            self?.isCheckingLocalModel = false
        }
    }

    func presentActionCard(_ card: ActionCard?) {
        pendingActionCard = card
    }

    func sendLocalQuestion() {
        do {
            let databaseURL = try LocalConversationContextProvider.defaultDatabaseURL()
            let context = try LocalConversationContextProvider(databaseURL: databaseURL)
                .context(for: conversationQuestion)
            conversationResponse = try ConversationCoordinator().respond(
                question: conversationQuestion,
                context: context
            )
            conversationRecord = nil
            conversationError = nil
        } catch {
            conversationError = "Enter a question to search local sources."
        }
    }

    func sendSelectedLocalModelQuestion() {
        guard localModelHealth != nil else {
            conversationError =
                "Health-check the selected local model before asking it."
            return
        }
        let question = conversationQuestion
        let assignment: ModelAssignment
        let databaseURL: URL
        do {
            assignment = try activeLocalModelAssignment()
            databaseURL = try LocalConversationContextProvider
                .defaultDatabaseURL()
        } catch {
            conversationError = "Select an active local model profile first."
            return
        }
        isGeneratingLocalModelAnswer = true
        conversationError = nil
        Task { [weak self] in
            do {
                let context = try await Task.detached {
                    try LocalConversationContextProvider(
                        databaseURL: databaseURL
                    ).context(for: question)
                }.value
                let generated = try await LocalModelClient(
                    assignment: assignment
                ).generate(question: question, context: context)
                self?.conversationResponse = try ConversationCoordinator()
                    .respond(question: question, generated: generated)
                self?.conversationRecord = nil
                self?.conversationError = nil
            } catch LocalModelInferenceError.missingContext {
                self?.conversationError =
                    "No matching local evidence is available. Capture or index a relevant source, then ask again."
            } catch {
                self?.conversationError =
                    "The selected local model could not produce a citation-grounded answer. No fallback or escalation occurred."
            }
            self?.isGeneratingLocalModelAnswer = false
        }
    }

    private func activeLocalModelAssignment() throws -> ModelAssignment {
        let registry = try ModelRegistry(
            stateURL: ModelProfileStorage.defaultStateURL()
        )
        guard let assignment = try registry.activeProfile()?
            .assignment(for: .local) else {
            throw LocalModelInferenceError.invalidAssignment
        }
        return assignment
    }

    func keepConversationResponse() {
        guard let conversationResponse else { return }
        conversationRecord = ConversationCoordinator().keep(conversationResponse)
    }

    func discardConversationResponse() {
        guard let conversationResponse else { return }
        conversationRecord = ConversationCoordinator().discard(conversationResponse)
    }

    func keepConversationAsKnowledge(kind: KnowledgeClaimKind) {
        guard let record = conversationRecord, record.disposition == .kept else {
            conversationError = "Keep a cited local answer before adding it to knowledge."
            return
        }
        do {
            let claim = try KnowledgeClaim(
                id: GoldenRetrievalManifest.sha256(of: Data(("conversation-knowledge|\(kind.rawValue)|\(record.response.id)").utf8)),
                statement: record.response.text,
                kind: kind,
                citations: record.response.citations
            )
            try KnowledgeStore(url: try Self.knowledgeStoreURL()).keep(claim)
            reloadKnowledgeClaims()
            conversationError = nil
        } catch { conversationError = "This local answer could not be retained as citation-bound knowledge." }
    }

    func reloadKnowledgeClaims() {
        do { knowledgeClaims = try KnowledgeStore(url: try Self.knowledgeStoreURL()).load() }
        catch { knowledgeClaims = [] }
    }

    func keepContradictionCandidate() {
        guard let left = knowledgeClaims.first(where: { $0.id == contradictionLeftID }),
              let right = knowledgeClaims.first(where: { $0.id == contradictionRightID }) else {
            knowledgeError = "Choose two different kept knowledge claims."
            return
        }
        do {
            let candidate = try ContradictionCandidate(
                id: GoldenRetrievalManifest.sha256(of: Data(("contradiction|\(left.id)|\(right.id)|\(contradictionSteelman)").utf8)),
                left: left,
                right: right,
                steelman: contradictionSteelman,
                bridgeSuggestion: contradictionBridgeSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contradictionBridgeSuggestion
            )
            try ContradictionStore(url: try Self.contradictionStoreURL()).keep(candidate)
            reloadContradictionCandidates()
            knowledgeError = nil
        } catch { knowledgeError = "Add a steelman and choose two different kept claims." }
    }

    func reloadContradictionCandidates() {
        do { contradictionCandidates = try ContradictionStore(url: try Self.contradictionStoreURL()).load() }
        catch { contradictionCandidates = [] }
    }

    func promoteConversationToTask() {
        guard let conversationRecord else { return }
        do {
            let proposal = try ConversationCoordinator().promoteToTask(
                conversationRecord,
                title: "Review: \(conversationRecord.response.text.prefix(60))",
                acceptanceCriteria: ["Review every cited local source before completing this task."],
                authority: .localRead
            )
            let databaseURL = try LocalConversationContextProvider.defaultDatabaseURL()
            try TaskStore(databaseURL: databaseURL).save(proposal)
            promotedTask = proposal
            reloadTasks()
            conversationError = nil
        } catch {
            conversationError = "Keep a cited local answer before promoting it to a task."
        }
    }

    func reloadTasks() {
        reloadWorkspace()
    }

    func reloadLibrary() {
        reloadWorkspace()
    }

    func selectLibrarySource(_ sourceID: String) {
        if selectedLibrarySourceID != sourceID {
            rawSourceInspection = nil
        }
        selectedLibrarySourceID = sourceID
        libraryError = nil
    }

    func openLibrarySource(for citation: Citation) {
        guard let row = libraryPresentation.row(for: citation) else {
            libraryError = "That citation is not available in the current local library."
            return
        }
        selectLibrarySource(row.id)
        selection = .library
    }

    func inspectRawLibrarySource(_ sourceID: String) {
        let normalizedSourceID = sourceID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedSourceID.isEmpty else {
            libraryError = "The local source identity is invalid."
            return
        }
        let databaseURL: URL
        let contentURL: URL
        do {
            databaseURL = try LocalVaultPaths.databaseURL()
            contentURL = try LocalVaultPaths.contentURL()
        } catch {
            libraryError = "The immutable local source could not be inspected."
            return
        }
        isInspectingRawSource = true
        rawSourceInspection = nil
        libraryError = nil
        Task { [weak self] in
            do {
                let inspection = try await Task.detached {
                    let queue = try IngestQueue(
                        databaseURL: databaseURL,
                        contentStore: try ContentStore(
                            rootDirectory: contentURL
                        ),
                        extractors: .localDefaults
                    )
                    return try queue.inspectRawSource(
                        for: ContentID(rawValue: normalizedSourceID)
                    )
                }.value
                guard self?.selectedLibrarySourceID == normalizedSourceID else {
                    self?.isInspectingRawSource = false
                    return
                }
                self?.rawSourceInspection = inspection
                self?.libraryError = nil
                self?.isInspectingRawSource = false
            } catch {
                self?.libraryError =
                    "Inspection stopped because the immutable local source could not be verified."
                self?.isInspectingRawSource = false
            }
        }
    }

    func setLibrarySourceLifecycle(
        _ lifecycle: SourceLifecycle,
        sourceID: String
    ) {
        let normalizedSourceID = sourceID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedSourceID.isEmpty else {
            libraryError = "The local source identity is invalid."
            return
        }
        let databaseURL: URL
        let contentURL: URL
        do {
            databaseURL = try LocalVaultPaths.databaseURL()
            contentURL = try LocalVaultPaths.contentURL()
        } catch {
            libraryError = "The local source lifecycle could not be updated."
            return
        }
        isUpdatingLibraryLifecycle = true
        libraryError = nil
        Task { [weak self] in
            do {
                try await Task.detached {
                    let queue = try IngestQueue(
                        databaseURL: databaseURL,
                        contentStore: try ContentStore(
                            rootDirectory: contentURL
                        ),
                        extractors: .localDefaults
                    )
                    try queue.setLifecycle(
                        lifecycle,
                        for: ContentID(rawValue: normalizedSourceID)
                    )
                }.value
                if self?.selectedLibrarySourceID == normalizedSourceID {
                    self?.rawSourceInspection = nil
                }
                self?.libraryError = nil
                self?.isUpdatingLibraryLifecycle = false
                self?.reloadLibrary()
            } catch {
                self?.libraryError =
                    "The local source lifecycle could not be updated."
                self?.isUpdatingLibraryLifecycle = false
            }
        }
    }

    private func reloadWorkspace() {
        do {
            let databaseURL = try LocalVaultPaths.databaseURL(); let contentURL = try LocalVaultPaths.contentURL()
            isRefreshingWorkspace = true
            Task { [weak self] in
                do { let value = try await Task.detached { (try LocalWorkspaceReader.tasks(databaseURL: databaseURL), try LocalWorkspaceReader.library(databaseURL: databaseURL, contentRootURL: contentURL)) }.value; self?.taskPresentation = value.0; self?.libraryPresentation = value.1; self?.taskError = nil; self?.libraryError = nil }
                catch { self?.taskError = "Local tasks could not be read."; self?.libraryError = "Local library could not be read." }
                self?.isRefreshingWorkspace = false
            }
        } catch {
            taskPresentation = TaskListPresentation(records: [])
            taskError = "Local tasks could not be read."
            libraryError = "Local library could not be read."
        }
    }

    func completeTask(_ taskID: String) {
        do {
            try TaskStore(databaseURL: LocalVaultPaths.databaseURL()).updateStatus(.completed, for: taskID)
            reloadTasks()
        } catch {
            taskError = "Local task status could not be updated."
        }
    }

    func assessMacCareReadOnly() {
        isMacCareAssessing = true; macCareError = nil
        Task { [weak self] in
            do { let assessment = try await Task.detached { try MacCareReadOnlyOperation.inspectStandardLocations() }.value; self?.macCarePresentation = MacCarePresentation(assessment: assessment) }
            catch { self?.macCarePresentation = nil; self?.macCareError = "Mac Care assessment could not be completed locally." }
            self?.isMacCareAssessing = false
        }
    }

    func captureCurrentClipboard() {
        guard let envelope = ClipboardCapture.readCurrent() else {
            captureMessage = "Clipboard has no plain text to capture."
            return
        }
        do {
            let databaseURL = try LocalVaultPaths.databaseURL()
            let contentStore = try ContentStore(rootDirectory: LocalVaultPaths.contentURL())
            let queue = try IngestQueue(
                databaseURL: databaseURL,
                contentStore: contentStore,
                extractors: .localDefaults
            )
            let receipt = try CaptureService(queue: queue).capture(envelope)
            _ = try queue.processNext()
            captureMessage = receipt.wasDuplicateSource
                ? "Clipboard is already in your local vault."
                : "Clipboard captured and indexed locally."
        } catch {
            captureMessage = "Clipboard could not be captured locally."
        }
    }

    func registerHotkeys() {
        do {
            let configuration = try HotkeyConfiguration(
                openAssistant: HotkeyShortcut(key: hotkeyOpenKey, modifiers: [.command, .option]),
                captureClipboard: HotkeyShortcut(key: hotkeyCaptureKey, modifiers: [.command, .option])
            )
            try hotkeyManager.register(configuration: configuration) { [weak self] action in
                guard let self else { return }
                switch action {
                case .openAssistant:
                    self.selection = .assistant
                    NSRunningApplication.current.activate()
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                case .captureClipboard:
                    self.captureCurrentClipboard()
                }
            }
            hotkeyError = nil
            hotkeyStatus = .active
        } catch {
            hotkeyError = "Global hotkeys could not be registered."
            hotkeyStatus = .unavailable
        }
    }

    func saveAndRegisterHotkeys() {
        do {
            let configuration = try HotkeyConfiguration(openAssistant: HotkeyShortcut(key: hotkeyOpenKey, modifiers: [.command, .option]), captureClipboard: HotkeyShortcut(key: hotkeyCaptureKey, modifiers: [.command, .option]))
            try HotkeyConfigurationStore(url: try LocalVaultPaths.rootURL().appending(path: "hotkeys.json")).save(configuration)
            registerHotkeys()
        } catch { hotkeyError = "Hotkey configuration could not be saved." }
    }

    func reloadWatchedSources() {
        guard let watchedSourceService else {
            watchedSourcePresentation = []
            watchedSourceError = "Watched source settings could not be opened locally."
            return
        }
        isUpdatingWatchedSources = true
        Task { [weak self] in
            do {
                let presentation = try await Task.detached {
                    try watchedSourceService.reload()
                    return watchedSourceService.presentations()
                }.value
                self?.watchedSourcePresentation = presentation
                self?.watchedSourceError = nil
            } catch {
                self?.watchedSourceError = "Watched source settings could not be updated locally."
            }
            self?.isUpdatingWatchedSources = false
        }
    }

    func addWatchedSource(path: String) {
        guard let watchedSourceService else { return }
        isUpdatingWatchedSources = true
        Task { [weak self] in
            do {
                let presentation = try await Task.detached {
                    _ = try watchedSourceService.add(path: path)
                    return watchedSourceService.presentations()
                }.value
                self?.watchedSourcePresentation = presentation
                self?.watchedSourceError = nil
            } catch {
                self?.watchedSourceError = "That folder is already configured or could not be saved locally."
            }
            self?.isUpdatingWatchedSources = false
        }
    }

    func setWatchedSourceEnabled(_ isEnabled: Bool, sourceID: UUID) {
        guard let watchedSourceService else { return }
        isUpdatingWatchedSources = true
        Task { [weak self] in
            do {
                let presentation = try await Task.detached {
                    try watchedSourceService.setEnabled(isEnabled, for: sourceID)
                    return watchedSourceService.presentations()
                }.value
                self?.watchedSourcePresentation = presentation
                self?.watchedSourceError = nil
            } catch {
                self?.watchedSourceError = "The watched source could not be updated locally."
            }
            self?.isUpdatingWatchedSources = false
        }
    }

    func removeWatchedSource(_ sourceID: UUID) {
        guard let watchedSourceService else { return }
        isUpdatingWatchedSources = true
        Task { [weak self] in
            do {
                let presentation = try await Task.detached {
                    try watchedSourceService.remove(sourceID)
                    return watchedSourceService.presentations()
                }.value
                self?.watchedSourcePresentation = presentation
                self?.watchedSourceError = nil
            } catch {
                self?.watchedSourceError = "The watched source could not be removed locally."
            }
            self?.isUpdatingWatchedSources = false
        }
    }

    private nonisolated static func makeWatchedSourceService() -> WatchedSourceService? {
        do {
            let store = WatchedSourceConfigurationStore(
                url: try LocalVaultPaths.rootURL().appending(path: "watched-sources.json")
            )
            let manager = WatchedSourceManager { envelope in
                do {
                    let queue = try IngestQueue(
                        databaseURL: LocalVaultPaths.databaseURL(),
                        contentStore: try ContentStore(rootDirectory: LocalVaultPaths.contentURL()),
                        extractors: .localDefaults
                    )
                    _ = try CaptureService(queue: queue).capture(envelope)
                    _ = try queue.processNext()
                    try queue.close()
                } catch {}
            }
            return WatchedSourceService(store: store, manager: manager)
        } catch {
            return nil
        }
    }

    private nonisolated static func makeRepositorySourceService() -> RepositorySourceService? {
        do {
            return RepositorySourceService(
                store: RepositorySourceConfigurationStore(
                    url: try LocalVaultPaths.rootURL().appending(path: "repository-sources.json")
                )
            )
        } catch {
            return nil
        }
    }

    private nonisolated static func researchPlanStoreURL() throws -> URL {
        try LocalVaultPaths.rootURL().appending(path: "research-plans.json")
    }

    private nonisolated static func knowledgeStoreURL() throws -> URL {
        try LocalVaultPaths.rootURL().appending(path: "knowledge-claims.json")
    }

    private nonisolated static func contradictionStoreURL() throws -> URL {
        try LocalVaultPaths.rootURL().appending(path: "contradictions.json")
    }

    private func loadHotkeyConfiguration() {
        guard let url = try? LocalVaultPaths.rootURL().appending(path: "hotkeys.json"), let configuration = try? HotkeyConfigurationStore(url: url).load() else { return }
        hotkeyOpenKey = configuration.openAssistant.key; hotkeyCaptureKey = configuration.captureClipboard.key
    }

    func inspectSelectedRepository() {
        let path = repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            repositoryError = "Enter a local Git repository path to inspect."
            repositoryPresentation = nil
            return
        }
        do {
            let snapshot = try RepositoryModule().intake(root: URL(filePath: path))
            repositoryPresentation = RepositoryPresentation(snapshot: snapshot)
            repositorySnapshot = snapshot
            repositoryIndexPresentation = nil
            clearRepositoryReview()
            repositoryError = nil
        } catch {
            repositoryPresentation = nil
            repositorySnapshot = nil
            clearRepositoryReview()
            repositoryError = "This path could not be inspected as a local Git repository."
        }
    }

    func reloadRepositorySources() {
        guard let repositorySourceService else {
            repositorySources = []
            return
        }
        do {
            repositorySources = try repositorySourceService.reload()
        } catch {
            repositorySources = []
            repositoryError = "Saved repository sources could not be read locally."
        }
    }

    func saveRepositorySource() {
        guard let repositorySourceService else {
            repositoryError = "Saved repository sources could not be opened locally."
            return
        }
        do {
            _ = try repositorySourceService.add(path: repositoryPath)
            repositorySources = try repositorySourceService.reload()
            repositoryError = nil
        } catch {
            repositoryError = "Enter a new local repository path to save it as a source."
        }
    }

    func selectRepositorySource(_ source: RepositorySource) {
        repositoryPath = source.canonicalPath
    }

    func removeRepositorySource(_ sourceID: UUID) {
        guard let repositorySourceService else { return }
        do {
            try repositorySourceService.remove(sourceID)
            repositorySources = try repositorySourceService.reload()
            repositoryError = nil
        } catch {
            repositoryError = "The saved repository source could not be removed locally."
        }
    }

    func indexSelectedRepository() {
        let path = repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            repositoryError = "Enter a local Git repository path to index."
            repositoryIndexPresentation = nil
            return
        }
        let databaseURL: URL
        let contentRootURL: URL
        do {
            databaseURL = try LocalVaultPaths.databaseURL()
            contentRootURL = try LocalVaultPaths.contentURL()
        } catch {
            repositoryIndexPresentation = nil
            repositoryError = "Committed repository sources could not be indexed locally."
            return
        }
        let root = URL(filePath: path)
        isRepositoryIndexing = true
        let cancellation = RepositoryIndexCancellation()
        repositoryIndexCancellation = cancellation
        repositoryError = nil
        Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try RepositoryLocalIndexOperation.index(
                        root: root,
                        databaseURL: databaseURL,
                        contentRootURL: contentRootURL,
                        shouldCancel: { cancellation.isCancelled }
                    )
                }.value
                self?.repositoryPresentation = RepositoryPresentation(snapshot: result.snapshot)
                self?.repositorySnapshot = result.snapshot
                self?.repositoryIndexPresentation = RepositoryIndexPresentation(result: result)
                self?.clearRepositoryReview()
            } catch RepositoryIncrementalIndexError.cancelled {
                self?.repositoryError = "Repository indexing was cancelled; no new snapshot receipt was saved."
            } catch {
                self?.repositoryIndexPresentation = nil
                self?.repositoryError = "Committed repository sources could not be indexed locally."
            }
            self?.isRepositoryIndexing = false
            self?.repositoryIndexCancellation = nil
        }
    }

    func cancelRepositoryIndexing() {
        repositoryIndexCancellation?.cancel()
    }

    func scanSelectedRepositoryObservations() {
        guard let snapshot = repositorySnapshot else {
            repositoryError = "Inspect a local repository before scanning committed observations."
            return
        }
        isScanningRepositoryObservations = true
        repositoryError = nil
        let root = URL(filePath: snapshot.canonicalPath)
        Task { [weak self] in
            do {
                let observations = try await Task.detached(priority: .userInitiated) {
                    try RepositoryObservationExtractor().extract(root: root, snapshot: snapshot)
                }.value
                self?.repositoryObservationEvidence = observations
                self?.repositoryObservations = observations.map(RepositoryObservationPresentation.init)
                self?.selectedRepositoryObservationID = nil
                self?.repositoryIdeaProposal = nil
                self?.repositoryIdeaCard = nil
                self?.repositoryIdeaTask = nil
                self?.repositoryIdeaResearchPlan = nil
                self?.repositoryIdeaDisposition = nil
            } catch {
                self?.repositoryObservationEvidence = []
                self?.repositoryObservations = []
                self?.selectedRepositoryObservationID = nil
                self?.repositoryError = "Committed observations require a clean, reproducible repository snapshot."
            }
            self?.isScanningRepositoryObservations = false
        }
    }

    func createRepositoryIdeaProposal() {
        guard let snapshot = repositorySnapshot,
              let selectedID = selectedRepositoryObservationID,
              let evidence = repositoryObservationEvidence.first(where: {
                  RepositoryObservationPresentation(observation: $0).id == selectedID
              }) else {
            repositoryError = "Select one commit-cited observation before creating a proposal-only idea."
            return
        }
        do {
            let draft = try RepositoryIdeaDraft(
                title: repositoryIdeaTitle,
                counterevidence: repositoryIdeaCounterevidence,
                validationExperiment: repositoryIdeaValidationExperiment
            )
            let card = try RepositoryIdeaCard(
                id: UUID().uuidString,
                title: draft.title,
                evidence: [evidence],
                counterevidence: [draft.counterevidence],
                confidence: 0.5,
                license: snapshot.license ?? "Unknown",
                validationExperiment: draft.validationExperiment
            )
            repositoryIdeaProposal = try card.promote(snapshot: snapshot)
            repositoryIdeaCard = card
            repositoryIdeaTask = nil
            repositoryIdeaResearchPlan = nil
            repositoryIdeaDisposition = nil
            repositoryError = nil
        } catch {
            repositoryIdeaProposal = nil
            repositoryIdeaCard = nil
            repositoryIdeaTask = nil
            repositoryIdeaResearchPlan = nil
            repositoryIdeaDisposition = nil
            repositoryError = "Enter a title, counterevidence, and a smallest validation experiment for a clean selected snapshot."
        }
    }

    func retainRepositoryIdea(_ disposition: RepositoryIdeaDisposition) {
        guard let snapshot = repositorySnapshot,
              let card = repositoryIdeaCard,
              repositoryIdeaProposal != nil else {
            repositoryError = "Create a proposal-only idea from a clean selected snapshot before keeping or rejecting it."
            return
        }
        do {
            try RepositoryIdeaStore(databaseURL: LocalVaultPaths.databaseURL())
                .save(card, snapshot: snapshot, disposition: disposition)
            repositoryIdeaDisposition = disposition
            if disposition == .rejected { repositoryIdeaTask = nil }
            reloadRepositoryIdeaHistory()
            repositoryError = nil
        } catch {
            repositoryError = "This repository idea could not be retained with its cited snapshot evidence."
        }
    }

    func saveRepositoryIdeaAsLocalTask() {
        guard let snapshot = repositorySnapshot,
              let card = repositoryIdeaCard,
              repositoryIdeaProposal != nil,
              repositoryIdeaDisposition != .rejected else {
            repositoryError = "Create a proposal-only idea from a clean selected snapshot before saving a local task."
            return
        }
        do {
            let task = try card.localTask(snapshot: snapshot)
            try TaskStore(databaseURL: LocalVaultPaths.databaseURL()).save(task)
            repositoryIdeaTask = task
            reloadTasks()
            repositoryError = nil
        } catch {
            repositoryIdeaTask = nil
            repositoryError = "This repository idea could not be saved as a cited local task."
        }
    }

    func createRepositoryIdeaResearchPlan() {
        guard let snapshot = repositorySnapshot,
              let card = repositoryIdeaCard,
              repositoryIdeaProposal != nil,
              repositoryIdeaDisposition != .rejected else {
            repositoryError = "Create a proposal-only idea from a clean selected snapshot before creating a local research plan."
            return
        }
        do {
            let run = try card.localResearchPlan(snapshot: snapshot)
            try ResearchPlanStore(url: try Self.researchPlanStoreURL()).keep(run)
            repositoryIdeaResearchPlan = run
            currentResearchRun = run
            researchPresentation = ResearchPresentation(run: run)
            researchQuery = run.queries.joined(separator: " ")
            reloadRetainedResearchPlans()
            repositoryError = nil
            selection = .research
        } catch {
            repositoryIdeaResearchPlan = nil
            repositoryError = "This repository idea could not be created as a cited local research plan."
        }
    }

    func saveRepositoryIdeaAsCodexPlan() {
        guard let snapshot = repositorySnapshot, let card = repositoryIdeaCard,
              repositoryIdeaProposal != nil, repositoryIdeaDisposition != .rejected else {
            repositoryError = "Create a proposal-only idea from a clean selected snapshot before saving a Codex plan handoff."
            return
        }
        do {
            let plan = try card.localCodexPlan(snapshot: snapshot)
            try TaskStore(databaseURL: LocalVaultPaths.databaseURL()).save(plan)
            repositoryIdeaCodexPlan = plan
            reloadTasks()
            repositoryError = nil
        } catch { repositoryIdeaCodexPlan = nil; repositoryError = "This repository idea could not be saved as a cited Codex plan handoff." }
    }

    func reloadRepositoryIdeaHistory() {
        do {
            repositoryIdeaHistory = RepositoryIdeaListPresentation(
                records: try RepositoryIdeaStore(databaseURL: LocalVaultPaths.databaseURL()).all()
            )
        } catch {
            repositoryIdeaHistory = RepositoryIdeaListPresentation(records: [])
        }
    }

    private func clearRepositoryReview() {
        repositoryObservationEvidence = []
        repositoryObservations = []
        selectedRepositoryObservationID = nil
        repositoryIdeaTitle = ""
        repositoryIdeaCounterevidence = ""
        repositoryIdeaValidationExperiment = ""
        repositoryIdeaProposal = nil
        repositoryIdeaCard = nil
        repositoryIdeaTask = nil
        repositoryIdeaResearchPlan = nil
        repositoryIdeaCodexPlan = nil
        repositoryIdeaDisposition = nil
    }
}
