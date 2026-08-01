import Foundation
import MeaningCore
import Testing
@testable import CAMAssistantCore

@Test("disabled and ungranted requests refuse before reading selected context")
func meaningPreviewAccessRefusesBeforeContextRead() async throws {
    let store = MemoryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let spy = MeaningSelectionSpy(selection: .fixture())

    await #expect(throws: MeaningPreviewCoordinatorError.accessDenied) {
        _ = try await coordinator.requestPractical(
            access: .init(enabled: false, localDataGranted: true),
            selection: { spy.read() },
            now: .fixed
        )
    }
    await #expect(throws: MeaningPreviewCoordinatorError.accessDenied) {
        _ = try await coordinator.requestPractical(
            access: .init(enabled: true, localDataGranted: false),
            selection: { spy.read() },
            now: .fixed
        )
    }

    #expect(spy.readCount == 0)
}

@Test("authorized empty context returns silence")
func meaningPreviewEmptyContextReturnsSilence() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())

    let result = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(items: []) },
        now: .fixed
    )

    #expect(result.glance.item == nil)
    #expect(result.glance.actions.isEmpty)
    #expect(result.inspect.itemID == nil)
}

@Test("practical selection is deterministic and returns at most one item")
func meaningPreviewReturnsOneDeterministicPracticalItem() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())
    let items = [
        MeaningContextItem.fixture(id: "zeta", text: "Review an unrelated note."),
        MeaningContextItem.fixture(id: "alpha", text: "Prepare the work outline."),
    ]

    let result = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(domain: "work", items: items) },
        now: .fixed
    )

    #expect(result.glance.item?.text == "Prepare the work outline.")
    #expect(result.glance.actions == [.now, .later, .release])
    #expect(result.inspect.itemID == result.glance.item?.id)
}

@Test("depleted capacity admits only a valid commitment due within 24 hours")
func meaningPreviewDepletedCapacityHonorsCommitmentBoundary() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())
    let factual = MeaningContextItem.fixture(id: "fact", text: "Review this work note.")
    let due = MeaningContextItem.fixture(
        id: "due",
        text: "Submit the work form.",
        kind: .commitment,
        dueAt: .fixed.addingTimeInterval(86_400)
    )

    let result = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(domain: "work", capacity: .depleted, items: [factual, due]) },
        now: .fixed
    )

    #expect(result.glance.item?.text == "Submit the work form.")
    #expect(result.glance.item?.kind == .commitment)
    #expect(result.glance.item?.expiresAt == .fixed.addingTimeInterval(86_400))

    let beyondBoundary = MeaningContextItem.fixture(
        id: "later-due",
        text: "Submit the later work form.",
        kind: .commitment,
        dueAt: .fixed.addingTimeInterval(86_401)
    )
    let boundaryCoordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())
    let suppressed = try await boundaryCoordinator.requestPractical(
        access: .authorized,
        selection: {
            .fixture(domain: "work", capacity: .depleted, items: [factual, beyondBoundary])
        },
        now: .fixed
    )
    #expect(suppressed.glance.item == nil)
}

@Test("Now changes no familiarity and Later hides until its boundary")
func meaningPreviewActionsRemainTypedAndDoNotInferHelpfulness() async throws {
    let store = MemoryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let first = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let itemID = try #require(first.glance.item?.id)

    let nowChange = try await coordinator.mutate(
        .action(.now, memoryID: itemID, at: .fixed),
        expectedVersion: first.version
    )
    #expect(nowChange?.action == .now)
    #expect(store.current.coreState.familiarity.stage(for: "work") == .usefulStranger)

    let laterChange = try await coordinator.mutate(
        .action(.later, memoryID: itemID, at: .fixed),
        expectedVersion: store.current.revision
    )
    #expect(laterChange?.nextEligibleAt == .fixed.addingTimeInterval(86_400))

    let hidden = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed.addingTimeInterval(86_399)
    )
    #expect(hidden.glance.item == nil)

    let returned = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed.addingTimeInterval(86_400)
    )
    #expect(returned.glance.item?.id == itemID)
}

