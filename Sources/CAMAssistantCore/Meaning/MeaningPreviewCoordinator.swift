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
    case utilityOutcome(UtilityOutcome, memoryID: UUID, domain: String)
    case reject(memoryID: UUID)
    case correct(memoryID: UUID, replacement: String)
    case expire(at: Date)
}

public enum MeaningPreviewCoordinatorError: Error, Equatable {
    case accessDenied
    case staleVersion(expected: UInt64, actual: UInt64)
    case missingMemory(UUID)
    case identifierCollision(UUID)
    case feedbackUnavailable
    case feedbackDecisionMismatch
    case feedbackDomainMismatch
    case sensitiveCorrection
}

public actor MeaningPreviewCoordinator {
    private let store: any MeaningPreviewStateStoring
    private let adapter: CAMMeaningContextAdapter
    private let utility: UtilitySpine
    private let projections: HostProjections
    private let auditSink: (any MeaningPreviewAuditRecording)?
    private let proposalAdapter: MeaningActionProposalAdapter
    private var snapshot: MeaningPreviewSnapshot
    private var surfacedDecision: SurfacedDecision?
    private var auditDeliveryHealthy = true

    public init(
        store: any MeaningPreviewStateStoring,
        adapter: CAMMeaningContextAdapter = .init(),
        utility: UtilitySpine = .init(),
        projections: HostProjections = .init(),
        auditSink: (any MeaningPreviewAuditRecording)? = nil,
        proposalAdapter: MeaningActionProposalAdapter = .init()
    ) throws {
        self.store = store
        self.adapter = adapter
        self.utility = utility
        self.projections = projections
        self.auditSink = auditSink
        self.proposalAdapter = proposalAdapter

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
        surfacedDecision = result.practical.map {
            SurfacedDecision(
                memoryID: $0.id,
                domain: selectionDomain(projection),
                presentationVersion: nextSnapshot.revision,
                at: now
            )
        }
        deliverAudit(
            MeaningPreviewAuditReceipt(
                timestamp: now,
                decisionID: result.practical?.id.uuidString ?? "silence",
                version: nextSnapshot.revision,
                status: .succeeded,
                reason: .surfaced,
                exclusions: projection.exclusions.values.sorted { $0.rawValue < $1.rawValue }
            )
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

        case let .utilityOutcome(outcome, memoryID, domain):
            guard let surfacedDecision else {
                throw MeaningPreviewCoordinatorError.feedbackUnavailable
            }
            guard surfacedDecision.presentationVersion == expectedVersion,
                  surfacedDecision.memoryID == memoryID else {
                throw MeaningPreviewCoordinatorError.feedbackDecisionMismatch
            }
            guard surfacedDecision.domain == domain else {
                throw MeaningPreviewCoordinatorError.feedbackDomainMismatch
            }
            state.recordUtilityOutcome(outcome, domain: domain)
            stateChange = nil

        case let .reject(memoryID):
            guard state.memory.contains(where: { $0.id == memoryID }) else {
                throw MeaningPreviewCoordinatorError.missingMemory(memoryID)
            }
            var feedback = state.resurfacingFeedback[memoryID] ?? ResurfacingFeedback()
            feedback.rejected = true
            state.resurfacingFeedback[memoryID] = feedback
            stateChange = nil

        case let .correct(memoryID, replacement):
            guard Self.isSafeCorrection(replacement) else {
                throw MeaningPreviewCoordinatorError.sensitiveCorrection
            }
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
        recordMutationAudit(mutation, version: nextSnapshot.revision)
        surfacedDecision = retainedDecision(after: mutation)
        return stateChange
    }

    public func proposeAction(
        id: String,
        kind: MeaningActionProposalKind,
        description: String,
        requestedRole: ModelRouteRole? = .local,
        at: Date
    ) throws -> MeaningActionProposal {
        let proposal = proposalAdapter.propose(
            id: id,
            kind: kind,
            description: description,
            requestedRole: requestedRole,
            stateVersion: Int(clamping: snapshot.revision)
        )
        deliverAudit(
            MeaningPreviewAuditReceipt(
                timestamp: at,
                decisionID: id,
                version: snapshot.revision,
                status: proposal.privacyDecision == .blocked ? .denied : .proposed,
                reason: proposal.privacyDecision == .blocked ? .proposalBlocked : .proposalOnly,
                riskClass: proposal.riskClass,
                privacyDecision: proposal.privacyDecision,
                outboundByteCount: proposal.outboundByteCount
            )
        )
        return proposal
    }

    public func auditDeliveryIsHealthy() -> Bool {
        auditDeliveryHealthy
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

    private func selectionDomain(_ projection: MeaningContextProjection) -> String {
        projection.context.topics.first ?? ""
    }

    private func recordMutationAudit(
        _ mutation: MeaningPreviewMutation,
        version: UInt64
    ) {
        guard let auditSink else { return }
        let receipt: MeaningPreviewAuditReceipt
        switch mutation {
        case let .action(action, memoryID, date):
            let reason: MeaningPreviewAuditReason = switch action {
            case .now: .now
            case .later: .later
            case .release: .released
            }
            receipt = .init(
                timestamp: date,
                decisionID: memoryID.uuidString,
                version: version,
                status: .succeeded,
                reason: reason
            )
        case let .utilityOutcome(outcome, memoryID, _):
            receipt = .init(
                timestamp: surfacedDecision?.at ?? Date(timeIntervalSince1970: 0),
                decisionID: memoryID.uuidString,
                version: version,
                status: .succeeded,
                reason: outcome == .helpful ? .helpful : .notHelpful
            )
        case let .reject(memoryID):
            receipt = .init(
                timestamp: Date(timeIntervalSince1970: 0),
                decisionID: memoryID.uuidString,
                version: version,
                status: .succeeded,
                reason: .rejected
            )
        case let .correct(memoryID, _):
            receipt = .init(
                timestamp: Date(timeIntervalSince1970: 0),
                decisionID: memoryID.uuidString,
                version: version,
                status: .succeeded,
                reason: .corrected
            )
        case .expire:
            receipt = .init(
                timestamp: Date(timeIntervalSince1970: 0),
                decisionID: "expiry",
                version: version,
                status: .succeeded,
                reason: .expired
            )
        }
        if !auditSink.record(receipt) {
            auditDeliveryHealthy = false
        }
    }

    private func deliverAudit(_ receipt: MeaningPreviewAuditReceipt) {
        guard let auditSink else { return }
        if !auditSink.record(receipt) {
            auditDeliveryHealthy = false
        }
    }

    private func retainedDecision(after mutation: MeaningPreviewMutation) -> SurfacedDecision? {
        switch mutation {
        case .utilityOutcome, .reject, .correct, .expire, .action:
            return nil
        }
    }

    private static func isSafeCorrection(_ replacement: String) -> Bool {
        let trimmed = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 4_096 else { return false }
        switch DataClassifier().classify(trimmed).riskClass {
        case .public, .generic:
            return true
        case .contextual, .proprietary, .restricted:
            return false
        }
    }
}

private struct SurfacedDecision: Sendable {
    let memoryID: UUID
    let domain: String
    let presentationVersion: UInt64
    let at: Date
}
