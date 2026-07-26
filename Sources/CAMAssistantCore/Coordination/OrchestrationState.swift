import CryptoKit
import Darwin
import Foundation

public enum OrchestrationStatus: String, Codable, Equatable, Sendable {
    case active
    case verifiedSuccess
    case verifiedPartial
    case blocked
    case cancelled
    case budgetExhausted
}

public enum OrchestrationEventKind: Codable, Equatable, Sendable {
    case phaseAdvanced(to: CoordinationPhase, evidenceID: String)
    case verificationPassed(evidenceID: String)
    case blocked(reason: String)
    case cancelled(reason: String)
}

/// Append-only event data. Persistence is deliberately a later layer; this
/// value makes each transition versioned and replayable before any executor
/// can be attached.
public struct OrchestrationEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let runID: String
    public let sequence: Int
    public let expectedStateVersion: Int
    public let kind: OrchestrationEventKind

    public init(
        id: UUID = UUID(),
        runID: String,
        sequence: Int,
        expectedStateVersion: Int,
        kind: OrchestrationEventKind
    ) {
        self.id = id
        self.runID = runID
        self.sequence = sequence
        self.expectedStateVersion = expectedStateVersion
        self.kind = kind
    }
}

public struct OrchestrationRunState: Codable, Equatable, Sendable {
    public let runID: String
    public let phase: CoordinationPhase
    public let status: OrchestrationStatus
    public let maxSteps: Int
    public let usedSteps: Int
    public let stateVersion: Int
    public let lastSequence: Int
    public let evidenceIDs: [String]
    public let terminalReason: String?

    public init(runID: String, maxSteps: Int) throws {
        guard !runID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              maxSteps > 0 else {
            throw OrchestrationReducerError.invalidInitialState
        }
        self.runID = runID
        phase = .observe
        status = .active
        self.maxSteps = maxSteps
        usedSteps = 0
        stateVersion = 0
        lastSequence = 0
        evidenceIDs = []
        terminalReason = nil
    }

    fileprivate init(
        runID: String,
        phase: CoordinationPhase,
        status: OrchestrationStatus,
        maxSteps: Int,
        usedSteps: Int,
        stateVersion: Int,
        lastSequence: Int,
        evidenceIDs: [String],
        terminalReason: String?
    ) {
        self.runID = runID
        self.phase = phase
        self.status = status
        self.maxSteps = maxSteps
        self.usedSteps = usedSteps
        self.stateVersion = stateVersion
        self.lastSequence = lastSequence
        self.evidenceIDs = evidenceIDs
        self.terminalReason = terminalReason
    }
}

public struct OrchestrationReducer: Sendable {
    public init() {}

    public func apply(
        event: OrchestrationEvent,
        to state: OrchestrationRunState
    ) throws -> OrchestrationRunState {
        guard event.runID == state.runID else { throw OrchestrationReducerError.runMismatch }
        guard event.expectedStateVersion == state.stateVersion else {
            throw OrchestrationReducerError.staleState(
                expected: event.expectedStateVersion,
                actual: state.stateVersion
            )
        }
        guard event.sequence == state.lastSequence + 1 else {
            throw OrchestrationReducerError.invalidSequence(
                expected: state.lastSequence + 1,
                actual: event.sequence
            )
        }
        guard state.status == .active else { throw OrchestrationReducerError.terminalState }

        let nextVersion = state.stateVersion + 1
        switch event.kind {
        case let .phaseAdvanced(to: nextPhase, evidenceID: evidenceID):
            guard !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  isLegalTransition(from: state.phase, to: nextPhase) else {
                throw OrchestrationReducerError.invalidPhaseTransition
            }
            let nextSteps = state.usedSteps + 1
            let exhausted = nextSteps > state.maxSteps
            return OrchestrationRunState(
                runID: state.runID,
                phase: nextPhase,
                status: exhausted ? .budgetExhausted : .active,
                maxSteps: state.maxSteps,
                usedSteps: nextSteps,
                stateVersion: nextVersion,
                lastSequence: event.sequence,
                evidenceIDs: state.evidenceIDs + [evidenceID],
                terminalReason: exhausted ? "Step budget exhausted." : nil
            )
        case let .verificationPassed(evidenceID: evidenceID):
            guard state.phase == .verify,
                  !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OrchestrationReducerError.missingVerificationEvidence
            }
            return OrchestrationRunState(
                runID: state.runID,
                phase: .verify,
                status: .verifiedSuccess,
                maxSteps: state.maxSteps,
                usedSteps: state.usedSteps,
                stateVersion: nextVersion,
                lastSequence: event.sequence,
                evidenceIDs: state.evidenceIDs + [evidenceID],
                terminalReason: nil
            )
        case let .blocked(reason: reason):
            return try terminalState(
                from: state, event: event, status: .blocked, reason: reason, stateVersion: nextVersion
            )
        case let .cancelled(reason: reason):
            return try terminalState(
                from: state, event: event, status: .cancelled, reason: reason, stateVersion: nextVersion
            )
        }
    }

    private func terminalState(
        from state: OrchestrationRunState,
        event: OrchestrationEvent,
        status: OrchestrationStatus,
        reason: String,
        stateVersion: Int
    ) throws -> OrchestrationRunState {
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReason.isEmpty else { throw OrchestrationReducerError.missingTerminalReason }
        return OrchestrationRunState(
            runID: state.runID,
            phase: state.phase,
            status: status,
            maxSteps: state.maxSteps,
            usedSteps: state.usedSteps,
            stateVersion: stateVersion,
            lastSequence: event.sequence,
            evidenceIDs: state.evidenceIDs,
            terminalReason: normalizedReason
        )
    }

    private func isLegalTransition(from current: CoordinationPhase, to next: CoordinationPhase) -> Bool {
        switch (current, next) {
        case (.observe, .plan), (.plan, .execute), (.execute, .verify),
             (.execute, .recovery), (.verify, .recovery), (.recovery, .plan):
            true
        default:
            false
        }
    }
}