@Test("Release and rejection survive coordinator restart")
func meaningPreviewReleaseAndRejectionPersistAcrossRestart() async throws {
    let releasedStore = MemoryMeaningPreviewStore()
    let firstCoordinator = try MeaningPreviewCoordinator(store: releasedStore)
    let first = try await firstCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let releasedID = try #require(first.glance.item?.id)
    _ = try await firstCoordinator.mutate(
        .action(.release, memoryID: releasedID, at: .fixed),
        expectedVersion: first.version
    )

    let restarted = try MeaningPreviewCoordinator(store: releasedStore)
    let afterRestart = try await restarted.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    #expect(afterRestart.glance.item == nil)

    let rejectedStore = MemoryMeaningPreviewStore()
    let rejectingCoordinator = try MeaningPreviewCoordinator(store: rejectedStore)
    let candidate = try await rejectingCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let rejectedID = try #require(candidate.glance.item?.id)
    _ = try await rejectingCoordinator.mutate(
        .reject(memoryID: rejectedID),
        expectedVersion: candidate.version
    )
    let rejectionRestart = try MeaningPreviewCoordinator(store: rejectedStore)
    let rejected = try await rejectionRestart.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    #expect(rejected.glance.item == nil)
}

@Test("expiry and correction preserve semantic lifecycle")
func meaningPreviewExpiryAndCorrectionPersistSemantically() async throws {
    let expiryStore = MemoryMeaningPreviewStore()
    let expiryCoordinator = try MeaningPreviewCoordinator(store: expiryStore)
    let commitment = MeaningContextItem.fixture(
        id: "deadline",
        text: "Submit the form.",
        kind: .commitment,
        dueAt: .fixed.addingTimeInterval(100)
    )
    let due = try await expiryCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(items: [commitment]) },
        now: .fixed
    )
    _ = try await expiryCoordinator.mutate(
        .expire(at: .fixed.addingTimeInterval(101)),
        expectedVersion: due.version
    )
    let expired = try await expiryCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(items: [commitment]) },
        now: .fixed.addingTimeInterval(101)
    )
    #expect(expired.glance.item == nil)

    let correctionStore = MemoryMeaningPreviewStore()
    let correctionCoordinator = try MeaningPreviewCoordinator(store: correctionStore)
    let original = try await correctionCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let originalID = try #require(original.glance.item?.id)
    _ = try await correctionCoordinator.mutate(
        .correct(memoryID: originalID, replacement: "Prepare the corrected work outline."),
        expectedVersion: original.version
    )
    let corrected = try await correctionCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    #expect(corrected.glance.item?.text == "Prepare the corrected work outline.")
    #expect(corrected.glance.item?.source == .correction)
    #expect(corrected.glance.item?.conflicts == [originalID])

    let firstCorrectionID = try #require(corrected.glance.item?.id)
    _ = try await correctionCoordinator.mutate(
        .correct(memoryID: firstCorrectionID, replacement: "Prepare the final work outline."),
        expectedVersion: corrected.version
    )
    let correctedAgain = try await correctionCoordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    #expect(correctedAgain.glance.item?.text == "Prepare the final work outline.")
    #expect(correctedAgain.glance.item?.source == .correction)
    #expect(correctedAgain.glance.item?.conflicts == [firstCorrectionID])
}

@Test("stale writes and failed saves leave revision and state unchanged")
func meaningPreviewRejectsStaleAndRollsBackFailedWrites() async throws {
    let store = MemoryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let first = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let itemID = try #require(first.glance.item?.id)
    _ = try await coordinator.mutate(
        .action(.now, memoryID: itemID, at: .fixed),
        expectedVersion: first.version
    )
    let acceptedRevision = store.current.revision

    await #expect(
        throws: MeaningPreviewCoordinatorError.staleVersion(
            expected: first.version,
            actual: acceptedRevision
        )
    ) {
        _ = try await coordinator.mutate(
            .action(.release, memoryID: itemID, at: .fixed),
            expectedVersion: first.version
        )
    }
    #expect(store.current.revision == acceptedRevision)

    store.failNextSave()
    await #expect(throws: MemoryMeaningPreviewStore.Failure.save) {
        _ = try await coordinator.mutate(
            .action(.release, memoryID: itemID, at: .fixed),
            expectedVersion: acceptedRevision
        )
    }
    #expect(store.current.revision == acceptedRevision)
    #expect(store.current.coreState.memory.first?.status == .active)

    _ = try await coordinator.mutate(
        .action(.release, memoryID: itemID, at: .fixed),
        expectedVersion: acceptedRevision
    )
    #expect(store.current.revision == acceptedRevision + 1)
    #expect(store.current.coreState.memory.first?.status == .released)
}

