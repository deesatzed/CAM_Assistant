import Foundation
import Testing
@testable import CAMAssistantCore

@Test("coordination run requires verification evidence before verified success")
func coordinationRunRequiresVerificationEvidenceBeforeVerifiedSuccess() throws {
    var run = try CoordinationRun(id: "run-1", maxSteps: 4)
    run = try run.advance(to: .plan, evidenceID: "observe-1")
    run = try run.advance(to: .execute, evidenceID: "plan-1")
    run = try run.advance(to: .verify, evidenceID: "execute-1")

    #expect(throws: CoordinationRunError.missingVerificationEvidence) {
        _ = try run.finishVerified(evidenceID: nil)
    }
    let finished = try run.finishVerified(evidenceID: "verify-1")
    #expect(finished.status == .verifiedSuccess)
    #expect(finished.resumeCursor == "completed:verify-1")
}

@Test("coordination budget exhaustion blocks and retains a resume cursor")
func coordinationBudgetExhaustionBlocksAndRetainsResumeCursor() throws {
    var run = try CoordinationRun(id: "run-2", maxSteps: 1)
    run = try run.advance(to: .plan, evidenceID: "observe-1")

    #expect(run.status == .blocked)
    #expect(run.resumeCursor == "blocked:budget-exhausted")
}

@Test("event reducer rejects stale transitions and requires current verification evidence")
func eventReducerRejectsStaleTransitionsAndRequiresCurrentVerificationEvidence() throws {
    var state = try OrchestrationRunState(runID: "event-run", maxSteps: 4)
    state = try OrchestrationReducer().apply(
        event: OrchestrationEvent(
            runID: "event-run",
            sequence: 1,
            expectedStateVersion: 0,
            kind: .phaseAdvanced(to: .plan, evidenceID: "observe-1")
        ),
        to: state
    )

    #expect(state.stateVersion == 1)
    #expect(state.phase == .plan)
    #expect(throws: OrchestrationReducerError.staleState(expected: 0, actual: 1)) {
        _ = try OrchestrationReducer().apply(
            event: OrchestrationEvent(
                runID: "event-run",
                sequence: 2,
                expectedStateVersion: 0,
                kind: .phaseAdvanced(to: .execute, evidenceID: "plan-1")
            ),
            to: state
        )
    }

    state = try OrchestrationReducer().apply(
        event: OrchestrationEvent(
            runID: "event-run",
            sequence: 2,
            expectedStateVersion: 1,
            kind: .phaseAdvanced(to: .execute, evidenceID: "plan-1")
        ),
        to: state
    )
    state = try OrchestrationReducer().apply(
        event: OrchestrationEvent(
            runID: "event-run",
            sequence: 3,
            expectedStateVersion: 2,
            kind: .phaseAdvanced(to: .verify, evidenceID: "execute-1")
        ),
        to: state
    )
    state = try OrchestrationReducer().apply(
        event: OrchestrationEvent(
            runID: "event-run",
            sequence: 4,
            expectedStateVersion: 3,
            kind: .verificationPassed(evidenceID: "verify-1")
        ),
        to: state
    )

    #expect(state.status == .verifiedSuccess)
    #expect(state.evidenceIDs == ["observe-1", "plan-1", "execute-1", "verify-1"])
}

@Test("event log persists ordered events and rebuilds identical state after restart")
func eventLogPersistsOrderedEventsAndRebuildsIdenticalStateAfterRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let logURL = root.appending(path: "events.json")
    let initial = try OrchestrationRunState(runID: "restart-run", maxSteps: 3)
    let first = OrchestrationEvent(
        runID: "restart-run",
        sequence: 1,
        expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "observe-1")
    )
    let second = OrchestrationEvent(
        runID: "restart-run",
        sequence: 2,
        expectedStateVersion: 1,
        kind: .phaseAdvanced(to: .execute, evidenceID: "plan-1")
    )

    let initialLog = try OrchestrationEventLog(url: logURL)
    let afterFirst = try initialLog.append(first, to: initial)
    let afterSecond = try initialLog.append(second, to: afterFirst)

    let reopenedLog = try OrchestrationEventLog(url: logURL)
    #expect(try reopenedLog.events() == [first, second])
    #expect(try reopenedLog.replay(from: initial) == afterSecond)
}