public enum OrchestrationReducerError: Error, Equatable {
    case invalidInitialState
    case runMismatch
    case staleState(expected: Int, actual: Int)
    case invalidSequence(expected: Int, actual: Int)
    case terminalState
    case invalidPhaseTransition
    case missingVerificationEvidence
    case missingTerminalReason
}

/// Local, append-only-in-meaning event persistence. Each append writes a full
/// atomic replacement so a partial process write cannot become a valid log.
/// The reducer remains the sole authority for deriving state from the events.
public final class OrchestrationEventLog {
    private let url: URL
    private let lock = NSRecursiveLock()
    private var persisted: PersistedOrchestrationEventLog

    public init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            persisted = try JSONDecoder().decode(
                PersistedOrchestrationEventLog.self,
                from: Data(contentsOf: url)
            )
            switch persisted.schemaVersion {
            case 1:
                persisted.schemaVersion = 2
                try save(persisted)
            case 2:
                break
            default:
                throw OrchestrationEventLogError.unsupportedSchemaVersion(persisted.schemaVersion)
            }
        } else {
            persisted = PersistedOrchestrationEventLog()
        }
    }

    public func append(
        _ event: OrchestrationEvent,
        to state: OrchestrationRunState,
        reducer: OrchestrationReducer = OrchestrationReducer()
    ) throws -> OrchestrationRunState {
        lock.lock()
        defer { lock.unlock() }
        guard !persisted.events.contains(where: { $0.id == event.id }) else {
            throw OrchestrationEventLogError.duplicateEvent(event.id)
        }
        let expectedSequence = (persisted.events.last?.sequence ?? 0) + 1
        guard event.sequence == expectedSequence else {
            throw OrchestrationEventLogError.staleAppend(
                expectedSequence: expectedSequence,
                actualSequence: event.sequence
            )
        }
        let nextState = try reducer.apply(event: event, to: state)
        var candidate = persisted
        candidate.events.append(event)
        try save(candidate)
        persisted = candidate
        return nextState
    }

    public func events() throws -> [OrchestrationEvent] {
        lock.lock()
        defer { lock.unlock() }
        return persisted.events
    }

    public func replay(
        from initial: OrchestrationRunState,
        reducer: OrchestrationReducer = OrchestrationReducer()
    ) throws -> OrchestrationRunState {
        lock.lock()
        defer { lock.unlock() }
        return try persisted.events.reduce(initial) { state, event in
            try reducer.apply(event: event, to: state)
        }
    }

    public func snapshot(
        from initial: OrchestrationRunState,
        reducer: OrchestrationReducer = OrchestrationReducer()
    ) throws -> OrchestrationSnapshot {
        lock.lock()
        defer { lock.unlock() }
        let state = try persisted.events.reduce(initial) { state, event in
            try reducer.apply(event: event, to: state)
        }
        return OrchestrationSnapshot(
            runID: state.runID,
            eventCount: persisted.events.count,
            eventDigest: try digest(for: persisted.events),
            state: state
        )
    }

    public func validate(
        snapshot: OrchestrationSnapshot,
        from initial: OrchestrationRunState,
        reducer: OrchestrationReducer = OrchestrationReducer()
    ) throws -> OrchestrationRunState {
        lock.lock()
        defer { lock.unlock() }
        guard snapshot.schemaVersion == 2,
              snapshot.runID == initial.runID,
              snapshot.eventCount == persisted.events.count,
              snapshot.eventDigest == (try digest(for: persisted.events)) else {
            throw OrchestrationSnapshotError.staleOrInvalidSnapshot
        }
        let replayed = try persisted.events.reduce(initial) { state, event in
            try reducer.apply(event: event, to: state)
        }
        guard replayed == snapshot.state else {
            throw OrchestrationSnapshotError.staleOrInvalidSnapshot
        }
        return replayed
    }

    private func digest(for events: [OrchestrationEvent]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(events)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func save(_ value: PersistedOrchestrationEventLog) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}

