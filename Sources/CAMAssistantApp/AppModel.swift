import CAMAssistantCore
import AppKit
import SwiftUI

enum AssistantSection: String, CaseIterable, Identifiable {
    case assistant = "Assistant"
    case meaningPreview = "Meaning Preview"
    case library = "Library"
    case activity = "Activity"
    case tasks = "Tasks"
    case modules = "Modules"
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
        case .meaningPreview:
            "lightbulb.max"
        case .library:
            "books.vertical"
        case .activity:
            "clock.arrow.circlepath"
        case .tasks:
            "checklist"
        case .modules:
            "puzzlepiece.extension"
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

struct PackagedTextSummaryPresentation: Equatable {
    let isInstalled: Bool
    let isEnabled: Bool
    let hasLocalTextGrant: Bool
    let statusLabel: String

    static let notInstalled = PackagedTextSummaryPresentation(
        isInstalled: false,
        isEnabled: false,
        hasLocalTextGrant: false,
        statusLabel: "Not installed. Installing does not grant access."
    )
}

enum MeaningPreviewLifecycle: String, Sendable, Equatable {
    case disabled
    case enabledWithoutLocalRead
    case ready
    case corruptedStore
    case incompatibleStore
    case unavailable
}

enum MeaningPreviewCardAction: String, Sendable, Equatable, CaseIterable {
    case now
    case later
    case release
}

enum MeaningPreviewFeedback: String, Sendable, Equatable, CaseIterable {
    case helpful
    case notHelpful
}

struct MeaningPreviewSourceReference: Sendable, Equatable {
    let id: String
}

struct MeaningPreviewResolvedContext: Sendable, Equatable {
    let id: String
    let derivedText: String
    let observedAt: Date
    let domain: String
    let uncertainty: MeaningContextUncertainty
    let sensitivity: MeaningContextSensitivity
    let permittedUses: Set<MeaningContextPermittedUse>
    let isVisible: Bool
    let isActive: Bool
    let isSupported: Bool
}

protocol MeaningPreviewSourceResolving: Sendable {
    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext
}

struct MeaningPreviewLiveSourceResolver: MeaningPreviewSourceResolving {
    static let maximumDerivedContextCharacters = 4_096
    let root: URL

    func resolve(_ reference: MeaningPreviewSourceReference) async throws
        -> MeaningPreviewResolvedContext {
        let root = root
        return try await Task.detached {
            let queue = try IngestQueue(
                databaseURL: root.appending(path: "vault.sqlite"),
                contentStore: try ContentStore(
                    rootDirectory: root.appending(
                        path: "content",
                        directoryHint: .isDirectory
                    )
                ),
                extractors: .localDefaults
            )
            defer { try? queue.close() }
            let sourceID = ContentID(rawValue: reference.id)
            guard try queue.lifecycle(for: sourceID) == .active,
                  let document = try queue.documents().first(where: {
                      $0.sourceID == sourceID
                  }),
                  !document.text.trimmingCharacters(
                      in: .whitespacesAndNewlines
                  ).isEmpty else {
                throw MeaningPreviewRuntimeError.sourceUnavailable
            }
            let classification = DataClassifier().classify(document.text)
            let sensitivity: MeaningContextSensitivity = switch
                classification.riskClass {
            case .restricted, .proprietary: .restricted
            case .contextual: .personal
            case .public, .generic: .ordinary
            }
            return MeaningPreviewResolvedContext(
                id: document.sourceID.rawValue,
                derivedText: String(
                    document.text.prefix(Self.maximumDerivedContextCharacters)
                ),
                observedAt: document.capturedAt,
                domain: "selected local source",
                uncertainty: .tentative,
                sensitivity: sensitivity,
                permittedUses: [.meaningPreview],
                isVisible: true,
                isActive: true,
                isSupported: true
            )
        }.value
    }
}

struct MeaningPreviewCardPresentation: Sendable, Equatable {
    let id: UUID
    let text: String
}

struct MeaningPreviewInspectPresentation: Sendable, Equatable {
    let summary: String
    let evidenceIDs: [String]
    let counterevidenceIDs: [String]
    let provenanceLabel: String
    let uncertaintyLabel: String
    let whySurfaced: String
    var exclusionLabels: [String] = []
}

struct MeaningPreviewAppPresentation: Sendable, Equatable {
    let version: UInt64
    var domain: String? = nil
    let card: MeaningPreviewCardPresentation?
    let inspect: MeaningPreviewInspectPresentation

    func updatingVersion(_ version: UInt64) -> Self {
        .init(version: version, domain: domain, card: card, inspect: inspect)
    }
}

struct MeaningPreviewRecoveryReceipt: Sendable, Equatable {
    let lifecycle: MeaningPreviewLifecycle
    let archivedPreviousState: Bool
}

enum MeaningPreviewRuntimeError: Error, Equatable {
    case accessDenied
    case disabledDuringRequest
    case noActivePresentation
    case stalePresentation
    case sourceUnavailable
}

protocol MeaningPreviewRuntime: Sendable {
    var initialLifecycle: MeaningPreviewLifecycle { get }
    func loadLifecycle() async -> MeaningPreviewLifecycle
    func enable() async throws -> MeaningPreviewLifecycle
    func grantLocalAccess() async throws -> MeaningPreviewLifecycle
    func disable() async throws -> MeaningPreviewLifecycle
    func recover() async throws -> MeaningPreviewRecoveryReceipt
    func request(
        reference: MeaningPreviewSourceReference,
        now: Date
    ) async throws -> MeaningPreviewAppPresentation
    func applyAction(
        _ action: MeaningPreviewCardAction,
        memoryID: UUID,
        expectedVersion: UInt64,
        at: Date
    ) async throws -> UInt64
    func recordFeedback(
        _ feedback: MeaningPreviewFeedback,
        memoryID: UUID,
        domain: String,
        expectedVersion: UInt64
    ) async throws -> UInt64
}

protocol MeaningPreviewReflectiveRuntime: Sendable {
    var reflectionInitiallyAvailable: Bool { get }
    func requestReflection(
        references: [MeaningPreviewSourceReference],
        now: Date
    ) async throws -> MeaningPreviewReflectivePresentation?
}

private struct MeaningPreviewAuthorizationLease: Sendable, Equatable {
    let epoch: UInt64
}

private final class MeaningPreviewAuthorizationGate: @unchecked Sendable {
    // Serializes the app-owned enable/grant/disable path with Preview saves.
    // The module state file is not an inter-process revocation protocol; an
    // external writer must not mutate it while the native app owns the pilot.
    private let lock = NSLock()
    private var epoch: UInt64 = 0
    private var authorized = false

    func authorize() -> MeaningPreviewAuthorizationLease {
        lock.lock()
        defer { lock.unlock() }
        authorized = true
        return MeaningPreviewAuthorizationLease(epoch: epoch)
    }

    func invalidate() {
        lock.lock()
        epoch &+= 1
        authorized = false
        lock.unlock()
    }