@Test("event log rejects a stale writer sequence before persisting it")
func eventLogRejectsStaleWriterSequenceBeforePersistingIt() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let log = try OrchestrationEventLog(url: root.appending(path: "events.json"))
    let initial = try OrchestrationRunState(runID: "writer-run", maxSteps: 3)
    let first = OrchestrationEvent(
        runID: "writer-run",
        sequence: 1,
        expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "observe-1")
    )
    _ = try log.append(first, to: initial)
    let stale = OrchestrationEvent(
        runID: "writer-run",
        sequence: 1,
        expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "different-observe")
    )

    #expect(throws: OrchestrationEventLogError.staleAppend(expectedSequence: 2, actualSequence: 1)) {
        _ = try log.append(stale, to: initial)
    }
    #expect(try log.events() == [first])
}

@Test("orchestration artifacts are content-addressed and integrity-checked after restart")
func orchestrationArtifactsAreContentAddressedAndIntegrityCheckedAfterRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = try OrchestrationArtifactStore(rootDirectory: root)
    let reference = try original.put(
        Data("synthetic orchestration evidence".utf8),
        contentType: "text/plain"
    )

    let reopened = try OrchestrationArtifactStore(rootDirectory: root)
    #expect(try reopened.data(for: reference) == Data("synthetic orchestration evidence".utf8))

    let forged = OrchestrationArtifactReference(
        contentID: reference.contentID,
        byteCount: reference.byteCount + 1,
        contentType: reference.contentType
    )
    #expect(throws: OrchestrationArtifactStoreError.integrityMismatch) {
        _ = try reopened.data(for: forged)
    }
}

@Test("handoff packet persists machine state and emits a human-readable next action")
func handoffPacketPersistsMachineStateAndEmitsHumanReadableNextAction() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try OrchestrationRunState(runID: "handoff-run", maxSteps: 3)
    let packet = try OrchestrationHandoffPacket(
        goal: "Verify a local synthetic run.",
        repository: HandoffRepositoryState(
            canonicalPath: "/tmp/cam-assistant",
            branch: "feature/coordination",
            commit: String(repeating: "a", count: 40),
            isDirty: true
        ),
        state: state,
        artifactReferences: [],
        lastVerifiedResult: "No verification has run.",
        nextSafeAction: "Advance the run to plan with current evidence.",
        blockers: []
    )
    let url = root.appending(path: "handoff.json")

    try packet.save(to: url)
    let restored = try OrchestrationHandoffPacket.load(from: url)

    #expect(restored == packet)
    #expect(packet.markdown().contains("Advance the run to plan with current evidence."))
    #expect(packet.markdown().contains("feature/coordination"))
}

@Test("bounded local loop persists evidence before it advances each phase")
func boundedLocalLoopPersistsEvidenceBeforeItAdvancesEachPhase() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try OrchestrationRunState(runID: "loop-run", maxSteps: 4)
    let log = try OrchestrationEventLog(url: root.appending(path: "events.json"))
    let artifacts = try OrchestrationArtifactStore(rootDirectory: root.appending(path: "artifacts"))
    let leases = try OrchestrationLeaseStore(rootDirectory: root.appending(path: "leases"))
    let loop = try BoundedOrchestrationLoop(
        initial: initial,
        eventLog: log,
        artifactStore: artifacts,
        leaseStore: leases,
        ownerID: "loop-test"
    )

    let terminal = try loop.run([
        .advance(to: .plan, evidence: Data("observed local state".utf8)),
        .advance(to: .execute, evidence: Data("validated local plan".utf8)),
        .advance(to: .verify, evidence: Data("local execution receipt".utf8)),
        .verification(evidence: Data("local verification receipt".utf8)),
    ])

    #expect(terminal.status == .verifiedSuccess)
    #expect(terminal.phase == .verify)
    #expect(try loop.artifactReferences().count == 4)
    #expect(try log.events().count == 4)
}

@Test("bounded local loop replays terminal state and refuses another step")
func boundedLocalLoopReplaysTerminalStateAndRefusesAnotherStep() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try OrchestrationRunState(runID: "replay-loop", maxSteps: 4)
    let logURL = root.appending(path: "events.json")
    let artifactsURL = root.appending(path: "artifacts")
    let leases = try OrchestrationLeaseStore(rootDirectory: root.appending(path: "leases"))
    let original = try BoundedOrchestrationLoop(
        initial: initial,
        eventLog: try OrchestrationEventLog(url: logURL),
        artifactStore: try OrchestrationArtifactStore(rootDirectory: artifactsURL),
        leaseStore: leases,
        ownerID: "original-owner"
    )
    let terminal = try original.run([
        .advance(to: .plan, evidence: Data("observe".utf8)),
        .advance(to: .execute, evidence: Data("plan".utf8)),
        .advance(to: .verify, evidence: Data("execute".utf8)),
        .verification(evidence: Data("verify".utf8)),
    ])
    let references = try original.artifactReferences()
    try original.releaseOwnership()

    let reopened = try BoundedOrchestrationLoop(
        initial: initial,
        eventLog: try OrchestrationEventLog(url: logURL),
        artifactStore: try OrchestrationArtifactStore(rootDirectory: artifactsURL),
        leaseStore: leases,
        ownerID: "reopened-owner"
    )

    #expect(reopened.state == terminal)
    #expect(try reopened.artifactReferences() == references)
    #expect(throws: BoundedOrchestrationLoopError.terminalState) {
        _ = try reopened.run([.advance(to: .recovery, evidence: Data("nope".utf8))])
    }
}

