import Foundation
import Testing
@testable import CAMAssistantCore

@Test("Keep stores a concise cited memory rather than a transcript")
func keepStoresConciseCitedMemory() throws {
    let fixture = try KeptMemoryFixture()
    let receipt = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)

    #expect(receipt.memory.text == fixture.answer.text)
    #expect(receipt.memory.citations == fixture.answer.citations)
    #expect(receipt.memory.conversationTranscript == nil)
    #expect(!receipt.memory.sourceVersionIdentity.isEmpty)
    #expect(try fixture.store.all() == [receipt.memory])
}

@Test("Discard leaves no durable answer")
func discardLeavesNoDurableAnswer() throws {
    let fixture = try KeptMemoryFixture()

    try fixture.store.discard(answerID: fixture.answer.id)

    #expect(try fixture.store.all().isEmpty)
}

@Test("Undo removes only the just-kept derived memory")
func undoRemovesJustKeptMemory() throws {
    let fixture = try KeptMemoryFixture()
    let receipt = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)

    try fixture.store.undo(receipt: receipt.undoReceipt)

    #expect(try fixture.store.all().isEmpty)
}

@Test("Kept memory survives a store restart")
func keptMemorySurvivesRestart() throws {
    let fixture = try KeptMemoryFixture()
    let receipt = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)

    let restarted = KeptMemoryStore(url: fixture.storeURL)

    #expect(try restarted.all() == [receipt.memory])
}

@Test("Duplicate memory is offered as a choice and never silently merged")
func duplicateMemoryRequiresExplicitChoice() throws {
    let fixture = try KeptMemoryFixture()
    let original = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)

    let candidate = try fixture.store.duplicateCandidate(for: fixture.answer)

    #expect(candidate?.id == original.memory.id)
    #expect(try fixture.store.all().count == 1)
}

@Test("Explicit update preserves identity and refreshes citation version")
func explicitUpdateRefreshesCitationVersion() throws {
    let fixture = try KeptMemoryFixture()
    let original = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)
    let changed = fixture.answerWithChangedCitation()

    let updated = try fixture.store.keep(
        answer: changed,
        choice: .updateExisting(original.memory.id),
        now: fixture.secondDate
    )

    #expect(updated.memory.id == original.memory.id)
    #expect(updated.memory.createdAt == original.memory.createdAt)
    #expect(updated.memory.updatedAt == fixture.secondDate)
    #expect(updated.memory.citations == changed.citations)
    #expect(updated.memory.sourceVersionIdentity != original.memory.sourceVersionIdentity)

    try fixture.store.undo(receipt: updated.undoReceipt)
    #expect(try fixture.store.all() == [original.memory])
}

@Test("A stale Undo cannot remove or overwrite a newer memory")
func staleUndoCannotChangeNewerMemory() throws {
    let fixture = try KeptMemoryFixture()
    let first = try fixture.store.keep(answer: fixture.answer, now: fixture.firstDate)
    _ = try fixture.store.keep(
        answer: fixture.answerWithChangedCitation(),
        choice: .updateExisting(first.memory.id),
        now: fixture.secondDate
    )

    #expect(throws: KeptMemoryStoreError.staleUndo) {
        try fixture.store.undo(receipt: first.undoReceipt)
    }
    #expect(try fixture.store.all().count == 1)
}

private struct KeptMemoryFixture {
    let root: URL
    let storeURL: URL
    let store: KeptMemoryStore
    let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    let secondDate = Date(timeIntervalSince1970: 1_700_000_100)
    let answer: ConversationResponse

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "cam-kept-memory-\(UUID().uuidString)"
        )
        storeURL = root.appending(path: "kept-memories.json")
        store = KeptMemoryStore(url: storeURL)
        answer = ConversationResponse(
            id: "answer-1",
            text: "The appointment is Tuesday.",
            route: .localRetrieval,
            confidence: .supported,
            citations: [
                Citation(
                    sourceID: "notes",
                    passageID: "notes#0",
                    quote: "The appointment is Tuesday at 10."
                ),
            ],
            retention: .ephemeral,
            modelIdentity: nil,
            endpointIdentity: nil,
            followUp: nil
        )
    }

    func answerWithChangedCitation() -> ConversationResponse {
        ConversationResponse(
            id: "answer-2",
            text: answer.text,
            route: .localRetrieval,
            confidence: .supported,
            citations: [
                Citation(
                    sourceID: "calendar",
                    passageID: "calendar#2",
                    quote: "Calendar confirms Tuesday at 10."
                ),
            ],
            retention: .ephemeral,
            modelIdentity: nil,
            endpointIdentity: nil,
            followUp: nil
        )
    }
}