    func withValidLease<T>(
        _ lease: MeaningPreviewAuthorizationLease,
        _ operation: () throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard authorized, lease.epoch == epoch else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        return try operation()
    }
}

private final class MeaningPreviewLeaseCheckingStore:
    MeaningPreviewStateStoring, @unchecked Sendable {
    private let underlying: MeaningPreviewStore
    private let gate: MeaningPreviewAuthorizationGate
    private let beforeSave: @Sendable () -> Void
    private let lock = NSLock()
    private var lease: MeaningPreviewAuthorizationLease?

    init(
        underlying: MeaningPreviewStore,
        gate: MeaningPreviewAuthorizationGate,
        beforeSave: @escaping @Sendable () -> Void
    ) {
        self.underlying = underlying
        self.gate = gate
        self.beforeSave = beforeSave
    }

    func install(_ lease: MeaningPreviewAuthorizationLease) {
        lock.lock()
        self.lease = lease
        lock.unlock()
    }

    func load() throws -> MeaningPreviewSnapshot {
        try underlying.load()
    }

    func save(_ snapshot: MeaningPreviewSnapshot) throws {
        lock.lock()
        let current = lease
        lock.unlock()
        guard let current else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        beforeSave()
        try gate.withValidLease(current) {
            try underlying.save(snapshot)
        }
    }
}

private struct MeaningPreviewModuleStateSnapshot: Codable {
    let enabledModuleIDs: Set<String>
    let permissionGrants: [String: Set<Permission>]
}

actor MeaningPreviewLiveRuntime: MeaningPreviewRuntime {
    nonisolated let initialLifecycle: MeaningPreviewLifecycle
    nonisolated let reflectionInitiallyAvailable: Bool

    private let root: URL
    private let manifestDirectory: URL
    private let sourceResolver: any MeaningPreviewSourceResolving
    private let beforePreviewSave: @Sendable () -> Void
    private let reflectionReportURL: URL
    private let reflectionAssignmentProvider:
        @Sendable () throws -> ModelAssignment
    private let reflectionTransport: (any LocalModelTransport)?
    private let authorizationGate = MeaningPreviewAuthorizationGate()
    private var coordinator: MeaningPreviewCoordinator?
    private var leaseStore: MeaningPreviewLeaseCheckingStore?
    private var activePresentation: (memoryID: UUID, domain: String, version: UInt64)?
    private var generation = UUID()

    init(
        root: URL,
        manifestDirectory: URL? = nil,
        sourceResolver: (any MeaningPreviewSourceResolving)? = nil,
        reflectionReportURL: URL? = nil,
        reflectionAssignmentProvider:
            @escaping @Sendable () throws -> ModelAssignment = {
                try MeaningPreviewLiveRuntime.activeLocalAssignment()
            },
        reflectionTransport: (any LocalModelTransport)? = nil,
        beforePreviewSave: @escaping @Sendable () -> Void = {}
    ) {
        self.root = root
        self.manifestDirectory = manifestDirectory
            ?? Self.defaultManifestDirectory()
        self.sourceResolver = sourceResolver
            ?? MeaningPreviewLiveSourceResolver(root: root)
        self.beforePreviewSave = beforePreviewSave
        self.reflectionReportURL = reflectionReportURL
            ?? Self.defaultReflectionReportURL()
        self.reflectionAssignmentProvider = reflectionAssignmentProvider
        self.reflectionTransport = reflectionTransport
        self.initialLifecycle = (
            try? Self.readLifecycle(
                root: root,
                manifestDirectory: self.manifestDirectory
            )
        ) ?? .unavailable
        self.reflectionInitiallyAvailable = Self.hasCurrentReflectionAdmission(
            reportURL: self.reflectionReportURL,
            assignmentProvider: reflectionAssignmentProvider,
            now: Date()
        )
    }

    func loadLifecycle() -> MeaningPreviewLifecycle {
        (try? currentLifecycle()) ?? .unavailable
    }

    func enable() throws -> MeaningPreviewLifecycle {
        let registry = try makeRegistry()
        try registry.enable("cam.meaning-preview")
        authorizationGate.invalidate()
        return try currentLifecycle()
    }

    func grantLocalAccess() throws -> MeaningPreviewLifecycle {
        let registry = try makeRegistry()
        try registry.grant(
            [.readLocal, .writeLocal],
            to: "cam.meaning-preview"
        )
        authorizationGate.invalidate()
        return try currentLifecycle()
    }

    func disable() throws -> MeaningPreviewLifecycle {
        authorizationGate.invalidate()
        let registry = try makeRegistry()
        try registry.disable("cam.meaning-preview")
        generation = UUID()
        activePresentation = nil
        coordinator = nil
        leaseStore = nil
        return .disabled
    }

    func recover() throws -> MeaningPreviewRecoveryReceipt {
        let lifecycle = try currentLifecycle()
        guard lifecycle == .corruptedStore
            || lifecycle == .incompatibleStore else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        authorizationGate.invalidate()
        generation = UUID()
        activePresentation = nil
        coordinator = nil
        leaseStore = nil

        let databaseURL = LocalVaultPaths.meaningPreviewDatabaseURL(
            vaultRoot: root
        )
        let stateDirectory = databaseURL.deletingLastPathComponent()
        let archiveRoot = root.appending(
            path: "meaning-preview-archive",
            directoryHint: .isDirectory
        )
        let archiveDirectory = archiveRoot.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        let hadPreviousState = FileManager.default.fileExists(
            atPath: stateDirectory.path
        )

        if hadPreviousState {
            try FileManager.default.createDirectory(
                at: archiveRoot,
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(
                at: stateDirectory,
                to: archiveDirectory
            )
        }

        do {
            _ = try MeaningPreviewStore(databaseURL: databaseURL)
        } catch {
            if FileManager.default.fileExists(atPath: stateDirectory.path) {
                try? FileManager.default.removeItem(at: stateDirectory)
            }
            if hadPreviousState {
                try? FileManager.default.moveItem(
                    at: archiveDirectory,
                    to: stateDirectory
                )
            }
            throw error
        }

        return MeaningPreviewRecoveryReceipt(
            lifecycle: try currentLifecycle(),
            archivedPreviousState: hadPreviousState
        )
    }

    func request(
        reference: MeaningPreviewSourceReference,
        now: Date
    ) async throws -> MeaningPreviewAppPresentation {
        guard try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        let requestGeneration = generation
        let selected = try await sourceResolver.resolve(reference)
        guard selected.id == reference.id else {
            throw MeaningPreviewRuntimeError.sourceUnavailable
        }
        guard requestGeneration == generation,
              try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.disabledDuringRequest
        }

        let scopedDomain = Self.scopedDomain(for: selected)
        let lease = authorizationGate.authorize()
        let activeCoordinator = try makeCoordinatorIfNeeded(lease: lease)
        let result = try await activeCoordinator.requestPractical(
            access: MeaningPreviewAccess(enabled: true, localDataGranted: true),
            selection: {
                MeaningContextSelection(
                    purpose: "explicit practical preview",
                    domain: scopedDomain,
                    capacity: .adequate,
                    selectedItems: [
                        MeaningContextItem(
                            id: selected.id,
                            sourceID: selected.id,
                            derivedText: selected.derivedText,
                            observedAt: selected.observedAt,
                            uncertainty: selected.uncertainty,
                            sensitivity: selected.sensitivity,
                            permittedUses: selected.permittedUses,
                            isVisible: selected.isVisible,
                            isActive: selected.isActive,
                            isSupported: selected.isSupported
                        ),
                    ]
                )
            },
            now: now
        )
        guard requestGeneration == generation,
              try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.disabledDuringRequest
        }

        let item = result.glance.item
        activePresentation = item.map {
            (memoryID: $0.id, domain: scopedDomain, version: result.version)
        }
        return MeaningPreviewAppPresentation(
            version: result.version,
            domain: item == nil ? nil : scopedDomain,
            card: item.map {
                MeaningPreviewCardPresentation(id: $0.id, text: $0.text)
            },
            inspect: MeaningPreviewInspectPresentation(
                summary: result.inspect.summary,
                evidenceIDs: result.inspect.evidence.map { $0.uuidString },
                counterevidenceIDs: result.inspect.counterevidence.map { $0.uuidString },
                provenanceLabel: item.map {
                    Self.provenanceLabel($0.source.rawValue)
                } ?? "Unavailable",
                uncertaintyLabel: item.map {
                    Self.uncertaintyLabel($0.confidence.rawValue)
                } ?? "Unavailable",
                whySurfaced: result.inspect.whySurfaced,
                exclusionLabels: result.exclusions.values.map { $0.rawValue }.sorted()
            )
        )
    }

    func requestReflection(
        references: [MeaningPreviewSourceReference],
        now: Date
    ) async throws -> MeaningPreviewReflectivePresentation? {
        guard try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        let uniqueReferences = references.sorted { $0.id < $1.id }
        guard (2...8).contains(uniqueReferences.count),
              Set(uniqueReferences.map(\.id)).count == uniqueReferences.count else {
            return nil
        }
        let requestGeneration = generation
        let assignment = try reflectionAssignmentProvider()
        let report = try JSONDecoder().decode(
            MeaningPreviewNamedModelReport.self,
            from: Data(contentsOf: reflectionReportURL)
        )
        guard let admission = MeaningPreviewReflectionAdmission.validated(
            report: report,
            assignment: assignment,
            now: now
        ) else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        let lease = authorizationGate.authorize()
        var resolved: [MeaningPreviewResolvedContext] = []
        resolved.reserveCapacity(uniqueReferences.count)
        for reference in uniqueReferences {
            try Task.checkCancellation()
            resolved.append(try await sourceResolver.resolve(reference))
        }
        try Task.checkCancellation()
        try authorizationGate.withValidLease(lease) {}
        guard requestGeneration == generation,
              try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.disabledDuringRequest
        }
        guard !resolved.contains(where: {
            $0.sensitivity == .restricted
                || $0.derivedText.lowercased().contains("secret")
                || $0.derivedText.lowercased().contains("password")
                || $0.derivedText.lowercased().contains("api key")
        }) else {
            throw MeaningPreviewReflectionError.restrictedContext
        }
        let scopedDomain = "explicit reflection|sources:"
            + uniqueReferences.map(\.id).joined(separator: ",")
        let selection = MeaningContextSelection(
            purpose: "explicit reflective preview",
            domain: scopedDomain,
            capacity: .adequate,
            selectedItems: resolved.map {
                MeaningContextItem(
                    id: $0.id,
                    sourceID: $0.id,
                    derivedText: $0.derivedText,
                    observedAt: $0.observedAt,
                    uncertainty: $0.uncertainty,
                    sensitivity: $0.sensitivity,
                    permittedUses: $0.permittedUses,
                    isVisible: $0.isVisible,
                    isActive: $0.isActive,
                    isSupported: $0.isSupported
                )
            }
        )
        let supplier = try MeaningPreviewLoopbackCandidateSupplier(
            assignment: assignment,
            transport: reflectionTransport
        )
        _ = try await supplier.health()
        try authorizationGate.withValidLease(lease) {}
        guard requestGeneration == generation,
              try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.disabledDuringRequest
        }
        let activeCoordinator = try makeCoordinatorIfNeeded(lease: lease)
        let result = try await activeCoordinator.requestReflective(
            access: .init(enabled: true, localDataGranted: true),
            admission: admission,
            selection: { selection },
            supplier: supplier,
            now: now
        )
        try Task.checkCancellation()
        try authorizationGate.withValidLease(lease) {}
        guard requestGeneration == generation,
              try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.disabledDuringRequest
        }
        return result
    }

    func applyAction(
        _ action: MeaningPreviewCardAction,
        memoryID: UUID,
        expectedVersion: UInt64,
        at: Date
    ) async throws -> UInt64 {
        let (activeCoordinator, lease) = try requireActiveCoordinator(
            memoryID: memoryID,
            domain: nil,
            expectedVersion: expectedVersion
        )
        leaseStore?.install(lease)
        switch action {
        case .now:
            _ = try await activeCoordinator.mutate(
                .action(.now, memoryID: memoryID, at: at),
                expectedVersion: expectedVersion
            )
        case .later:
            _ = try await activeCoordinator.mutate(
                .action(.later, memoryID: memoryID, at: at),
                expectedVersion: expectedVersion
            )
        case .release:
            _ = try await activeCoordinator.mutate(
                .action(.release, memoryID: memoryID, at: at),
                expectedVersion: expectedVersion
            )
        }
        activePresentation = nil
        return expectedVersion + 1
    }

    func recordFeedback(
        _ feedback: MeaningPreviewFeedback,
        memoryID: UUID,
        domain: String,
        expectedVersion: UInt64
    ) async throws -> UInt64 {
        let (activeCoordinator, lease) = try requireActiveCoordinator(
            memoryID: memoryID,
            domain: domain,
            expectedVersion: expectedVersion
        )
        leaseStore?.install(lease)
        switch feedback {
        case .helpful:
            _ = try await activeCoordinator.mutate(
                .utilityOutcome(.helpful, memoryID: memoryID, domain: domain),
                expectedVersion: expectedVersion
            )
        case .notHelpful:
            _ = try await activeCoordinator.mutate(
                .utilityOutcome(.notHelpful, memoryID: memoryID, domain: domain),
                expectedVersion: expectedVersion
            )
        }
        activePresentation = nil
        return expectedVersion + 1
    }

    private func requireActiveCoordinator(
        memoryID: UUID,
        domain: String?,
        expectedVersion: UInt64
    ) throws -> (MeaningPreviewCoordinator, MeaningPreviewAuthorizationLease) {
        guard try currentLifecycle() == .ready else {
            throw MeaningPreviewRuntimeError.accessDenied
        }
        guard let activePresentation, let coordinator else {
            throw MeaningPreviewRuntimeError.noActivePresentation
        }
        guard activePresentation.memoryID == memoryID,
              activePresentation.version == expectedVersion,
              domain == nil || activePresentation.domain == domain else {
            throw MeaningPreviewRuntimeError.stalePresentation
        }
        return (coordinator, authorizationGate.authorize())
    }

    private func makeCoordinatorIfNeeded(
        lease: MeaningPreviewAuthorizationLease
    ) throws -> MeaningPreviewCoordinator {
        if let coordinator {
            leaseStore?.install(lease)
            return coordinator
        }
        let audit = try AuditStore(databaseURL: root.appending(path: "vault.sqlite"))
        let checkedStore = MeaningPreviewLeaseCheckingStore(
            underlying: try MeaningPreviewStore(
                databaseURL: LocalVaultPaths.meaningPreviewDatabaseURL(
                    vaultRoot: root
                )
            ),
            gate: authorizationGate,
            beforeSave: beforePreviewSave
        )
        checkedStore.install(lease)
        let created = try MeaningPreviewCoordinator(
            store: checkedStore,
            auditSink: MeaningPreviewAuditSink(store: audit)
        )
        leaseStore = checkedStore
        coordinator = created
        return created
    }

    private func currentLifecycle() throws -> MeaningPreviewLifecycle {
        try Self.readLifecycle(root: root, manifestDirectory: manifestDirectory)
    }

    private func makeRegistry() throws -> ModuleRegistry {
        try ModuleRegistry(
            manifestDirectory: manifestDirectory,
            stateURL: LocalVaultPaths.stateURL(.moduleState, vaultRoot: root)
        )
    }

    private static func readLifecycle(
        root: URL,
        manifestDirectory: URL
    ) throws -> MeaningPreviewLifecycle {
        let manifest = try ModuleManifest.decodeValidated(
            Data(
                contentsOf: manifestDirectory.appending(
                    path: "meaning-preview.json"
                )
            )
        )
        guard manifest.id == "cam.meaning-preview",
              !manifest.isCore,
              Set(manifest.permissions) == [.readLocal, .writeLocal] else {
            return .unavailable
        }
        let stateURL = LocalVaultPaths.stateURL(.moduleState, vaultRoot: root)
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return .disabled
        }
        let state = try JSONDecoder().decode(
            MeaningPreviewModuleStateSnapshot.self,
            from: Data(contentsOf: stateURL)
        )
        guard state.enabledModuleIDs.contains(manifest.id) else {
            return .disabled
        }
        let granted = state.permissionGrants[manifest.id] ?? []
        guard Set(manifest.permissions).isSubset(of: granted) else {
            return .enabledWithoutLocalRead
        }
        let databaseURL = LocalVaultPaths.meaningPreviewDatabaseURL(
            vaultRoot: root
        )
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .ready
        }
        do {
            _ = try MeaningPreviewStore(databaseURL: databaseURL).load()
            return .ready
        } catch MeaningPreviewStoreError.unsupportedSchema {
            return .incompatibleStore
        } catch MeaningPreviewStoreError.malformedState {
            return .corruptedStore
        } catch let error as SQLiteStoreError {
            return Self.isConfirmedSQLiteCorruption(error)
                ? .corruptedStore : .unavailable
        } catch {
            return .unavailable
        }
    }

    private static func defaultManifestDirectory() -> URL {
        let packaged = Bundle.main.resourceURL?
            .appending(path: "Modules/Core", directoryHint: .isDirectory)
        if let packaged,
           FileManager.default.fileExists(atPath: packaged.path) {
            return packaged
        }
        return URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Modules/Core", directoryHint: .isDirectory)
    }

    private static func provenanceLabel(_ value: String) -> String {
        switch value {
        case "hostImport": "Selected CAM-derived local context"
        case "correction": "Corrected isolated Preview context"
        case "inference": "Inference"
        case "observed": "Observed context"
        case "userStatement": "User-stated context"
        default: "Unavailable"
        }
    }

    private static func uncertaintyLabel(_ value: String) -> String {
        switch value {
        case "supported": "Supported"
        case "tentative": "Tentative"
        case "low": "Low confidence"
        default: "Unavailable"
        }
    }

    private static func scopedDomain(
        for context: MeaningPreviewResolvedContext
    ) -> String {
        let base = context.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(base.isEmpty ? "selected local source" : base)|source:\(context.id)"
    }

    private static func isConfirmedSQLiteCorruption(
        _ error: SQLiteStoreError
    ) -> Bool {
        let message: String = switch error {
        case let .openFailed(value), let .prepareFailed(value),
             let .bindFailed(value), let .stepFailed(value),
             let .closeFailed(value), let .backupFailed(value):
            value
        case .closed:
            ""
        }
        let normalized = message.lowercased()
        return normalized.contains("file is not a database")
            || normalized.contains("database disk image is malformed")
    }

    private static func defaultReflectionReportURL() -> URL {
        if let resource = Bundle.main.resourceURL?
            .appending(path: "MeaningPreview", directoryHint: .isDirectory)
            .appending(path: "named-model-report.json"),
           FileManager.default.fileExists(atPath: resource.path) {
            return resource
        }
        return URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/evidence/add2cam-09-named-model-report.json")
    }

    private static func activeLocalAssignment() throws -> ModelAssignment {
        let registry = try ModelRegistry(
            stateURL: ModelProfileStorage.defaultStateURL()
        )
        guard let assignment = try registry.activeProfile()?
            .assignment(for: .local) else {
            throw LocalModelInferenceError.invalidAssignment
        }
        return assignment
    }

    private static func hasCurrentReflectionAdmission(
        reportURL: URL,
        assignmentProvider: @Sendable () throws -> ModelAssignment,
        now: Date
    ) -> Bool {
        guard let assignment = try? assignmentProvider(),
              let data = try? Data(contentsOf: reportURL),
              let report = try? JSONDecoder().decode(
                  MeaningPreviewNamedModelReport.self,
                  from: data
              ) else { return false }
        return MeaningPreviewReflectionAdmission.validated(
            report: report,
            assignment: assignment,
            now: now
        ) != nil
    }
}