@Test("bounded local loop rejects an invalid step before storing its evidence")
func boundedLocalLoopRejectsAnInvalidStepBeforeStoringItsEvidence() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let artifacts = try OrchestrationArtifactStore(rootDirectory: root.appending(path: "artifacts"))
    let loop = try BoundedOrchestrationLoop(
        initial: try OrchestrationRunState(runID: "invalid-loop", maxSteps: 2),
        eventLog: try OrchestrationEventLog(url: root.appending(path: "events.json")),
        artifactStore: artifacts,
        leaseStore: try OrchestrationLeaseStore(rootDirectory: root.appending(path: "leases")),
        ownerID: "invalid-owner"
    )

    #expect(throws: OrchestrationReducerError.missingVerificationEvidence) {
        _ = try loop.run([.verification(evidence: Data("invalid timing".utf8))])
    }
    #expect(try artifacts.objectCount() == 0)
}

@Test("orchestration ownership rejects a second local owner until release")
func orchestrationOwnershipRejectsSecondLocalOwnerUntilRelease() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let firstStore = try OrchestrationLeaseStore(rootDirectory: root)
    let secondStore = try OrchestrationLeaseStore(rootDirectory: root)
    let first = try firstStore.acquire(runID: "owned-run", ownerID: "first-owner")

    #expect(throws: OrchestrationLeaseError.heldByAnotherOwner) {
        _ = try secondStore.acquire(runID: "owned-run", ownerID: "second-owner")
    }

    try firstStore.release(first)
    let second = try secondStore.acquire(runID: "owned-run", ownerID: "second-owner")
    #expect(second.runID == "owned-run")
    try secondStore.release(second)
}

@Test("bounded loop requires exclusive ownership and permits a released successor")
func boundedLoopRequiresExclusiveOwnershipAndPermitsAReleasedSuccessor() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try OrchestrationRunState(runID: "loop-owner-run", maxSteps: 2)
    let leases = try OrchestrationLeaseStore(rootDirectory: root.appending(path: "leases"))
    let first = try BoundedOrchestrationLoop(
        initial: initial,
        eventLog: try OrchestrationEventLog(url: root.appending(path: "events.json")),
        artifactStore: try OrchestrationArtifactStore(rootDirectory: root.appending(path: "artifacts")),
        leaseStore: leases,
        ownerID: "first-owner"
    )

    #expect(throws: OrchestrationLeaseError.heldByAnotherOwner) {
        _ = try BoundedOrchestrationLoop(
            initial: initial,
            eventLog: try OrchestrationEventLog(url: root.appending(path: "events.json")),
            artifactStore: try OrchestrationArtifactStore(rootDirectory: root.appending(path: "artifacts")),
            leaseStore: leases,
            ownerID: "second-owner"
        )
    }

    try first.releaseOwnership()
    let successor = try BoundedOrchestrationLoop(
        initial: initial,
        eventLog: try OrchestrationEventLog(url: root.appending(path: "events.json")),
        artifactStore: try OrchestrationArtifactStore(rootDirectory: root.appending(path: "artifacts")),
        leaseStore: leases,
        ownerID: "second-owner"
    )
    try successor.releaseOwnership()
}

@Test("orchestration ownership excludes a forked process at the operating-system lock")
func orchestrationOwnershipExcludesForkedProcessAtOperatingSystemLock() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let runID = "forked-owner-run"
    let lockRoot = root.appending(path: "locks")
    let store = try OrchestrationLeaseStore(rootDirectory: lockRoot)
    let parentLease = try store.acquire(runID: runID, ownerID: "parent")
    let child = Process()
    child.executableURL = try debugCLIURL()
    child.arguments = [
        "orchestration-lock-probe", lockRoot.path, runID,
    ]
    try child.run()
    child.waitUntilExit()
    #expect(child.terminationStatus == 75)
    try store.release(parentLease)
}