public enum OrchestrationEventLogError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case duplicateEvent(UUID)
    case staleAppend(expectedSequence: Int, actualSequence: Int)
}

/// A derived resume cache. It contains no authority beyond the event log: the
/// digest, event count, and replayed state must all agree before it is usable.
public struct OrchestrationSnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let runID: String
    public let eventCount: Int
    public let eventDigest: String
    public let state: OrchestrationRunState

    public init(runID: String, eventCount: Int, eventDigest: String, state: OrchestrationRunState) {
        schemaVersion = 2
        self.runID = runID
        self.eventCount = eventCount
        self.eventDigest = eventDigest
        self.state = state
    }
}

public enum OrchestrationSnapshotError: Error, Equatable {
    case staleOrInvalidSnapshot
}

/// Atomic local persistence for a derived snapshot. Callers must validate the
/// loaded value against `OrchestrationEventLog` before using its cached state.
public final class OrchestrationSnapshotStore {
    private let url: URL
    private let lock = NSRecursiveLock()

    public init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try load()
        }
    }

    public func save(_ snapshot: OrchestrationSnapshot) throws {
        guard snapshot.schemaVersion == 2 else {
            throw OrchestrationSnapshotStoreError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    public func load() throws -> OrchestrationSnapshot {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OrchestrationSnapshotStoreError.missingSnapshot
        }
        let decoded = try JSONDecoder().decode(OrchestrationSnapshot.self, from: Data(contentsOf: url))
        switch decoded.schemaVersion {
        case 1:
            let migrated = OrchestrationSnapshot(
                runID: decoded.runID,
                eventCount: decoded.eventCount,
                eventDigest: decoded.eventDigest,
                state: decoded.state
            )
            try save(migrated)
            return migrated
        case 2:
            return decoded
        default:
            throw OrchestrationSnapshotStoreError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
    }
}

public enum OrchestrationSnapshotStoreError: Error, Equatable {
    case missingSnapshot
    case unsupportedSchemaVersion(Int)
}

private struct PersistedOrchestrationEventLog: Codable {
    var schemaVersion: Int = 2
    var events: [OrchestrationEvent] = []
}

/// Stable reference to a large local artifact. Run state carries this compact
/// reference instead of duplicating source text, traces, or receipt payloads.
public struct OrchestrationArtifactReference: Codable, Equatable, Sendable {
    public let contentID: ContentID
    public let byteCount: Int
    public let contentType: String

    public init(contentID: ContentID, byteCount: Int, contentType: String) {
        self.contentID = contentID
        self.byteCount = byteCount
        self.contentType = contentType
    }
}

public enum OrchestrationArtifactStoreError: Error, Equatable {
    case invalidContentType
    case integrityMismatch
}

/// A local operating-system lock ownership record. The opaque ID prevents a
/// different caller from releasing an owner it did not acquire.
public struct OrchestrationLease: Equatable, Sendable {
    public let id: UUID
    public let runID: String
    public let ownerID: String

    fileprivate init(id: UUID = UUID(), runID: String, ownerID: String) {
        self.id = id
        self.runID = runID
        self.ownerID = ownerID
    }
}

private final class ProcessLeaseRegistry: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var paths: Set<String> = []
}

private let processLeaseRegistry = ProcessLeaseRegistry()