@Test("actor serialization admits only one writer for a shared revision")
func meaningPreviewSerializesConcurrentMutations() async throws {
    let coordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())
    let first = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture() },
        now: .fixed
    )
    let itemID = try #require(first.glance.item?.id)

    let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
        for _ in 0..<2 {
            group.addTask {
                do {
                    _ = try await coordinator.mutate(
                        .action(.now, memoryID: itemID, at: .fixed),
                        expectedVersion: first.version
                    )
                    return true
                } catch {
                    return false
                }
            }
        }
        var count = 0
        for await success in group where success { count += 1 }
        return count
    }

    #expect(successes == 1)
}

@Test("adapter fails closed for invalid commitments and duplicate identities")
func meaningPreviewAdapterRejectsInvalidCommitmentsAndIdentityCollisions() {
    let invalidCommitment = MeaningContextItem.fixture(
        id: "missing-due",
        text: "An undated commitment.",
        kind: .commitment
    )
    let duplicateA = MeaningContextItem.fixture(id: "duplicate", text: "First duplicate.")
    let duplicateB = MeaningContextItem.fixture(id: "duplicate", text: "Second duplicate.")

    let projection = CAMMeaningContextAdapter().project(
        .fixture(items: [invalidCommitment, duplicateA, duplicateB]),
        now: .fixed
    )

    #expect(projection.memory.isEmpty)
    #expect(projection.exclusions["missing-due"] == .invalidCommitment)
    #expect(projection.exclusions["duplicate"] == .identifierCollision)
}

@Test("identifier ownership persists and rejects a collision from a later request")
func meaningPreviewRejectsCrossRequestIdentifierCollision() async throws {
    let store = MemoryMeaningPreviewStore()
    let coordinator = try MeaningPreviewCoordinator(store: store)
    let firstOwner = "AxxxxxxxxxxxxxxxB"
    let collidingOwner = "BxxxxxxxxxxxxxxxA"
    let first = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(items: [.fixture(id: firstOwner)]) },
        now: .fixed
    )
    let revision = first.version
    let memoryID = try #require(first.glance.item?.id)

    await #expect(throws: MeaningPreviewCoordinatorError.identifierCollision(memoryID)) {
        _ = try await coordinator.requestPractical(
            access: .authorized,
            selection: { .fixture(items: [.fixture(id: collidingOwner)]) },
            now: .fixed
        )
    }
    #expect(store.current.revision == revision)
    #expect(store.current.identifierOwners[memoryID.uuidString] == firstOwner)
}

@Test("an unrelated persisted conflict cannot enter the current explicit selection")
func meaningPreviewRejectsUnregisteredConflictDescendant() async throws {
    let selectedItem = MeaningContextItem.fixture(id: "selected", text: "Prepare selected work.")
    let projected = CAMMeaningContextAdapter().project(
        .fixture(items: [selectedItem]),
        now: .fixed
    )
    let selectedID = try #require(projected.memory.first?.id)
    let unrelated = MemoryItem(
        kind: .commitment,
        text: "Unrelated prior work conflict.",
        source: .correction,
        observedAt: .fixed,
        conflicts: [selectedID],
        expiresAt: .fixed.addingTimeInterval(60),
        contextTags: ["work"]
    )
    let store = MemoryMeaningPreviewStore(
        snapshot: MeaningPreviewSnapshot(coreState: CoreState(memory: [unrelated]))
    )
    let coordinator = try MeaningPreviewCoordinator(store: store)

    let result = try await coordinator.requestPractical(
        access: .authorized,
        selection: { .fixture(items: [selectedItem]) },
        now: .fixed
    )

    #expect(result.glance.item?.id == selectedID)
    #expect(result.glance.item?.text == "Prepare selected work.")
}