@Test("event log derives a digest-bound snapshot that validates after restart")
func eventLogDerivesDigestBoundSnapshotThatValidatesAfterRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try OrchestrationRunState(runID: "snapshot-run", maxSteps: 3)
    let first = OrchestrationEvent(
        runID: "snapshot-run", sequence: 1, expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "observe")
    )
    let second = OrchestrationEvent(
        runID: "snapshot-run", sequence: 2, expectedStateVersion: 1,
        kind: .phaseAdvanced(to: .execute, evidenceID: "plan")
    )
    let log = try OrchestrationEventLog(url: root.appending(path: "events.json"))
    let afterFirst = try log.append(first, to: initial)
    let expected = try log.append(second, to: afterFirst)
    let snapshot = try log.snapshot(from: initial)

    let reopened = try OrchestrationEventLog(url: root.appending(path: "events.json"))
    #expect(try reopened.validate(snapshot: snapshot, from: initial) == expected)
    #expect(snapshot.eventCount == 2)
}

@Test("persisted orchestration snapshot is rejected after the event log advances")
func persistedOrchestrationSnapshotIsRejectedAfterTheEventLogAdvances() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let initial = try OrchestrationRunState(runID: "stale-snapshot-run", maxSteps: 4)
    let log = try OrchestrationEventLog(url: root.appending(path: "events.json"))
    let first = OrchestrationEvent(
        runID: initial.runID, sequence: 1, expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "observe")
    )
    let afterFirst = try log.append(first, to: initial)
    let snapshot = try log.snapshot(from: initial)
    let store = try OrchestrationSnapshotStore(url: root.appending(path: "snapshot.json"))
    try store.save(snapshot)
    #expect(try store.load() == snapshot)

    let second = OrchestrationEvent(
        runID: initial.runID, sequence: 2, expectedStateVersion: 1,
        kind: .phaseAdvanced(to: .execute, evidenceID: "plan")
    )
    _ = try log.append(second, to: afterFirst)
    #expect(throws: OrchestrationSnapshotError.staleOrInvalidSnapshot) {
        _ = try log.validate(snapshot: try store.load(), from: initial)
    }
}

@Test("orchestration persistence migrates version one event logs and snapshots")
func orchestrationPersistenceMigratesVersionOneEventLogsAndSnapshots() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let initial = try OrchestrationRunState(runID: "migration-run", maxSteps: 2)
    let event = OrchestrationEvent(
        runID: initial.runID, sequence: 1, expectedStateVersion: 0,
        kind: .phaseAdvanced(to: .plan, evidenceID: "observe")
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let eventLogURL = root.appending(path: "events.json")
    try encoder.encode(LegacyEventLogFixture(schemaVersion: 1, events: [event])).write(to: eventLogURL)

    let migratedLog = try OrchestrationEventLog(url: eventLogURL)
    let expected = try OrchestrationReducer().apply(event: event, to: initial)
    #expect(try migratedLog.replay(from: initial) == expected)

    let snapshot = try migratedLog.snapshot(from: initial)
    let legacySnapshot = LegacySnapshotFixture(
        schemaVersion: 1,
        runID: snapshot.runID,
        eventCount: snapshot.eventCount,
        eventDigest: snapshot.eventDigest,
        state: snapshot.state
    )
    let snapshotURL = root.appending(path: "snapshot.json")
    try encoder.encode(legacySnapshot).write(to: snapshotURL)
    let migratedSnapshot = try OrchestrationSnapshotStore(url: snapshotURL).load()
    #expect(migratedSnapshot.schemaVersion == 2)
    #expect(try migratedLog.validate(snapshot: migratedSnapshot, from: initial) == expected)
}

private func debugCLIURL() throws -> URL {
    let buildRoot = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: ".swift-build")
    guard let enumerator = FileManager.default.enumerator(
        at: buildRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { throw CLITestError.executableNotFound }
    for case let candidate as URL in enumerator where candidate.lastPathComponent == "cam-assistant" {
        guard !candidate.path.contains(".dSYM"),
              candidate.pathComponents.contains("debug"),
              FileManager.default.isExecutableFile(atPath: candidate.path) else {
            continue
        }
        return candidate
    }
    throw CLITestError.executableNotFound
}

private enum CLITestError: Error { case executableNotFound }

private struct LegacyEventLogFixture: Codable {
    let schemaVersion: Int
    let events: [OrchestrationEvent]
}

private struct LegacySnapshotFixture: Codable {
    let schemaVersion: Int
    let runID: String
    let eventCount: Int
    let eventDigest: String
    let state: OrchestrationRunState
}