/// Process-safe run ownership backed by advisory operating-system file locks.
/// The OS releases the lock when the owning process exits; the lock file stays
/// in place to avoid inode-replacement races between competing processes.
public final class OrchestrationLeaseStore {
    private struct ActiveLease {
        let lease: OrchestrationLease
        let descriptor: Int32
        let lockPath: String
    }

    private let rootDirectory: URL
    private let lock = NSRecursiveLock()
    private var active: [UUID: ActiveLease] = [:]

    public init(rootDirectory: URL) throws {
        self.rootDirectory = rootDirectory.standardizedFileURL
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    deinit {
        lock.lock()
        defer { lock.unlock() }
        for activeLease in active.values {
            _ = setLock(activeLease.descriptor, type: Int16(F_UNLCK))
            _ = Darwin.close(activeLease.descriptor)
            releaseProcessPath(activeLease.lockPath)
        }
    }

    public func acquire(runID: String, ownerID: String) throws -> OrchestrationLease {
        let normalizedRunID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOwnerID = ownerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRunID.isEmpty, !normalizedOwnerID.isEmpty else {
            throw OrchestrationLeaseError.invalidIdentity
        }

        lock.lock()
        defer { lock.unlock() }
        let path = lockURL(for: normalizedRunID).path
        try reserveProcessPath(path)
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            releaseProcessPath(path)
            throw OrchestrationLeaseError.lockFileUnavailable
        }
        guard setLock(descriptor, type: Int16(F_WRLCK)) else {
            _ = Darwin.close(descriptor)
            releaseProcessPath(path)
            throw OrchestrationLeaseError.heldByAnotherOwner
        }
        let lease = OrchestrationLease(runID: normalizedRunID, ownerID: normalizedOwnerID)
        active[lease.id] = ActiveLease(lease: lease, descriptor: descriptor, lockPath: path)
        return lease
    }

    public func release(_ lease: OrchestrationLease) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let activeLease = active[lease.id], activeLease.lease == lease else {
            throw OrchestrationLeaseError.notOwned
        }
        _ = setLock(activeLease.descriptor, type: Int16(F_UNLCK))
        _ = Darwin.close(activeLease.descriptor)
        active.removeValue(forKey: lease.id)
        releaseProcessPath(activeLease.lockPath)
    }

    public func assertOwned(_ lease: OrchestrationLease) throws {
        lock.lock()
        defer { lock.unlock() }
        guard active[lease.id]?.lease == lease else {
            throw OrchestrationLeaseError.notOwned
        }
    }

    private func lockURL(for runID: String) -> URL {
        let digest = SHA256.hash(data: Data(runID.utf8)).map { String(format: "%02x", $0) }.joined()
        return rootDirectory.appending(path: digest + ".lock")
    }

    private func setLock(_ descriptor: Int32, type: Int16) -> Bool {
        var operation = flock()
        operation.l_type = type
        operation.l_whence = Int16(SEEK_SET)
        operation.l_start = 0
        operation.l_len = 0
        return Darwin.fcntl(descriptor, F_SETLK, &operation) == 0
    }

    private func reserveProcessPath(_ path: String) throws {
        processLeaseRegistry.lock.lock()
        defer { processLeaseRegistry.lock.unlock() }
        guard !processLeaseRegistry.paths.contains(path) else {
            throw OrchestrationLeaseError.heldByAnotherOwner
        }
        processLeaseRegistry.paths.insert(path)
    }

    private func releaseProcessPath(_ path: String) {
        processLeaseRegistry.lock.lock()
        defer { processLeaseRegistry.lock.unlock() }
        processLeaseRegistry.paths.remove(path)
    }
}

public enum OrchestrationLeaseError: Error, Equatable {
    case invalidIdentity
    case lockFileUnavailable
    case heldByAnotherOwner
    case notOwned
}

public final class OrchestrationArtifactStore {
    private let contentStore: ContentStore

    public init(rootDirectory: URL) throws {
        contentStore = try ContentStore(rootDirectory: rootDirectory)
    }

    public func put(
        _ data: Data,
        contentType: String
    ) throws -> OrchestrationArtifactReference {
        let normalizedType = contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedType.isEmpty else { throw OrchestrationArtifactStoreError.invalidContentType }
        let stored = try contentStore.put(data)
        return OrchestrationArtifactReference(
            contentID: stored.id,
            byteCount: stored.byteCount,
            contentType: normalizedType
        )
    }

