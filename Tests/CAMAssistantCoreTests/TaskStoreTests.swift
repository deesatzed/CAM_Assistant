import Foundation
import Testing
@testable import CAMAssistantCore

@Test("promoted task records persist authority criteria and citations across restart")
func promotedTaskRecordsPersistAcrossRestart() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let proposal = TaskProposal(
        id: "task-1",
        title: "Review evidence",
        acceptanceCriteria: ["Read the source."],
        authority: .localRead,
        citations: [Citation(sourceID: "source", passageID: "passage", quote: "evidence")]
    )

    try TaskStore(databaseURL: databaseURL).save(proposal)
    let restored = try TaskStore(databaseURL: databaseURL).all()

    #expect(restored.count == 1)
    #expect(restored[0].proposal == proposal)
    #expect(restored[0].status == .open)
}

@Test("task list presentation preserves task authority and citation count")
func taskListPresentationPreservesTaskAuthorityAndCitationCount() {
    let proposal = TaskProposal(
        id: "task-1",
        title: "Review evidence",
        acceptanceCriteria: ["Read the source."],
        authority: .localRead,
        citations: [Citation(sourceID: "source", passageID: "passage", quote: "evidence")]
    )
    let presentation = TaskListPresentation(records: [
        StoredTaskRecord(proposal: proposal, status: .open, createdAt: .distantPast),
    ])

    #expect(presentation.openCount == 1)
    #expect(presentation.rows.first?.authorityLabel == "Local read")
    #expect(presentation.rows.first?.citationLabel == "1 local citation")
    #expect(presentation.rows.first?.statusLabel == "Open")
}

@Test("task status transition persists without altering the proposal")
func taskStatusTransitionPersistsWithoutAlteringProposal() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let proposal = TaskProposal(id: "task-1", title: "Review evidence", acceptanceCriteria: ["Read."], authority: .localRead, citations: [])
    try TaskStore(databaseURL: databaseURL).save(proposal)

    try TaskStore(databaseURL: databaseURL).updateStatus(.completed, for: proposal.id)
    let restored = try TaskStore(databaseURL: databaseURL).all()

    #expect(restored.first?.proposal == proposal)
    #expect(restored.first?.status == .completed)
}

@Test("task status transition rejects an unknown task")
func taskStatusTransitionRejectsAnUnknownTask() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: TaskStoreError.taskNotFound("missing")) {
        try TaskStore(databaseURL: root.appending(path: "vault.sqlite"))
            .updateStatus(.completed, for: "missing")
    }
}
