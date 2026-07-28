import Foundation
import Testing
@testable import CAMAssistantApp
@testable import CAMAssistantCore

@MainActor
@Test("app model recovers only unleased repository work and reloads cancellation")
func appModelRepositoryRecoveryAndCancellationAreDurable() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let store = try RepositoryJobStore(databaseURL: databaseURL)
    let running = try store.create(
        sourceID: nil,
        canonicalPath: "/tmp/live-app-repository"
    )
    let lease = try #require(
        try RepositoryJobLease.acquire(
            databaseURL: databaseURL,
            jobID: running.id
        )
    )
    _ = try store.start(running.id)

    let first = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: store,
        initializeFullWorkspace: false
    )
    #expect(first.repositoryJobs.first?.statusLabel == "Indexing locally")
    #expect(try store.record(id: running.id)?.status == .running)

    lease.release()
    let second = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: store,
        initializeFullWorkspace: false
    )
    #expect(second.repositoryJobs.first?.failureLabel == "Interrupted by app restart")
    #expect(try store.record(id: running.id)?.status == .failed)

    let pending = try store.create(
        sourceID: nil,
        canonicalPath: "/tmp/pending-app-repository"
    )
    second.reloadRepositoryJobs()
    second.cancelRepositoryJob(pending.id)

    #expect(try store.record(id: pending.id)?.status == .cancelled)
    #expect(
        second.repositoryJobs.first(where: { $0.id == pending.id })?
            .availableAction == .resume
    )
}