    public func data(for reference: OrchestrationArtifactReference) throws -> Data {
        let data = try contentStore.data(for: reference.contentID)
        let actualDigest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == reference.byteCount,
              actualDigest == reference.contentID.rawValue else {
            throw OrchestrationArtifactStoreError.integrityMismatch
        }
        return data
    }

    public func reference(
        for contentID: ContentID,
        contentType: String
    ) throws -> OrchestrationArtifactReference {
        let normalizedType = contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedType.isEmpty else { throw OrchestrationArtifactStoreError.invalidContentType }
        let data = try contentStore.data(for: contentID)
        let actualDigest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actualDigest == contentID.rawValue else {
            throw OrchestrationArtifactStoreError.integrityMismatch
        }
        return OrchestrationArtifactReference(
            contentID: contentID,
            byteCount: data.count,
            contentType: normalizedType
        )
    }

    public func objectCount() throws -> Int {
        try contentStore.objectCount()
    }
}

/// Typed local inputs for the single bounded coordination loop. These values
/// carry evidence bytes only; they cannot execute a command, invoke a model,
/// contact CAM, or grant a capability additional authority.
public enum OrchestrationLoopStep: Sendable {
    case advance(to: CoordinationPhase, evidence: Data)
    case verification(evidence: Data)
    case blocked(reason: String)
    case cancelled(reason: String)
}

/// One deterministic local coordination path. Evidence is content-addressed
/// before the event that cites it is appended, and restart state is replayed
/// from the event log rather than trusted from an independent mutable cursor.
public final class BoundedOrchestrationLoop {
    public static let evidenceContentType = "application/vnd.cam-assistant.orchestration-evidence"

    private let eventLog: OrchestrationEventLog
    private let artifactStore: OrchestrationArtifactStore
    private let reducer: OrchestrationReducer
    private let leaseStore: OrchestrationLeaseStore
    private var lease: OrchestrationLease?
    public private(set) var state: OrchestrationRunState

    public init(
        initial: OrchestrationRunState,
        eventLog: OrchestrationEventLog,
        artifactStore: OrchestrationArtifactStore,
        leaseStore: OrchestrationLeaseStore,
        ownerID: String,
        reducer: OrchestrationReducer = OrchestrationReducer()
    ) throws {
        self.eventLog = eventLog
        self.artifactStore = artifactStore
        self.reducer = reducer
        self.leaseStore = leaseStore
        let acquired = try leaseStore.acquire(runID: initial.runID, ownerID: ownerID)
        lease = acquired
        do {
            state = try eventLog.replay(from: initial, reducer: reducer)
        } catch {
            try? leaseStore.release(acquired)
            lease = nil
            throw error
        }
    }

    deinit {
        try? releaseOwnership()
    }

    @discardableResult
    public func run(_ steps: [OrchestrationLoopStep]) throws -> OrchestrationRunState {
        guard let lease else { throw OrchestrationLeaseError.notOwned }
        try leaseStore.assertOwned(lease)
        for step in steps {
            guard state.status == .active else { throw BoundedOrchestrationLoopError.terminalState }
            let event: OrchestrationEvent
            switch step {
            case let .advance(to: phase, evidence: evidence):
                event = try evidenceEvent(
                    evidence: evidence,
                    kind: { evidenceID in .phaseAdvanced(to: phase, evidenceID: evidenceID) }
                )
            case let .verification(evidence: evidence):
                event = try evidenceEvent(
                    evidence: evidence,
                    kind: { evidenceID in .verificationPassed(evidenceID: evidenceID) }
                )
            case let .blocked(reason: reason):
                event = nextEvent(kind: .blocked(reason: reason))
            case let .cancelled(reason: reason):
                event = nextEvent(kind: .cancelled(reason: reason))
            }
            state = try eventLog.append(event, to: state, reducer: reducer)
        }
        return state
    }

    public func releaseOwnership() throws {
        guard let lease else { throw OrchestrationLeaseError.notOwned }
        try leaseStore.release(lease)
        self.lease = nil
    }

    public func artifactReferences() throws -> [OrchestrationArtifactReference] {
        try state.evidenceIDs.map { evidenceID in
            try artifactStore.reference(
                for: ContentID(rawValue: evidenceID),
                contentType: Self.evidenceContentType
            )
        }
    }