struct MeaningPreviewUnavailableRuntime: MeaningPreviewRuntime {
    let initialLifecycle: MeaningPreviewLifecycle = .unavailable

    func loadLifecycle() async -> MeaningPreviewLifecycle { .unavailable }
    func enable() async throws -> MeaningPreviewLifecycle { throw MeaningPreviewRuntimeError.accessDenied }
    func grantLocalAccess() async throws -> MeaningPreviewLifecycle { throw MeaningPreviewRuntimeError.accessDenied }
    func disable() async throws -> MeaningPreviewLifecycle { .disabled }
    func recover() async throws -> MeaningPreviewRecoveryReceipt {
        throw MeaningPreviewRuntimeError.accessDenied
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

struct VaultRecoveryOperations: Sendable {
    let create: @Sendable (
        _ sourceRoot: URL,
        _ packageURL: URL
    ) throws -> FullVaultBackupReceipt
    let validate: @Sendable (
        _ packageURL: URL
    ) throws -> FullVaultValidationReceipt
    let restore: @Sendable (
        _ packageURL: URL,
        _ destinationRoot: URL
    ) throws -> FullVaultRestoreReceipt

    static let live = VaultRecoveryOperations(
        create: { sourceRoot, packageURL in
            try FullVaultBackupService().createPackage(
                from: sourceRoot,
                to: packageURL
            )
        },
        validate: { packageURL in
            try FullVaultBackupService().validatePackage(at: packageURL)
        },
        restore: { packageURL, destinationRoot in
            try FullVaultBackupService().restorePackage(
                at: packageURL,
                to: destinationRoot
            )
        }
    )
}

struct RepositorySemanticOperations: Sendable {
    let analyze: @Sendable (
        _ root: URL,
        _ snapshot: RepositorySnapshot
    ) async throws -> RepositorySemanticV3RuntimeAnalysis

    static let live = RepositorySemanticOperations {
        root,
        snapshot in
        let registry = try ModelRegistry(
            stateURL: ModelProfileStorage.defaultStateURL()
        )
        guard let assignment = try registry.activeProfile()?
            .assignment(for: .local) else {
            throw LocalModelInferenceError.invalidAssignment
        }
        let generator = try RepositorySemanticV3LocalGenerator(
            assignment: assignment
        )
        return try await RepositorySemanticV3RuntimeAnalyzer().analyze(
            root: root,
            snapshot: snapshot,
            generator: generator
        )
    }
}

struct ResearchAcquisitionOperations: Sendable {
    let prepare: @Sendable (
        _ vaultRoot: URL,
        _ runID: String,
        _ query: String,
        _ target: URL
    ) throws -> ResearchAcquisitionProposal
    let execute: @Sendable (
        _ vaultRoot: URL,
        _ proposal: ResearchAcquisitionProposal
    ) async throws -> ResearchAcquisitionResult
    let resume: @Sendable (
        _ vaultRoot: URL,
        _ jobID: UUID
    ) throws -> ResearchAcquisitionProposal
    let cancel: @Sendable (
        _ vaultRoot: URL,
        _ jobID: UUID
    ) async throws -> Void
    let recoverAndLoadJobs: @Sendable (
        _ vaultRoot: URL
    ) throws -> [ResearchAcquisitionJobRecord]
    let loadJobs: @Sendable (
        _ vaultRoot: URL
    ) throws -> [ResearchAcquisitionJobRecord]
    let keep: @Sendable (
        _ vaultRoot: URL,
        _ packet: ResearchPacket
    ) async throws -> [ResearchPacket]
    let loadPackets: @Sendable (
        _ vaultRoot: URL
    ) throws -> [ResearchPacket]

    static let live = ResearchAcquisitionOperations(
        prepare: { root, runID, query, target in
            try makeCoordinator(vaultRoot: root).proposal(
                runID: runID,
                query: query,
                target: target,
                stateVersion: 0,
                expiresAt: Date().addingTimeInterval(600)
            )
        },
        execute: { root, proposal in
            try await makeCoordinator(vaultRoot: root).execute(
                proposal,
                approvalSource: "native-user-explicit"
            )
        },
        resume: { root, jobID in
            try makeCoordinator(vaultRoot: root).resumeProposal(
                jobID: jobID,
                expiresAt: Date().addingTimeInterval(600)
            )
        },
        cancel: { root, jobID in
            _ = try ResearchAcquisitionJobStore(
                databaseURL: root.appending(path: "vault.sqlite")
            ).cancel(jobID)
        },
        recoverAndLoadJobs: { root in
            let store = try ResearchAcquisitionJobStore(
                databaseURL: root.appending(path: "vault.sqlite")
            )
            _ = try store.recoverInterrupted()
            return try store.all()
        },
        loadJobs: { root in
            try ResearchAcquisitionJobStore(
                databaseURL: root.appending(path: "vault.sqlite")
            ).all()
        },
        keep: { root, packet in
            let store = ResearchPacketStore(
                url: root.appending(path: "research-packets.json")
            )
            try store.keep(packet)
            return try store.load()
        },
        loadPackets: { root in
            try ResearchPacketStore(
                url: root.appending(path: "research-packets.json")
            ).load()
        }
    )

    private static func makeCoordinator(
        vaultRoot: URL
    ) throws -> ResearchAcquisitionCoordinator {
        try ResearchAcquisitionCoordinator.live(vaultRoot: vaultRoot)
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
    @Published var researchSourceURL = ""
    @Published private(set) var researchAcquisitionProposal:
        ResearchAcquisitionProposal?
    @Published private(set) var researchAcquisitionResult:
        ResearchAcquisitionResult?
    @Published private(set) var researchAcquisitionJobs:
        [ResearchAcquisitionJobRecord] = []
    @Published private(set) var retainedResearchPackets:
        [ResearchPacket] = []
    @Published private(set) var researchAcquisitionStatus: String?
    @Published private(set) var researchAcquisitionError: String?
    @Published private(set) var isPreparingResearchAcquisition = false
    @Published private(set) var isResearchAcquiring = false
    @Published private(set) var isResearchPacketRetentionRunning = false
    @Published private(set) var isResearchStateReloading = false
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
    @Published private(set) var ingestJobs: [IngestJobRecord] = []
    @Published private(set) var activityError: String?
    @Published private(set) var isRefreshingActivity = false
    @Published private(set) var isUpdatingIngestJob = false
    @Published private(set) var captureMessage: String?
    @Published private(set) var hotkeyError: String?
    @Published private(set) var hotkeyStatus: GlobalHotkeyStatus = .unregistered
    @Published var hotkeyOpenKey = AssistantHotkeyDefaults.openKey
    @Published var hotkeyCaptureKey = AssistantHotkeyDefaults.captureKey
    @Published var repositoryPath = ""
    @Published private(set) var repositoryPresentation: RepositoryPresentation?
    @Published private(set) var repositoryIndexPresentation: RepositoryIndexPresentation?
    @Published private(set) var repositoryError: String?
    @Published private(set) var isRepositoryIndexing = false
    @Published private(set) var repositoryObservations: [RepositoryObservationPresentation] = []
    @Published var selectedRepositoryObservationID: String?
    @Published private(set) var isScanningRepositoryObservations = false
    @Published private(set) var repositorySemanticAnalysis:
        RepositorySemanticV3RuntimeAnalysis?
    @Published private(set) var repositorySemanticStatus: String?
    @Published private(set) var isRepositorySemanticAnalyzing = false
    @Published var repositoryIdeaTitle = ""
    @Published var repositoryIdeaCounterevidence = ""
    @Published var repositorySemanticRejectedAlternative = ""
    @Published var repositoryIdeaValidationExperiment = ""
    @Published private(set) var repositoryIdeaProposal: RepositoryIdeaProposal?
    @Published private(set) var repositoryIdeaTask: TaskProposal?
    @Published private(set) var repositoryIdeaResearchPlan: ResearchRun?
    @Published private(set) var repositoryIdeaCodexPlan: TaskProposal?
    @Published private(set) var repositoryIdeaDisposition: RepositoryIdeaDisposition?
    @Published private(set) var repositoryIdeaHistory = RepositoryIdeaListPresentation(records: [])
    @Published private(set) var repositorySources: [RepositorySource] = []
    @Published private(set) var repositoryJobs: [RepositoryJobPresentation] = []
    @Published private(set) var macCarePresentation: MacCarePresentation?
    @Published private(set) var macCareError: String?
    @Published private(set) var isMacCareAssessing = false
    @Published private(set) var watchedSourcePresentation: [WatchedSourcePresentation] = []
    @Published private(set) var watchedSourceError: String?
    @Published private(set) var isUpdatingWatchedSources = false
    @Published private(set) var vaultRecoveryStatus: String?
    @Published private(set) var vaultRecoveryError: String?
    @Published private(set) var isVaultRecoveryRunning = false
    @Published private(set) var packagedTextSummaryPresentation =
        PackagedTextSummaryPresentation.notInstalled
    @Published var packagedTextSummaryInput = ""
    @Published private(set) var packagedTextSummaryResult:
        PackagedTextSummary?
    @Published private(set) var packagedTextSummaryError: String?
    @Published private(set) var meaningPreviewLifecycle: MeaningPreviewLifecycle = .disabled
    @Published private(set) var meaningPreviewPresentation: MeaningPreviewAppPresentation?
    @Published private(set) var meaningPreviewSelectedSource: MeaningPreviewSourceReference?
    @Published private(set) var meaningPreviewStatus: String?
    @Published private(set) var meaningPreviewError: String?
    @Published private(set) var meaningPreviewReflectiveSourceIDs: Set<String> = []
    @Published private(set) var meaningPreviewReflection: MeaningPreviewReflectivePresentation?
    @Published private(set) var meaningPreviewReflectionStatus: String?
    @Published private(set) var meaningPreviewReflectionError: String?
    @Published private(set) var isMeaningPreviewReflecting = false
    @Published private(set) var isMeaningPreviewReflectionAvailable = false
    @Published private(set) var isMeaningPreviewWorking = false
    private let hotkeyManager = HotkeyManager()
    private let foregroundActivation: AssistantForegroundActivation
    private lazy var watchedSourceCaptureRefresh = WatchedSourceCaptureRefresh(
        setMessage: { [weak self] message in
            self?.captureMessage = message
        },
        reloadLibrary: { [weak self] in
            self?.reloadLibrary()
        }
    )
    private lazy var watchedSourceService: WatchedSourceService? =
        Self.makeWatchedSourceService { [weak self] in
            Task { @MainActor [weak self] in
                self?.watchedSourceCaptureRefresh.perform()
                self?.reloadIngestJobs()
            }
        }
    private let repositorySourceService: RepositorySourceService?
    private let repositoryJobStore: RepositoryJobStore?
    private let repositorySemanticOperations: RepositorySemanticOperations
    private let researchAcquisitionOperations:
        ResearchAcquisitionOperations
    private let vaultRecoveryOperations: VaultRecoveryOperations
    private let vaultRootProvider: @Sendable () throws -> URL
    private let meaningPreviewRuntime: any MeaningPreviewRuntime
    private let meaningPreviewReflectiveRuntime: (any MeaningPreviewReflectiveRuntime)?
    private var repositorySnapshot: RepositorySnapshot?
    private var repositoryObservationEvidence: [RepositoryObservation] = []
    private var repositoryIdeaCard: RepositoryIdeaCard?
    private var repositoryIndexCancellation: RepositoryIndexCancellation?
    private var activeRepositoryJobID: UUID?
    private var repositorySemanticTask: Task<Void, Never>?
    private var activeRepositorySemanticRunID: UUID?
    private var researchPreparationTask: Task<Void, Never>?
    private var researchAcquisitionTask: Task<Void, Never>?
    private var researchAcquisitionCancellationTask: Task<Void, Never>?
    private var researchRetentionTask: Task<Void, Never>?
    private var researchStateReloadTask: Task<Void, Never>?
    private var activeResearchPreparationID: UUID?
    private var activeResearchAcquisitionID: UUID?
    private var activeResearchCancellationID: UUID?
    private var activeResearchRetentionID: UUID?
    private var meaningPreviewOperationGeneration = UUID()
    private var meaningPreviewReflectionGeneration = UUID()
    private var meaningPreviewReflectionTask:
        Task<MeaningPreviewReflectivePresentation?, Error>?

    init(
        health: AppHealth = .evaluate(
            localModelAvailable: false,
            camRuntimeAvailable: false,
            networkAvailable: false
        ),
        foregroundActivation: AssistantForegroundActivation = .live,
        repositorySourceService: RepositorySourceService? = AppModel.makeRepositorySourceService(),
        repositoryJobStore: RepositoryJobStore? = AppModel.makeRepositoryJobStore(),
        initializeFullWorkspace: Bool = true,
        repositorySemanticOperations:
            RepositorySemanticOperations = .live,
        researchAcquisitionOperations:
            ResearchAcquisitionOperations = .live,
        vaultRecoveryOperations: VaultRecoveryOperations = .live,
        meaningPreviewRuntime: (any MeaningPreviewRuntime)? = nil,
        vaultRootProvider: @escaping @Sendable () throws -> URL = {
            try LocalVaultPaths.rootURL()
        }
    ) {
        self.health = health
        self.foregroundActivation = foregroundActivation
        self.repositorySourceService = repositorySourceService
        self.repositoryJobStore = repositoryJobStore
        self.repositorySemanticOperations = repositorySemanticOperations
        self.researchAcquisitionOperations =
            researchAcquisitionOperations
        self.vaultRecoveryOperations = vaultRecoveryOperations
        self.vaultRootProvider = vaultRootProvider
        if let meaningPreviewRuntime {
            self.meaningPreviewRuntime = meaningPreviewRuntime
        } else if let root = try? vaultRootProvider() {
            self.meaningPreviewRuntime = MeaningPreviewLiveRuntime(root: root)
        } else {
            self.meaningPreviewRuntime = MeaningPreviewUnavailableRuntime()
        }
        self.meaningPreviewReflectiveRuntime = self.meaningPreviewRuntime
            as? any MeaningPreviewReflectiveRuntime
        self.isMeaningPreviewReflectionAvailable =
            self.meaningPreviewReflectiveRuntime?.reflectionInitiallyAvailable
                ?? false
        meaningPreviewLifecycle = self.meaningPreviewRuntime.initialLifecycle
        if meaningPreviewLifecycle == .unavailable {
            meaningPreviewError = Self.meaningPreviewUnavailableMessage
        }
        guard initializeFullWorkspace else {
            reloadRepositorySources()
            reloadRepositoryJobs(recoverInterrupted: true)
            return
        }
        loadHotkeyConfiguration()
        reloadModelSettings()
        reloadTasks()
        reloadLibrary()
        reloadIngestJobs()
        reloadWatchedSources()
        reloadRepositoryIdeaHistory()
        reloadRepositorySources()
        reloadRepositoryJobs(recoverInterrupted: true)
        reloadRetainedResearchPlans()
        reloadResearchAcquisitionState(recoverInterrupted: true)
        reloadKnowledgeClaims()
        reloadContradictionCandidates()
        reloadPackagedTextSummaryModule()
    }

    var isMeaningPreviewVisible: Bool {
        meaningPreviewLifecycle == .enabledWithoutLocalRead
            || meaningPreviewLifecycle == .ready
            || meaningPreviewLifecycle == .corruptedStore
            || meaningPreviewLifecycle == .incompatibleStore
    }

    var canRequestMeaningPreview: Bool {
        meaningPreviewLifecycle == .ready
            && meaningPreviewSelectedSource != nil
            && !isMeaningPreviewWorking
    }

    var canRequestMeaningPreviewReflection: Bool {
        meaningPreviewLifecycle == .ready
            && isMeaningPreviewReflectionAvailable
            && (2...8).contains(meaningPreviewReflectiveSourceIDs.count)
            && !isMeaningPreviewReflecting
    }

    func selectMeaningPreviewSource(id: String) {
        meaningPreviewOperationGeneration = UUID()
        isMeaningPreviewWorking = false
        meaningPreviewSelectedSource = .init(id: id)
        meaningPreviewPresentation = nil
        meaningPreviewStatus = "Selected one active CAM-derived local source."
        meaningPreviewError = nil
    }

    func toggleMeaningPreviewReflectiveSource(id: String) {
        meaningPreviewReflectionTask?.cancel()
        meaningPreviewReflectionGeneration = UUID()
        meaningPreviewReflection = nil
        isMeaningPreviewReflecting = false
        if meaningPreviewReflectiveSourceIDs.contains(id) {
            meaningPreviewReflectiveSourceIDs.remove(id)
        } else if meaningPreviewReflectiveSourceIDs.count < 8 {
            meaningPreviewReflectiveSourceIDs.insert(id)
        } else {
            meaningPreviewReflectionError =
                "Reflection accepts at most eight explicitly selected sources."
            return
        }
        meaningPreviewReflectionError = nil
        meaningPreviewReflectionStatus =
            "Selected \(meaningPreviewReflectiveSourceIDs.count) current sources for explicit reflection."
    }

    func requestMeaningPreviewReflection() async {
        guard (2...8).contains(meaningPreviewReflectiveSourceIDs.count) else {
            meaningPreviewReflectionStatus =
                "Select at least two and at most eight current sources for reflection."
            return
        }
        guard isMeaningPreviewReflectionAvailable,
              let runtime = meaningPreviewReflectiveRuntime else {
            meaningPreviewReflectionError =
                "Reflection is not admitted by current frozen model evidence. Practical Preview remains available."
            return
        }
        let generation = UUID()
        meaningPreviewReflectionGeneration = generation
        let references = meaningPreviewReflectiveSourceIDs.sorted().map {
            MeaningPreviewSourceReference(id: $0)
        }
        isMeaningPreviewReflecting = true
        meaningPreviewReflection = nil
        meaningPreviewReflectionError = nil
        meaningPreviewReflectionStatus = "Checking explicit selected context locally."
        let task = Task {
            try await runtime.requestReflection(references: references, now: Date())
        }
        meaningPreviewReflectionTask = task
        do {
            let result = try await task.value
            guard generation == meaningPreviewReflectionGeneration,
                  meaningPreviewLifecycle == .ready else { return }
            meaningPreviewReflection = result
            meaningPreviewReflectionStatus = result == nil
                ? "The validated reflective lane abstained. No fallback occurred."
                : "One ephemeral reflection was admitted by the frozen local-model gate."
        } catch is CancellationError {
            // Selection change or disable owns the newer status.
        } catch {
            guard generation == meaningPreviewReflectionGeneration else { return }
            isMeaningPreviewReflectionAvailable = false
            meaningPreviewReflection = nil
            meaningPreviewReflectionError =
                "Selected local reflection is unavailable. No fallback occurred; practical Preview remains available."
            meaningPreviewReflectionStatus = nil
        }
        if generation == meaningPreviewReflectionGeneration {
            isMeaningPreviewReflecting = false
            meaningPreviewReflectionTask = nil
        }
    }

    func enableMeaningPreview() async {
        await updateMeaningPreviewLifecycle(
            failure: "Meaning Preview could not be enabled. No access was granted."
        ) { try await meaningPreviewRuntime.enable() }
    }

    func grantMeaningPreviewLocalRead() async {
        await updateMeaningPreviewLifecycle(
            failure: "Local read/write access could not be granted. No Preview ran."
        ) { try await meaningPreviewRuntime.grantLocalAccess() }
    }

    func recoverMeaningPreview() async {
        let operation = beginMeaningPreviewOperation()
        do {
            let receipt = try await meaningPreviewRuntime.recover()
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewLifecycle = receipt.lifecycle
            meaningPreviewPresentation = nil
            meaningPreviewSelectedSource = nil
            meaningPreviewError = nil
            if receipt.lifecycle == .disabled
                || receipt.lifecycle == .unavailable {
                selection = .assistant
            }
            meaningPreviewStatus = receipt.archivedPreviousState
                ? "Meaning Preview isolated state was archived and reinitialized."
                : "Meaning Preview isolated state was initialized."
        } catch {
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewError = "Meaning Preview isolated recovery failed. Ordinary CAM is unchanged."
            meaningPreviewStatus = nil
        }
        finishMeaningPreviewOperation(operation)
    }

    func disableMeaningPreview() async {
        meaningPreviewReflectionTask?.cancel()
        meaningPreviewReflectionGeneration = UUID()
        meaningPreviewReflectiveSourceIDs = []
        meaningPreviewReflection = nil
        meaningPreviewReflectionStatus = nil
        meaningPreviewReflectionError = nil
        isMeaningPreviewReflecting = false
        let operation = beginMeaningPreviewOperation()
        meaningPreviewPresentation = nil
        meaningPreviewSelectedSource = nil
        isMeaningPreviewWorking = false
        do {
            let lifecycle = try await meaningPreviewRuntime.disable()
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewLifecycle = lifecycle
            selection = .assistant
            meaningPreviewStatus = "Meaning Preview disabled. Ordinary Assistant is unchanged."
            meaningPreviewError = nil
        } catch {
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewError = "Meaning Preview could not be disabled. Ordinary CAM is unchanged."
        }
        finishMeaningPreviewOperation(operation)
    }

    func requestMeaningPreview() async {
        guard !isMeaningPreviewWorking else { return }
        guard meaningPreviewLifecycle == .ready else {
            meaningPreviewError = "Grant local read and isolated write access before requesting a Preview."
            return
        }
        guard let selected = meaningPreviewSelectedSource else {
            meaningPreviewError = "Select one active local source for this Preview."
            return
        }
        let operation = beginMeaningPreviewOperation()
        meaningPreviewPresentation = nil
        meaningPreviewStatus = "Checking the explicitly selected local context."
        meaningPreviewError = nil
        do {
            let presentation = try await meaningPreviewRuntime.request(
                reference: selected,
                now: Date()
            )
            guard isCurrentMeaningPreviewOperation(operation),
                  meaningPreviewLifecycle == .ready else {
                return
            }
            meaningPreviewPresentation = presentation
            meaningPreviewStatus = presentation.card == nil
                ? "Nothing practical surfaced from the selected context."
                : "One practical Preview is ready."
        } catch {
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewPresentation = nil
            meaningPreviewError = Self.meaningPreviewRequestFailure(error)
            meaningPreviewStatus = nil
        }
        finishMeaningPreviewOperation(operation)
    }

    func applyMeaningPreviewAction(_ action: MeaningPreviewCardAction) async {
        guard !isMeaningPreviewWorking else { return }
        guard let presentation = meaningPreviewPresentation,
              let card = presentation.card else { return }
        let operation = beginMeaningPreviewOperation()
        do {
            _ = try await meaningPreviewRuntime.applyAction(
                action,
                memoryID: card.id,
                expectedVersion: presentation.version,
                at: Date()
            )
            guard isCurrentMeaningPreviewOperation(operation),
                  meaningPreviewLifecycle == .ready else { return }
            meaningPreviewPresentation = nil
            meaningPreviewStatus = switch action {
            case .now: "Now recorded in isolated Preview state."
            case .later: "Later recorded; this item will not resurface immediately."
            case .release: "Released from isolated Preview state."
            }
            meaningPreviewError = nil
        } catch {
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewError = Self.meaningPreviewMutationFailure
        }
        finishMeaningPreviewOperation(operation)
    }

    func recordMeaningPreviewFeedback(_ feedback: MeaningPreviewFeedback) async {
        guard !isMeaningPreviewWorking else { return }
        guard let presentation = meaningPreviewPresentation,
              let card = presentation.card,
              let domain = presentation.domain else { return }
        let operation = beginMeaningPreviewOperation()
        do {
            _ = try await meaningPreviewRuntime.recordFeedback(
                feedback,
                memoryID: card.id,
                domain: domain,
                expectedVersion: presentation.version
            )
            guard isCurrentMeaningPreviewOperation(operation),
                  meaningPreviewLifecycle == .ready else { return }
            meaningPreviewPresentation = nil
            meaningPreviewStatus = feedback == .helpful
                ? "Helpful recorded explicitly in isolated Preview state."
                : "Not helpful recorded explicitly in isolated Preview state."
            meaningPreviewError = nil
        } catch {
            guard isCurrentMeaningPreviewOperation(operation) else { return }
            meaningPreviewError = Self.meaningPreviewMutationFailure
        }
        finishMeaningPreviewOperation(operation)
    }

    private func updateMeaningPreviewLifecycle(
        failure: String,
        operation: () async throws -> MeaningPreviewLifecycle
    ) async {
        let operationID = beginMeaningPreviewOperation()
        do {
            let lifecycle = try await operation()
            guard isCurrentMeaningPreviewOperation(operationID) else { return }
            meaningPreviewLifecycle = lifecycle
            meaningPreviewPresentation = nil
            meaningPreviewError = nil
            meaningPreviewStatus = switch meaningPreviewLifecycle {
            case .disabled: "Meaning Preview is disabled."
            case .enabledWithoutLocalRead:
                "Meaning Preview enabled. No local access has been granted."
            case .ready:
                "Meaning Preview has explicit local read and isolated write access."
            case .corruptedStore:
                "Meaning Preview isolated state is corrupted and requires recovery."
            case .incompatibleStore:
                "Meaning Preview isolated state is incompatible and requires recovery."
            case .unavailable: nil
            }
        } catch {
            guard isCurrentMeaningPreviewOperation(operationID) else { return }
            meaningPreviewError = failure
        }
        finishMeaningPreviewOperation(operationID)
    }

    private func beginMeaningPreviewOperation() -> UUID {
        let value = UUID()
        meaningPreviewOperationGeneration = value
        isMeaningPreviewWorking = true
        return value
    }

    private func isCurrentMeaningPreviewOperation(_ value: UUID) -> Bool {
        meaningPreviewOperationGeneration == value
    }

    private func finishMeaningPreviewOperation(_ value: UUID) {
        guard isCurrentMeaningPreviewOperation(value) else { return }
        isMeaningPreviewWorking = false
    }

    private static let meaningPreviewUnavailableMessage =
        "Meaning Preview state is unavailable. Ordinary CAM is unchanged."
    private static let meaningPreviewMutationFailure =
        "Meaning Preview changed or became unavailable. Request a fresh Preview."

    private static func meaningPreviewRequestFailure(_ error: Error) -> String {
        switch error {
        case MeaningPreviewRuntimeError.accessDenied,
             MeaningPreviewRuntimeError.disabledDuringRequest:
            "Meaning Preview access changed before the selected context was used."
        case MeaningPreviewRuntimeError.sourceUnavailable:
            "The selected local source is no longer active or available. Choose another source."
        default:
            "Meaning Preview could not read its isolated state. Ordinary CAM is unchanged."
        }
    }

    func reloadPackagedTextSummaryModule() {
        do {
            let root = try vaultRootProvider()
            let manifestDirectory = Self.moduleManifestDirectory(vaultRoot: root)
            guard FileManager.default.fileExists(atPath: manifestDirectory.path)
            else {
                packagedTextSummaryPresentation = .notInstalled
                packagedTextSummaryResult = nil
                packagedTextSummaryError = nil
                return
            }
            let registry = try Self.moduleRegistry(vaultRoot: root)
            guard registry.manifests().contains(where: { $0.id == "cam.text-summary" })
            else {
                packagedTextSummaryPresentation = .notInstalled
                packagedTextSummaryResult = nil
                packagedTextSummaryError = nil
                return
            }
            let isEnabled = try registry.isEnabled("cam.text-summary")
            let hasGrant = try registry.grantedPermissions(
                for: "cam.text-summary"
            ).contains(.readLocal)
            let status: String
            if !isEnabled {
                status = "Installed but disabled. Enablement still grants no access."
            } else if !hasGrant {
                status = "Enabled with no local-text access. Grant is still required."
            } else {
                status = "Enabled with explicit local-text access."
            }
            packagedTextSummaryPresentation = PackagedTextSummaryPresentation(
                isInstalled: true,
                isEnabled: isEnabled,
                hasLocalTextGrant: hasGrant,
                statusLabel: status
            )
            packagedTextSummaryError = nil
        } catch {
            packagedTextSummaryPresentation = .notInstalled
            packagedTextSummaryResult = nil
            packagedTextSummaryError =
                "The packaged module state could not be read. Core memory is unchanged."
        }
    }

    func installPackagedTextSummaryModule() {
        do {
            let root = try vaultRootProvider()
            _ = try PackagedModuleInstaller(
                manifestDirectory: Self.moduleManifestDirectory(vaultRoot: root)
            ).installTextSummary()
            packagedTextSummaryResult = nil
            reloadPackagedTextSummaryModule()
        } catch PackagedModuleInstallerError.alreadyInstalled {
            reloadPackagedTextSummaryModule()
        } catch {
            packagedTextSummaryError =
                "The trusted packaged module could not be installed. Core memory is unchanged."
        }
    }

    func enablePackagedTextSummaryModule() {
        do {
            let root = try vaultRootProvider()
            try Self.moduleRegistry(vaultRoot: root).enable("cam.text-summary")
            packagedTextSummaryResult = nil
            reloadPackagedTextSummaryModule()
        } catch {
            packagedTextSummaryError =
                "The packaged module could not be enabled. No permission was granted."
        }
    }

    func grantPackagedTextSummaryLocalRead() {
        do {
            let root = try vaultRootProvider()
            try Self.moduleRegistry(vaultRoot: root).grant(
                [.readLocal], to: "cam.text-summary"
            )
            packagedTextSummaryResult = nil
            reloadPackagedTextSummaryModule()
        } catch {
            packagedTextSummaryError =
                "Local-text access could not be granted. No module action ran."
        }
    }

    func summarizeWithPackagedTextSummaryModule() {
        guard !packagedTextSummaryInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            packagedTextSummaryError = "Enter text to summarize locally."
            return
        }
        do {
            let root = try vaultRootProvider()
            packagedTextSummaryResult = try PackagedTextSummaryModule().summarize(
                packagedTextSummaryInput,
                registry: Self.moduleRegistry(vaultRoot: root)
            )
            packagedTextSummaryError = nil
        } catch {
            packagedTextSummaryResult = nil
            packagedTextSummaryError =
                "The module is unavailable until it is enabled and granted local-text access."
        }
    }

    func disablePackagedTextSummaryModule() {
        do {
            let root = try vaultRootProvider()
            try Self.moduleRegistry(vaultRoot: root).disable("cam.text-summary")
            packagedTextSummaryResult = nil
            reloadPackagedTextSummaryModule()
        } catch {
            packagedTextSummaryError =
                "The packaged module could not be disabled. Core memory is unchanged."
        }
    }

    func removePackagedTextSummaryModule() {
        do {
            let root = try vaultRootProvider()
            let manifestDirectory = Self.moduleManifestDirectory(vaultRoot: root)
            try PackagedModuleInstaller(manifestDirectory: manifestDirectory)
                .removeTextSummary()
            try Self.moduleRegistry(vaultRoot: root).reload()
            packagedTextSummaryResult = nil
            reloadPackagedTextSummaryModule()
        } catch {
            packagedTextSummaryError =
                "The packaged module could not be removed. Core memory is unchanged."
        }
    }

    private static func moduleManifestDirectory(vaultRoot: URL) -> URL {
        vaultRoot.appending(path: "modules", directoryHint: .isDirectory)
    }

    private static func moduleRegistry(vaultRoot: URL) throws -> ModuleRegistry {
        try ModuleRegistry(
            manifestDirectory: moduleManifestDirectory(vaultRoot: vaultRoot),
            stateURL: LocalVaultPaths.stateURL(.moduleState, vaultRoot: vaultRoot)
        )
    }

    func createVaultBackup(to packageURL: URL) {
        guard beginVaultRecovery() else { return }
        let sourceRoot: URL
        do {
            sourceRoot = try vaultRootProvider()
        } catch {
            failVaultRecovery(
                "The local vault location could not be resolved."
            )
            return
        }
        let create = vaultRecoveryOperations.create
        Task { [weak self] in
            do {
                let receipt = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try create(sourceRoot, packageURL)
                }.value
                self?.vaultRecoveryStatus =
                    "Backup created: \(receipt.entryCount) entries, "
                    + "\(receipt.totalByteCount) bytes. Manifest "
                    + "\(receipt.manifestSHA256.prefix(12)). Package "
                    + "\(receipt.packageURL.path)."
                self?.vaultRecoveryError = nil
            } catch {
                self?.vaultRecoveryStatus = nil
                self?.vaultRecoveryError =
                    "The local backup could not be created. "
                    + "No existing vault was changed."
            }
            self?.isVaultRecoveryRunning = false
        }
    }

    func validateVaultBackup(at packageURL: URL) {
        guard beginVaultRecovery() else { return }
        let validate = vaultRecoveryOperations.validate
        Task { [weak self] in
            do {
                let receipt = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try validate(packageURL)
                }.value
                self?.vaultRecoveryStatus =
                    "Backup validated: \(receipt.entryCount) entries, "
                    + "\(receipt.totalByteCount) bytes, schema "
                    + "\(receipt.sourceSchemaVersion). Manifest "
                    + "\(receipt.manifestSHA256.prefix(12))."
                self?.vaultRecoveryError = nil
            } catch {
                self?.vaultRecoveryStatus = nil
                self?.vaultRecoveryError =
                    "The selected backup did not pass local validation. "
                    + "No vault was changed."
            }
            self?.isVaultRecoveryRunning = false
        }
    }