@Test("snapshot revision decodes backward compatibly")
func meaningPreviewSnapshotDefaultsMissingRevision() throws {
    let encoded = try JSONEncoder().encode(MeaningPreviewSnapshot())
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "revision")
    let legacy = try JSONSerialization.data(withJSONObject: object)

    #expect(try JSONDecoder().decode(MeaningPreviewSnapshot.self, from: legacy).revision == 0)
}

@Test("frozen practical fixture replays with the same semantic result")
func meaningPreviewFixtureReplayIsSemanticallyDeterministic() async throws {
    let fixtureURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Fixtures/MeaningPreview/v1/practical-scenarios.json")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let fixture = try decoder.decode(
        PracticalScenarioFixture.self,
        from: Data(contentsOf: fixtureURL)
    )
    let selection = MeaningContextSelection.fixture(
        domain: fixture.domain,
        capacity: fixture.capacity,
        items: fixture.items.map {
            MeaningContextItem.fixture(id: $0.id, text: $0.text, kind: $0.kind, dueAt: $0.dueAt)
        }
    )
    var semanticResults: [String] = []
    for _ in 0..<2 {
        let coordinator = try MeaningPreviewCoordinator(store: MemoryMeaningPreviewStore())
        let result = try await coordinator.requestPractical(
            access: .authorized,
            selection: { selection },
            now: fixture.now
        )
        semanticResults.append(
            [
                result.glance.item?.text ?? "silence",
                result.glance.item?.kind.rawValue ?? "none",
                result.inspect.whySurfaced,
            ].joined(separator: "|")
        )
    }

    #expect(semanticResults == [fixture.expectedSemanticResult, fixture.expectedSemanticResult])
}

private final class MemoryMeaningPreviewStore: MeaningPreviewStateStoring, @unchecked Sendable {
    enum Failure: Error { case save }

    private let lock = NSLock()
    private var snapshot: MeaningPreviewSnapshot
    private var failSave = false

    init(snapshot: MeaningPreviewSnapshot = .init()) {
        self.snapshot = snapshot
    }

    func load() throws -> MeaningPreviewSnapshot {
        lock.withLock { snapshot }
    }

    func save(_ snapshot: MeaningPreviewSnapshot) throws {
        try lock.withLock {
            if failSave {
                failSave = false
                throw Failure.save
            }
            self.snapshot = snapshot
        }
    }

    var current: MeaningPreviewSnapshot { lock.withLock { snapshot } }

    func failNextSave() { lock.withLock { failSave = true } }
}

private struct PracticalScenarioFixture: Decodable {
    struct Item: Decodable {
        let id: String
        let text: String
        let kind: MeaningContextItemKind
        let dueAt: Date?
    }

    let now: Date
    let domain: String
    let capacity: Capacity
    let items: [Item]
    let expectedSemanticResult: String
}

private final class MeaningSelectionSpy: @unchecked Sendable {
    private let lock = NSLock()
    private let selection: MeaningContextSelection
    private var count = 0

    init(selection: MeaningContextSelection) {
        self.selection = selection
    }

    var readCount: Int { lock.withLock { count } }

    func read() -> MeaningContextSelection {
        lock.withLock { count += 1 }
        return selection
    }
}

private extension MeaningPreviewAccess {
    static let authorized = MeaningPreviewAccess(enabled: true, localDataGranted: true)
}

private extension MeaningContextSelection {
    static func fixture(
        domain: String = "work",
        capacity: Capacity = .adequate,
        items: [MeaningContextItem] = [MeaningContextItem.fixture()]
    ) -> MeaningContextSelection {
        MeaningContextSelection(
            purpose: "practical utility",
            domain: domain,
            capacity: capacity,
            selectedItems: items
        )
    }
}

private extension MeaningContextItem {
    static func fixture(
        id: String = "item",
        text: String = "Prepare the work outline.",
        kind: MeaningContextItemKind = .factual,
        dueAt: Date? = nil
    ) -> MeaningContextItem {
        MeaningContextItem(
            id: id,
            sourceID: "source-\(id)",
            derivedText: text,
            observedAt: .fixed,
            uncertainty: .supported,
            kind: kind,
            dueAt: dueAt
        )
    }
}