    private func evidenceEvent(
        evidence: Data,
        kind: (String) -> OrchestrationEventKind
    ) throws -> OrchestrationEvent {
        guard !evidence.isEmpty else { throw BoundedOrchestrationLoopError.emptyEvidence }
        let contentID = ContentID(
            rawValue: SHA256.hash(data: evidence).map { String(format: "%02x", $0) }.joined()
        )
        let event = nextEvent(kind: kind(contentID.rawValue))
        // Reject invalid transitions before a derived artifact is written. The
        // event log repeats this reducer check when it atomically persists.
        _ = try reducer.apply(event: event, to: state)
        let reference = try artifactStore.put(evidence, contentType: Self.evidenceContentType)
        guard reference.contentID == contentID else {
            throw BoundedOrchestrationLoopError.evidenceIdentityMismatch
        }
        return event
    }

    private func nextEvent(kind: OrchestrationEventKind) -> OrchestrationEvent {
        OrchestrationEvent(
            runID: state.runID,
            sequence: state.lastSequence + 1,
            expectedStateVersion: state.stateVersion,
            kind: kind
        )
    }
}

public enum BoundedOrchestrationLoopError: Error, Equatable {
    case terminalState
    case emptyEvidence
    case evidenceIdentityMismatch
}

public struct HandoffRepositoryState: Codable, Equatable, Sendable {
    public let canonicalPath: String
    public let branch: String
    public let commit: String
    public let isDirty: Bool

    public init(canonicalPath: String, branch: String, commit: String, isDirty: Bool) {
        self.canonicalPath = canonicalPath
        self.branch = branch
        self.commit = commit
        self.isDirty = isDirty
    }
}

/// Durable continuation information. Large local evidence remains represented
/// by artifact references, preserving a compact and portable resume packet.
public struct OrchestrationHandoffPacket: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let createdAt: Date
    public let goal: String
    public let repository: HandoffRepositoryState
    public let state: OrchestrationRunState
    public let artifactReferences: [OrchestrationArtifactReference]
    public let lastVerifiedResult: String
    public let nextSafeAction: String
    public let blockers: [String]

    public init(
        createdAt: Date = Date(),
        goal: String,
        repository: HandoffRepositoryState,
        state: OrchestrationRunState,
        artifactReferences: [OrchestrationArtifactReference],
        lastVerifiedResult: String,
        nextSafeAction: String,
        blockers: [String]
    ) throws {
        schemaVersion = 1
        self.createdAt = createdAt
        self.goal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repository = repository
        self.state = state
        self.artifactReferences = artifactReferences
        self.lastVerifiedResult = lastVerifiedResult.trimmingCharacters(in: .whitespacesAndNewlines)
        self.nextSafeAction = nextSafeAction.trimmingCharacters(in: .whitespacesAndNewlines)
        self.blockers = blockers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        try validate()
    }

    public func save(to url: URL) throws {
        try validate()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> Self {
        let packet = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try packet.validate()
        return packet
    }

    public func markdown() -> String {
        let dirty = repository.isDirty ? "dirty" : "clean"
        let blockerText = blockers.isEmpty ? "None." : blockers.map { "- \($0)" }.joined(separator: "\n")
        return """
        # CAM Assistant Handoff

        ## Goal

        \(goal)

        ## Repository

        - Path: \(repository.canonicalPath)
        - Branch: \(repository.branch)
        - Commit: \(repository.commit)
        - State: \(dirty)

        ## Run

        - ID: \(state.runID)
        - Phase: \(state.phase.rawValue)
        - Status: \(state.status.rawValue)
        - State version: \(state.stateVersion)
        - Last verified result: \(lastVerifiedResult)

        ## Next safe action

        \(nextSafeAction)

        ## Blockers

        \(blockerText)
        """
    }

    private func validate() throws {
        guard schemaVersion == 1 else { throw OrchestrationHandoffError.unsupportedSchemaVersion(schemaVersion) }
        guard !goal.isEmpty, !lastVerifiedResult.isEmpty, !nextSafeAction.isEmpty,
              !repository.canonicalPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !repository.branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              repository.commit.count == 40,
              repository.commit.unicodeScalars.allSatisfy(isHexScalar),
              blockers.allSatisfy({ !$0.isEmpty }) else {
            throw OrchestrationHandoffError.invalidPacket
        }
    }

    private func isHexScalar(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value)
            || (65...70).contains(scalar.value)
            || (97...102).contains(scalar.value)
    }
}

public enum OrchestrationHandoffError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidPacket
}