    func restoreVaultBackup(
        at packageURL: URL,
        to destinationRoot: URL
    ) {
        guard beginVaultRecovery() else { return }
        let restore = vaultRecoveryOperations.restore
        Task { [weak self] in
            do {
                let receipt = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try restore(packageURL, destinationRoot)
                }.value
                let authorityLabel =
                    receipt.authorityRecordsQuarantined == 1
                    ? "authority record quarantined"
                    : "authority records quarantined"
                self?.vaultRecoveryStatus =
                    "New vault restored: \(receipt.entryCount) entries, "
                    + "\(receipt.watchedSourcesPaused) watched sources paused, "
                    + "\(receipt.authorityRecordsQuarantined) "
                    + "\(authorityLabel). Destination "
                    + "\(receipt.destinationURL.path)."
                self?.vaultRecoveryError = nil
            } catch {
                self?.vaultRecoveryStatus = nil
                self?.vaultRecoveryError =
                    "The backup could not be restored to that new location. "
                    + "No existing vault was changed."
            }
            self?.isVaultRecoveryRunning = false
        }
    }

    private func beginVaultRecovery() -> Bool {
        guard !isVaultRecoveryRunning else {
            vaultRecoveryError =
                "Another local backup or restore operation is still running."
            return false
        }
        isVaultRecoveryRunning = true
        vaultRecoveryStatus = nil
        vaultRecoveryError = nil
        return true
    }

    private func failVaultRecovery(_ message: String) {
        isVaultRecoveryRunning = false
        vaultRecoveryStatus = nil
        vaultRecoveryError = message
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

    var researchAcquisitionPacket: ResearchPacket? {
        researchAcquisitionResult?.packet
    }

    func prepareResearchAcquisition() {
        let query = researchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else {
            researchAcquisitionError =
                "Enter one public research question."
            return
        }
        let targetText = researchSourceURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let target = URL(string: targetText) else {
            researchAcquisitionError =
                "Enter a public HTTPS document URL. "
                + "Local, private-network, credentialed, and non-HTTPS "
                + "targets are refused."
            return
        }
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            researchAcquisitionError =
                "The local vault could not be opened for research."
            return
        }
        let run: ResearchRun
        do {
            run = try ResearchCoordinator().begin(
                id: UUID().uuidString,
                queries: [query],
                stateVersion: 0
            )
        } catch {
            researchAcquisitionError =
                "Enter one public research question."
            return
        }
        currentResearchRun = run
        researchPresentation = ResearchPresentation(run: run)
        researchPreparationTask?.cancel()
        let preparationID = UUID()
        activeResearchPreparationID = preparationID
        isPreparingResearchAcquisition = true
        researchAcquisitionError = nil
        researchAcquisitionStatus =
            "Checking the exact target and privacy boundary locally."
        researchAcquisitionProposal = nil
        pendingActionCard = nil
        let prepare = researchAcquisitionOperations.prepare
        researchPreparationTask = Task { [weak self] in
            do {
                let proposal = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try prepare(root, run.id, query, target)
                }.value
                guard self?.activeResearchPreparationID
                        == preparationID else {
                    return
                }
                self?.researchAcquisitionProposal = proposal
                self?.pendingActionCard = proposal.actionCard
                self?.researchAcquisitionStatus =
                    "Exact public-document proposal ready. "
                    + "Review the target and limits before approval."
                self?.researchAcquisitionError = nil
            } catch is CancellationError {
                guard self?.activeResearchPreparationID
                        == preparationID else {
                    return
                }
                self?.researchAcquisitionStatus =
                    "Research proposal preparation was cancelled."
                self?.researchAcquisitionError = nil
            } catch {
                guard self?.activeResearchPreparationID
                        == preparationID else {
                    return
                }
                self?.researchAcquisitionProposal = nil
                self?.pendingActionCard = nil
                self?.researchAcquisitionStatus = nil
                self?.researchAcquisitionError =
                    Self.researchAcquisitionMessage(
                        for: error,
                        phase: .proposal
                    )
            }
            guard self?.activeResearchPreparationID
                    == preparationID else {
                return
            }
            self?.isPreparingResearchAcquisition = false
            self?.activeResearchPreparationID = nil
        }
    }

    func approveAndAcquireResearchSource() {
        guard let proposal = researchAcquisitionProposal,
              !isResearchAcquiring else {
            return
        }
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            researchAcquisitionError =
                "The local vault could not be opened for research."
            return
        }
        researchAcquisitionTask?.cancel()
        researchAcquisitionCancellationTask?.cancel()
        activeResearchAcquisitionID = proposal.id
        activeResearchCancellationID = nil
        isResearchAcquiring = true
        researchAcquisitionError = nil
        researchAcquisitionStatus =
            "Acquiring the exact approved public document."
        let execute = researchAcquisitionOperations.execute
        researchAcquisitionTask = Task { [weak self] in
            do {
                let worker = Task.detached(
                    priority: .userInitiated
                ) {
                    try await execute(root, proposal)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard self?.activeResearchAcquisitionID == proposal.id,
                      self?.activeResearchCancellationID != proposal.id else {
                    return
                }
                self?.researchAcquisitionResult = result
                self?.researchAcquisitionProposal = nil
                self?.pendingActionCard = nil
                self?.upsertResearchJob(result.job)
                self?.researchAcquisitionStatus =
                    "Ephemeral public-document packet ready for review. "
                    + "Nothing was retained automatically."
                self?.researchAcquisitionError = nil
            } catch is CancellationError {
                guard self?.activeResearchAcquisitionID
                        == proposal.id else {
                    return
                }
                self?.researchAcquisitionResult = nil
                self?.researchAcquisitionProposal = nil
                self?.pendingActionCard = nil
                self?.researchAcquisitionStatus =
                    "Public document acquisition was cancelled. "
                    + "No packet was retained; safe resume requires "
                    + "a new exact approval."
                self?.researchAcquisitionError = nil
            } catch {
                guard self?.activeResearchAcquisitionID
                        == proposal.id else {
                    return
                }
                self?.researchAcquisitionResult = nil
                self?.researchAcquisitionProposal = nil
                self?.pendingActionCard = nil
                self?.researchAcquisitionStatus = nil
                self?.researchAcquisitionError =
                    Self.researchAcquisitionMessage(
                        for: error,
                        phase: .execution
                    )
                self?.reloadResearchAcquisitionState(
                    recoverInterrupted: false
                )
            }
            guard self?.activeResearchAcquisitionID
                    == proposal.id,
                  self?.activeResearchCancellationID
                    != proposal.id else {
                return
            }
            self?.isResearchAcquiring = false
            self?.activeResearchAcquisitionID = nil
            self?.researchAcquisitionTask = nil
        }
    }

    func cancelResearchAcquisition() {
        guard let jobID = activeResearchAcquisitionID else { return }
        let acquisitionTask = researchAcquisitionTask
        activeResearchCancellationID = jobID
        acquisitionTask?.cancel()
        researchAcquisitionResult = nil
        researchAcquisitionProposal = nil
        pendingActionCard = nil
        researchAcquisitionStatus =
            "Public document acquisition was cancelled. "
            + "No packet was retained; safe resume requires "
            + "a new exact approval."
        researchAcquisitionError = nil
        let cancel = researchAcquisitionOperations.cancel
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            isResearchAcquiring = false
            activeResearchAcquisitionID = nil
            activeResearchCancellationID = nil
            researchAcquisitionError =
                "The local vault could not record the research cancellation."
            return
        }
        researchAcquisitionCancellationTask?.cancel()
        researchAcquisitionCancellationTask = Task { [weak self] in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try await cancel(root, jobID)
                }.value
            } catch {
                guard self?.activeResearchCancellationID == jobID else {
                    return
                }
                self?.researchAcquisitionError =
                    "The acquisition stopped, but its durable cancellation "
                    + "record could not be refreshed."
            }
            await acquisitionTask?.value
            guard self?.activeResearchCancellationID == jobID else {
                return
            }
            self?.isResearchAcquiring = false
            self?.activeResearchAcquisitionID = nil
            self?.activeResearchCancellationID = nil
            self?.researchAcquisitionTask = nil
            self?.researchAcquisitionCancellationTask = nil
            self?.reloadResearchAcquisitionState(recoverInterrupted: false)
        }
    }

    func prepareResearchAcquisitionResume(_ jobID: UUID) {
        guard !isPreparingResearchAcquisition,
              !isResearchAcquiring else {
            return
        }
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            researchAcquisitionError =
                "The local vault could not be opened for research."
            return
        }
        let preparationID = UUID()
        activeResearchPreparationID = preparationID
        isPreparingResearchAcquisition = true
        researchAcquisitionError = nil
        researchAcquisitionStatus =
            "Preparing a new exact approval for safe resume."
        let resume = researchAcquisitionOperations.resume
        researchPreparationTask = Task { [weak self] in
            do {
                let proposal = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try resume(root, jobID)
                }.value
                guard self?.activeResearchPreparationID
                        == preparationID else {
                    return
                }
                self?.researchAcquisitionProposal = proposal
                self?.pendingActionCard = proposal.actionCard
                self?.researchAcquisitionStatus =
                    "Resume proposal ready. Review and approve "
                    + "the new exact action card."
                self?.researchAcquisitionError = nil
            } catch {
                guard self?.activeResearchPreparationID
                        == preparationID else {
                    return
                }
                self?.researchAcquisitionProposal = nil
                self?.pendingActionCard = nil
                self?.researchAcquisitionStatus = nil
                self?.researchAcquisitionError =
                    "This acquisition cannot be resumed. "
                    + "Its attempt limit may be exhausted."
            }
            guard self?.activeResearchPreparationID
                    == preparationID else {
                return
            }
            self?.isPreparingResearchAcquisition = false
            self?.activeResearchPreparationID = nil
        }
    }

    func keepResearchAcquisitionPacket() {
        guard let packet = researchAcquisitionPacket,
              !isResearchPacketRetentionRunning else {
            return
        }
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            researchAcquisitionError =
                "The local vault could not be opened for research."
            return
        }
        let retentionID = UUID()
        activeResearchRetentionID = retentionID
        isResearchPacketRetentionRunning = true
        researchAcquisitionError = nil
        let keep = researchAcquisitionOperations.keep
        researchRetentionTask = Task { [weak self] in
            do {
                let packets = try await Task.detached(
                    priority: .userInitiated
                ) {
                    try await keep(root, packet)
                }.value
                guard self?.activeResearchRetentionID
                        == retentionID else {
                    return
                }
                self?.retainedResearchPackets = packets
                self?.researchAcquisitionStatus =
                    "Research packet kept locally. The displayed source "
                    + "receipt and typed results will reopen after restart."
                self?.researchAcquisitionError = nil
            } catch {
                guard self?.activeResearchRetentionID
                        == retentionID else {
                    return
                }
                self?.researchAcquisitionError =
                    "The reviewed research packet could not be kept."
            }
            guard self?.activeResearchRetentionID
                    == retentionID else {
                return
            }
            self?.isResearchPacketRetentionRunning = false
            self?.activeResearchRetentionID = nil
        }
    }

    func discardResearchAcquisitionPacket() {
        guard researchAcquisitionPacket != nil else { return }
        researchAcquisitionResult = nil
        researchAcquisitionStatus =
            "Ephemeral research packet discarded. "
            + "Kept packets and vault source bytes were not changed."
        researchAcquisitionError = nil
    }

    func reviewCompletedResearchAcquisition(_ jobID: UUID) {
        guard let job = researchAcquisitionJobs.first(
            where: { $0.id == jobID }
        ) else {
            researchAcquisitionError =
                "The completed research receipt is no longer available."
            return
        }
        do {
            researchAcquisitionResult =
                try ResearchAcquisitionResult.recover(completedJob: job)
            researchAcquisitionStatus =
                "Completed receipt reopened as an ephemeral packet for "
                + "review. Nothing was retained automatically."
            researchAcquisitionError = nil
        } catch {
            researchAcquisitionResult = nil
            researchAcquisitionError =
                "The completed research receipt could not be reopened."
        }
    }

    func reloadResearchAcquisitionState(
        recoverInterrupted: Bool = false
    ) {
        guard !isResearchStateReloading else { return }
        let root: URL
        do {
            root = try vaultRootProvider()
        } catch {
            researchAcquisitionError =
                "The local vault could not be opened for research."
            return
        }
        isResearchStateReloading = true
        let loadJobs = recoverInterrupted
            ? researchAcquisitionOperations.recoverAndLoadJobs
            : researchAcquisitionOperations.loadJobs
        let loadPackets = researchAcquisitionOperations.loadPackets
        researchStateReloadTask = Task { [weak self] in
            do {
                let state = try await Task.detached(
                    priority: .utility
                ) {
                    (
                        try loadJobs(root),
                        try loadPackets(root)
                    )
                }.value
                self?.researchAcquisitionJobs = state.0
                self?.retainedResearchPackets = state.1
            } catch {
                self?.researchAcquisitionError =
                    "Research acquisition history could not be read."
            }
            self?.isResearchStateReloading = false
        }
    }

    private func upsertResearchJob(
        _ job: ResearchAcquisitionJobRecord
    ) {
        researchAcquisitionJobs.removeAll { $0.id == job.id }
        researchAcquisitionJobs.append(job)
        researchAcquisitionJobs.sort {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString
                : $0.createdAt < $1.createdAt
        }
    }

    private enum ResearchAcquisitionMessagePhase {
        case proposal
        case execution
    }

    private nonisolated static func researchAcquisitionMessage(
        for error: Error,
        phase: ResearchAcquisitionMessagePhase
    ) -> String {
        if let error = error as? ResearchAcquisitionError {
            switch error {
            case .policyBlocked:
                return "The research question or target contains "
                    + "protected data. No network request or approval "
                    + "was created."
            case .invalidTarget:
                return "Enter a public HTTPS document URL. "
                    + "Local, private-network, credentialed, and "
                    + "non-HTTPS targets are refused."
            case .invalidResponse:
                return "The public source was refused because its status, "
                    + "origin, content type, or byte size did not match "
                    + "the exact approved boundary."
            case .transportFailed:
                return "The exact public document could not be acquired. "
                    + "No provider fallback, browser, cloud model, or "
                    + "automatic retention was used."
            case .ingestionFailed:
                return "The acquired bytes could not be validated by the "
                    + "local vault. No research packet was created."
            default:
                break
            }
        }
        switch phase {
        case .proposal:
            return "The exact public-document proposal could not be "
                + "created. No network request or approval occurred."
        case .execution:
            return "The exact public document could not be acquired. "
                + "No packet was retained and no fallback was used."
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

    func reloadIngestJobs() {
        let databaseURL: URL
        let contentURL: URL
        do {
            databaseURL = try LocalVaultPaths.databaseURL()
            contentURL = try LocalVaultPaths.contentURL()
        } catch {
            ingestJobs = []
            activityError = "Local ingest activity could not be read."
            return
        }
        isRefreshingActivity = true
        Task { [weak self] in
            do {
                let records = try await Task.detached {
                    let queue = try IngestQueue(
                        databaseURL: databaseURL,
                        contentStore: try ContentStore(
                            rootDirectory: contentURL
                        ),
                        extractors: .localDefaults
                    )
                    let records = try queue.jobs()
                    try queue.close()
                    return records
                }.value
                self?.ingestJobs = records
                self?.activityError = nil
            } catch {
                self?.activityError = "Local ingest activity could not be read."
            }
            self?.isRefreshingActivity = false
        }
    }

    func cancelIngestJob(_ sourceID: ContentID) {
        updateIngestJob(sourceID, operation: .cancel)
    }

    func resumeIngestJob(_ sourceID: ContentID) {
        updateIngestJob(sourceID, operation: .resume)
    }

    private enum IngestJobOperation {
        case cancel
        case resume
    }

    private func updateIngestJob(
        _ sourceID: ContentID,
        operation: IngestJobOperation
    ) {
        let databaseURL: URL
        let contentURL: URL
        do {
            databaseURL = try LocalVaultPaths.databaseURL()
            contentURL = try LocalVaultPaths.contentURL()
        } catch {
            activityError = "The local ingest job could not be updated."
            return
        }
        isUpdatingIngestJob = true
        activityError = nil
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
                    switch operation {
                    case .cancel:
                        try queue.cancel(sourceID)
                    case .resume:
                        _ = try queue.resume(sourceID)
                    }
                    try queue.close()
                }.value
                switch operation {
                case .cancel:
                    self?.captureMessage =
                        "Ingest cancelled locally. Original source bytes remain available."
                case .resume:
                    self?.captureMessage =
                        "Ingest resumed and indexed locally."
                    self?.reloadLibrary()
                }
                self?.activityError = nil
                self?.isUpdatingIngestJob = false
                self?.reloadIngestJobs()
            } catch {
                self?.activityError =
                    "The local ingest job changed before it could be updated. Refresh and try again."
                self?.isUpdatingIngestJob = false
                self?.reloadIngestJobs()
            }
        }
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
            defer { try? queue.close() }
            let receipt = try CaptureService(queue: queue).capture(envelope)
            if receipt.wasDuplicateSource {
                captureMessage = "Clipboard is already in your local vault."
            } else if CaptureProcessingPolicy.shouldDefer() {
                captureMessage =
                    "Clipboard queued locally. Review or cancel it in Activity."
            } else {
                _ = try queue.processNext()
                captureMessage = "Clipboard captured and indexed locally."
                reloadLibrary()
            }
            reloadIngestJobs()
        } catch {
            captureMessage = "Clipboard could not be captured locally."
            reloadIngestJobs()
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
                    self.foregroundActivation.perform()
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

    private nonisolated static func makeWatchedSourceService(
        onCapture: @escaping @Sendable () -> Void
    ) -> WatchedSourceService? {
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
                    onCapture()
                } catch {}
            }
            return WatchedSourceService(store: store, manager: manager)
        } catch {
            return nil
        }
    }

    private nonisolated static func makeRepositorySourceService() -> RepositorySourceService? {
        do {
            let lifecycleStore = try RepositorySourceLifecycleStore(
                databaseURL: LocalVaultPaths.databaseURL()
            )
            return RepositorySourceService(
                store: RepositorySourceConfigurationStore(
                    url: try LocalVaultPaths.rootURL().appending(path: "repository-sources.json")
                ),
                lifecycleStore: lifecycleStore
            )
        } catch {
            return nil
        }
    }

    private nonisolated static func makeRepositoryJobStore() -> RepositoryJobStore? {
        try? RepositoryJobStore(databaseURL: LocalVaultPaths.databaseURL())
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

    func reloadRepositoryJobs(recoverInterrupted: Bool = false) {
        guard let repositoryJobStore else {
            repositoryJobs = []
            return
        }
        do {
            if recoverInterrupted {
                _ = try repositoryJobStore.recoverInterrupted()
            }
            repositoryJobs = try repositoryJobStore.all()
                .reversed()
                .map(RepositoryJobPresentation.init)
        } catch {
            repositoryJobs = []
            repositoryError = "Repository job history could not be read locally."
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
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let sourceID = repositorySources.first {
            URL(filePath: $0.canonicalPath)
                .standardizedFileURL
                .resolvingSymlinksInPath().path == root.path
        }?.id
        guard let repositoryJobStore else {
            repositoryIndexPresentation = nil
            repositoryError = "Repository job history could not be opened locally."
            return
        }
        let job: RepositoryJobRecord
        do {
            job = try repositoryJobStore.create(
                sourceID: sourceID,
                canonicalPath: root.path
            )
            reloadRepositoryJobs()
        } catch {
            repositoryIndexPresentation = nil
            repositoryError = "A durable local repository job could not be created."
            return
        }
        runRepositoryJob(
            job.id,
            root: root,
            databaseURL: databaseURL,
            contentRootURL: contentRootURL
        )
    }

    func cancelRepositoryJob(_ jobID: UUID) {
        guard let job = repositoryJobs.first(where: { $0.id == jobID }),
              job.availableAction == .cancel else {
            return
        }
        if activeRepositoryJobID == jobID {
            if repositoryIndexCancellation?.cancel() == false {
                repositoryError = "This repository job is already finishing its local snapshot receipt."
            }
            return
        }
        do {
            _ = try repositoryJobStore?.cancel(jobID)
            reloadRepositoryJobs()
            repositoryError = nil
        } catch {
            repositoryError = "This repository job could not be cancelled locally."
        }
    }

    func resumeRepositoryJob(_ jobID: UUID) {
        guard !isRepositoryIndexing,
              let repositoryJobStore,
              let presentation = repositoryJobs.first(where: { $0.id == jobID }),
              presentation.availableAction == .resume else {
            return
        }
        do {
            guard let job = try repositoryJobStore.record(id: jobID) else {
                repositoryError = "This repository job is no longer available."
                return
            }
            runRepositoryJob(
                job.id,
                root: URL(filePath: job.canonicalPath),
                databaseURL: try LocalVaultPaths.databaseURL(),
                contentRootURL: try LocalVaultPaths.contentURL()
            )
        } catch {
            repositoryError = "This repository job could not be resumed locally."
        }
    }

    private func runRepositoryJob(
        _ jobID: UUID,
        root: URL,
        databaseURL: URL,
        contentRootURL: URL
    ) {
        isRepositoryIndexing = true
        activeRepositoryJobID = jobID
        let cancellation = RepositoryIndexCancellation()
        repositoryIndexCancellation = cancellation
        repositoryError = nil
        Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try RepositoryJobRunner.run(
                        jobID: jobID,
                        root: root,
                        databaseURL: databaseURL,
                        contentRootURL: contentRootURL,
                        cancellation: cancellation
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
            self?.activeRepositoryJobID = nil
            self?.reloadRepositoryJobs()
        }
    }

    func cancelRepositoryIndexing() {
        guard let activeRepositoryJobID else { return }
        cancelRepositoryJob(activeRepositoryJobID)
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

    func analyzeSelectedRepositorySemantics() {
        guard !isRepositorySemanticAnalyzing else { return }
        guard let snapshot = repositorySnapshot else {
            repositoryError =
                "Inspect a clean local repository before analyzing bounded evidence."
            return
        }
        guard !snapshot.isDirty else {
            repositoryError =
                "Repository evidence analysis requires a clean committed snapshot."
            return
        }

        let root = URL(filePath: snapshot.canonicalPath)
        let analyze = repositorySemanticOperations.analyze
        let runID = UUID()
        activeRepositorySemanticRunID = runID
        repositorySemanticAnalysis = nil
        repositorySemanticStatus = nil
        repositoryIdeaProposal = nil
        repositoryIdeaCard = nil
        repositoryIdeaTask = nil
        repositoryIdeaResearchPlan = nil
        repositoryIdeaCodexPlan = nil
        repositoryIdeaDisposition = nil
        repositoryError = nil
        isRepositorySemanticAnalyzing = true
        repositorySemanticTask = Task { [weak self] in
            do {
                let worker = Task.detached(
                    priority: .userInitiated
                ) {
                    try await analyze(root, snapshot)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = result
                self?.repositorySemanticStatus = result.didAbstain
                    ? "The selected local model abstained. No repository idea was created or retained."
                    : "Ephemeral local-model candidate ready for review. Nothing was retained or promoted."
                self?.repositoryError = nil
            } catch is CancellationError {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus =
                    "Local repository evidence analysis was cancelled. No result was retained."
                self?.repositoryError = nil
            } catch RepositorySemanticV3RuntimeBundleError.snapshotDrift {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus = nil
                self?.repositoryError =
                    "The repository changed after inspection. Reinspect a clean commit before analyzing it."
            } catch RepositorySemanticV3RuntimeBundleError
                .dirtySnapshotNotEligible {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus = nil
                self?.repositoryError =
                    "Repository evidence analysis requires a clean committed snapshot."
            } catch RepositorySemanticV3RuntimeBundleError
                .insufficientEvidence {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus = nil
                self?.repositoryError =
                    "This commit does not contain both bounded support and counterevidence for local-model analysis. No model request occurred."
            } catch RepositorySemanticV3RuntimeBundleError
                .evidenceBoundsExceeded {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus = nil
                self?.repositoryError =
                    "A selected repository evidence excerpt exceeded the local analysis bound. No model request occurred."
            } catch {
                guard self?.activeRepositorySemanticRunID == runID else {
                    return
                }
                self?.repositorySemanticAnalysis = nil
                self?.repositorySemanticStatus = nil
                self?.repositoryError =
                    "The selected local model could not analyze this bounded evidence. No fallback, CAM call, or retention occurred."
            }
            guard self?.activeRepositorySemanticRunID == runID else {
                return
            }
            self?.isRepositorySemanticAnalyzing = false
            self?.repositorySemanticTask = nil
            self?.activeRepositorySemanticRunID = nil
        }
    }

    func cancelRepositorySemanticAnalysis() {
        repositorySemanticTask?.cancel()
    }

    func createRepositorySemanticIdeaProposal() {
        guard let snapshot = repositorySnapshot,
              let validated = repositorySemanticAnalysis?
                .validatedCandidate,
              validated.snapshotCommit == snapshot.commit else {
            repositoryError =
                "Analyze a clean commit and review an accepted ephemeral candidate before creating an idea."
            return
        }
        do {
            let card = try validated.ideaCard(
                id: UUID().uuidString,
                title: repositoryIdeaTitle.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                rejectedAlternatives: [
                    repositorySemanticRejectedAlternative,
                ],
                validationExperiment:
                    repositoryIdeaValidationExperiment
            )
            repositoryIdeaProposal = try card.promote(
                snapshot: snapshot
            )
            repositoryIdeaCard = card
            repositoryIdeaTask = nil
            repositoryIdeaResearchPlan = nil
            repositoryIdeaCodexPlan = nil
            repositoryIdeaDisposition = nil
            repositoryError = nil
        } catch {
            repositoryIdeaProposal = nil
            repositoryIdeaCard = nil
            repositoryIdeaTask = nil
            repositoryIdeaResearchPlan = nil
            repositoryIdeaCodexPlan = nil
            repositoryIdeaDisposition = nil
            repositoryError =
                "Enter an idea title, one rejected alternative, and the smallest validation experiment."
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
        repositorySemanticTask?.cancel()
        repositorySemanticTask = nil
        activeRepositorySemanticRunID = nil
        isRepositorySemanticAnalyzing = false
        repositorySemanticAnalysis = nil
        repositorySemanticStatus = nil
        repositoryObservationEvidence = []
        repositoryObservations = []
        selectedRepositoryObservationID = nil
        repositoryIdeaTitle = ""
        repositoryIdeaCounterevidence = ""
        repositorySemanticRejectedAlternative = ""
        repositoryIdeaValidationExperiment = ""
        repositoryIdeaProposal = nil
        repositoryIdeaCard = nil
        repositoryIdeaTask = nil
        repositoryIdeaResearchPlan = nil
        repositoryIdeaCodexPlan = nil
        repositoryIdeaDisposition = nil
    }
}
