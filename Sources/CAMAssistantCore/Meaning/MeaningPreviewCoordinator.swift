import Foundation
import MeaningCore

public protocol MeaningPreviewStateStoring: Sendable {
    func load() throws -> MeaningPreviewSnapshot
    func save(_ snapshot: MeaningPreviewSnapshot) throws
}

public struct MeaningPreviewAccess: Sendable, Equatable {
    public let enabled: Bool
    public let localDataGranted: Bool

    public init(enabled: Bool, localDataGranted: Bool) {
        self.enabled = enabled
        self.localDataGranted = localDataGranted
    }
}

public struct MeaningPreviewPresentation: Sendable {
    public let version: UInt64
    public let glance: GlanceProjection
    public let inspect: InspectProjection
    public let exclusions: [String: MeaningContextExclusion]

    public init(
        version: UInt64,
        glance: GlanceProjection,
        inspect: InspectProjection,
        exclusions: [String: MeaningContextExclusion]
    ) {
        self.version = version
        self.glance = glance
        self.inspect = inspect
        self.exclusions = exclusions
    }
}

public enum MeaningPreviewMutation: Sendable {
    case action(UtilityAction, memoryID: UUID, at: Date)
    case reject(memoryID: UUID)
    case correct(memoryID: UUID, replacement: String)
    case expire(at: Date)
}

public enum MeaningPreviewCoordinatorError: Error, Equatable {
    case accessDenied
    case staleVersion(expected: UInt64, actual: UInt64)
    case missingMemory(UUID)
    case identifierCollision(UUID)
}

public actor MeaningPreviewCoordinator {
    private let store: any MeaningPreviewStateStoring
    private let adapter: CAMMeaningContextAdapter
    private let utility: UtilitySpine
    private let projections: HostProjections
    private var snapshot: MeaningPreviewSnapshot

    public init(
        store: any MeaningPreviewStateStoring,
        adapter: CAMMeaningContextAdapter = .init(),
        utility: UtilitySpine = .init(),
        projections: HostProjections = .init()
    ) throws {
        self.store = store
        self.adapter = adapter
        self.utility = utility
        self.projections = projections

        let loaded = try store.load()
        self.snapshot = MeaningPreviewSnapshot(
            schemaVersion: loaded.schemaVersion,
            revision: loaded.revision,
            coreState: try loaded.coreState.migrated(),
            provenance: loaded.provenance,
            identifierOwners: loaded.identifierOwners,
            correctionLineage: loaded.correctionLineage
        )
    }

    public func requestPractical(
        access: MeaningPreviewAccess,
        selection: @Sendable () throws -> MeaningContextSelection,
        now: Date
    ) throws -> MeaningPreviewPresentation {
        guard access.enabled, access.localDataGranted else {
            throw MeaningPreviewCoordinatorError.accessDenied
        }

        let projection = adapter.project(try selection(), now: now)
        let identifierOwners = try reconciledIdentifierOwners(for: projection)
        let reconciledState = reconcile(projection: projection)
        let nextSnapshot = MeaningPreviewSnapshot(
            revision: snapshot.revision + 1,
            coreState: reconciledState,
            provenance: projection.provenance,
            identifierOwners: identifierOwners,
            correctionLineage: snapshot.correctionLineage
        )
        try store.save(nextSnapshot)
        snapshot = nextSnapshot

        let selectedIDs = Set(projection.memory.map(\.id))
        let selectedMemory = reconciledState.memory.filter { item in
            if selectedIDs.contains(item.id) {
                return true
            }
            guard
                item.source == .correction,
                let ancestorValue = nextSnapshot.correctionLineage[item.id.uuidString],
                let ancestorID = UUID(uuidString: ancestorValue),
                selectedIDs.contains(ancestorID),
                nextSnapshot.identifierOwners[ancestorID.uuidString]
                    == projection.identifierOwners[ancestorID.uuidString],
                let parentID = item.conflicts.first,
                parentID == ancestorID
                    || nextSnapshot.correctionLineage[parentID.uuidString] == ancestorValue
            else {
                return false
            }
            return true
        }
        let selectedState = CoreState(
            memory: selectedMemory,
            resurfacingFeedback: reconciledState.resurfacingFeedback,
            familiarity: reconciledState.familiarity,
            nudgeState: reconciledState.nudgeState
        )
        let result = utility.select(from: selectedState, context: projection.context)
        let glance = projections.glance(result.practical)
        let inspect = projections.inspect(
            memory: selectedState.memory,
            surfaced: result.practical,
            intrusiveness: .embedded
        )
        return MeaningPreviewPresentation(
            version: nextSnapshot.revision,
            glance: glance,
            inspect: inspect,
            exclusions: projection.exclusions
        )
    }

    @discardableResult
    public func mutate(
        _ mutation: MeaningPreviewMutation,
        expectedVersion: UInt64
    ) throws -> UtilityStateChange? {
        guard expectedVersion == snapshot.revision else {
            throw MeaningPreviewCoordinatorError.staleVersion(
                expected: expectedVersion,
                actual: snapshot.revision
            )
        }

        var state = snapshot.coreState
        var correctionLineage = snapshot.correctionLineage
        let stateChange: UtilityStateChange?
        switch mutation {
        case let .action(action, memoryID, date):
            guard let index = state.memory.firstIndex(where: { $0.id == memoryID }) else {
                throw MeaningPreviewCoordinatorError.missingMemory(memoryID)
            }
            stateChange = utility.apply(action, to: &state.memory[index], at: date)

        case let .reject(memoryID):
            guard state.memory.contains(where: { $0.id == memoryID }) else {
                throw MeaningPreviewCoordinatorError.missingMemory(memoryID)
            }
            var feedback = state.resurfacingFeedback[memoryID] ?? ResurfacingFeedback()
            feedback.rejected = true
            state.resurfacingFeedback[memoryID] = feedback
            stateChange = nil

        case let .correct(memoryID, replacement):
            var ecology = try ecology(from: state.memory)
            let previousIDs = Set(state.memory.map(\.id))
            try ecology.correct(memoryID, replacement: replacement)
            state.memory = ecology.inspect()
            for corrected in state.memory where
                !previousIDs.contains(corrected.id)
                    && corrected.source == .correction
                    && corrected.conflicts.contains(memoryID)
            {
                correctionLineage[corrected.id.uuidString]
                    = snapshot.correctionLineage[memoryID.uuidString] ?? memoryID.uuidString
            }
            stateChange = nil

        case let .expire(date):
            var ecology = try ecology(from: state.memory)
            ecology.expire(at: date)
            state.memory = ecology.inspect()
            stateChange = nil
        }

        let nextSnapshot = MeaningPreviewSnapshot(
            revision: snapshot.revision + 1,
            coreState: state,
            provenance: snapshot.provenance,
            identifierOwners: snapshot.identifierOwners,
            correctionLineage: correctionLineage
        )
        try store.save(nextSnapshot)
        snapshot = nextSnapshot
        return stateChange
    }

    private func reconcile(projection: MeaningContextProjection) -> CoreState {
        var state = snapshot.coreState
        for projected in projection.memory {
            if let index = state.memory.firstIndex(where: { $0.id == projected.id }) {
                let existing = state.memory[index]
                var refreshed = projected
                refreshed.status = existing.status
                refreshed.availableAfter = existing.availableAfter
                refreshed.version = existing.version
                refreshed.revisions = existing.revisions
                refreshed.support = existing.support
                refreshed.conflicts = existing.conflicts
                state.memory[index] = refreshed
            } else {
                state.memory.append(projected)
            }
        }
        return state
    }

    private func reconciledIdentifierOwners(
        for projection: MeaningContextProjection
    ) throws -> [String: String] {
        var owners = snapshot.identifierOwners
        for (memoryIDValue, currentOwner) in projection.identifierOwners {
            guard let memoryID = UUID(uuidString: memoryIDValue) else {
                continue
            }
            if let persistedOwner = owners[memoryIDValue], persistedOwner != currentOwner {
                throw MeaningPreviewCoordinatorError.identifierCollision(memoryID)
            }
            if owners[memoryIDValue] == nil,
               snapshot.coreState.memory.contains(where: { $0.id == memoryID }),
               !snapshot.provenance.contains(where: { $0.itemID == currentOwner }) {
                throw MeaningPreviewCoordinatorError.identifierCollision(memoryID)
            }
            owners[memoryIDValue] = currentOwner
        }
        return owners
    }

    private func ecology(from items: [MemoryItem]) throws -> MemoryEcology {
        var ecology = MemoryEcology()
        for item in items {
            try ecology.record(item)
        }
        return ecology
    }
}
