import Foundation
import Testing
@testable import CAMAssistantCore

@Test("selected repository intake is read-only and captures Git evidence")
func selectedRepositoryIntakeIsReadOnlyAndCapturesGitEvidence() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let sourceURL = fixture.root.appending(path: "Sources/example.swift")
    let bytesBefore = try Data(contentsOf: sourceURL)
    let statusBefore = try fixture.git("status", "--porcelain")

    let snapshot = try RepositoryModule().intake(root: fixture.root)

    #expect(snapshot.canonicalPath == fixture.root.standardizedFileURL.path)
    #expect(snapshot.branch == "main")
    #expect(snapshot.commit.count == 40)
    #expect(snapshot.isDirty == false)
    #expect(snapshot.license == "MIT")
    let sourceEvidence = try #require(snapshot.files.first { $0.path == "Sources/example.swift" })
    #expect(sourceEvidence.lineCount == 1)
    #expect(sourceEvidence.contentDigest?.count == 64)
    #expect(try Data(contentsOf: sourceURL) == bytesBefore)
    #expect(try fixture.git("status", "--porcelain") == statusBefore)
}

@Test("repository presentation describes a selected snapshot without implying mining")
func repositoryPresentationDescribesSelectedSnapshotWithoutImplyingMining() {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: "https://example.invalid/project.git",
        branch: "main",
        commit: String(repeating: "a", count: 40),
        isDirty: true,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 1)]
    )

    let presentation = RepositoryPresentation(snapshot: snapshot)

    #expect(presentation.canonicalPath == "/tmp/example")
    #expect(presentation.commitShort == String(repeating: "a", count: 12))
    #expect(presentation.statusLabel == "Working tree has uncommitted changes")
    #expect(presentation.evidenceLabel == "1 committed file receipt")
    #expect(presentation.miningStatus == "CAM mining is disabled")
}

@Test("repository indexing presentation distinguishes new captured sources from an unchanged receipt")
func repositoryIndexingPresentationDistinguishesNewCapturedSourcesFromUnchangedReceipt() {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "a", count: 40),
        isDirty: false,
        license: "MIT",
        files: []
    )
    let captured = RepositoryIncrementalIndexResult(
        snapshot: snapshot,
        comparison: nil,
        saveResult: .recorded,
        capturedSourceIDs: [ContentID(rawValue: "one"), ContentID(rawValue: "two")]
    )
    let unchanged = RepositoryIncrementalIndexResult(
        snapshot: snapshot,
        comparison: nil,
        saveResult: .unchanged,
        capturedSourceIDs: []
    )

    #expect(RepositoryIndexPresentation(result: captured).statusLabel == "Indexed 2 committed sources locally")
    #expect(RepositoryIndexPresentation(result: unchanged).statusLabel == "Current commit is already indexed locally")
    #expect(RepositoryIndexPresentation(result: captured).miningStatus == "CAM mining is disabled")
}

@Test("repository observation presentation preserves exact commit cited evidence")
func repositoryObservationPresentationPreservesExactCommitCitedEvidence() {
    let observation = RepositoryObservation(
        snapshotCommit: String(repeating: "a", count: 40),
        filePath: "Sources/Example.swift",
        line: 12,
        symbol: "reviewMe",
        statement: "Committed Swift func declaration requires review."
    )

    let presentation = RepositoryObservationPresentation(observation: observation)

    #expect(presentation.commitShort == String(repeating: "a", count: 12))
    #expect(presentation.filePath == "Sources/Example.swift")
    #expect(presentation.line == 12)
    #expect(presentation.symbol == "reviewMe")
    #expect(presentation.statement == "Committed Swift func declaration requires review.")
}

@Test("repository local index operation owns vault dependencies and returns a receipt")
func repositoryLocalIndexOperationOwnsVaultDependenciesAndReturnsAReceipt() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }

    let result = try RepositoryLocalIndexOperation.index(
        root: fixture.root,
        databaseURL: vaultRoot.appending(path: "vault.sqlite"),
        contentRootURL: vaultRoot.appending(path: "content")
    )

    #expect(result.saveResult == .recorded)
    #expect(result.capturedSourceIDs.count == 3)
}

@Test("repository jobs recover interrupted running work after restart")
func repositoryJobsRecoverInterruptedRunningWorkAfterRestart() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let sourceID = UUID()
    let createdAt = Date(timeIntervalSince1970: 100)

    let initialStore = try RepositoryJobStore(databaseURL: databaseURL)
    let created = try initialStore.create(
        sourceID: sourceID,
        canonicalPath: "/tmp/example-repository",
        maxAttempts: 3,
        createdAt: createdAt
    )
    #expect(created.status == .pending)
    #expect(created.attempts == 0)
    #expect(
        try initialStore.start(
            created.id,
            at: Date(timeIntervalSince1970: 101)
        ).status == .running
    )
    try initialStore.close()

    let reopenedStore = try RepositoryJobStore(databaseURL: databaseURL)
    let recovered = try reopenedStore.recoverInterrupted(
        at: Date(timeIntervalSince1970: 102)
    )
    let record = try #require(try reopenedStore.record(id: created.id))

    #expect(recovered.map(\.id) == [created.id])
    #expect(record.sourceID == sourceID)
    #expect(record.canonicalPath == "/tmp/example-repository")
    #expect(record.status == .failed)
    #expect(record.attempts == 1)
    #expect(record.maxAttempts == 3)
    #expect(record.errorCode == "interrupted")
    #expect(record.createdAt == createdAt)
    #expect(record.updatedAt == Date(timeIntervalSince1970: 102))
    #expect(record.snapshotCommit == nil)
    #expect(record.capturedSourceCount == nil)
}

@Test("repository restart recovery skips a job owned by a live process lease")
func repositoryRecoverySkipsLiveJobLease() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")
    let store = try RepositoryJobStore(databaseURL: databaseURL)
    let job = try store.create(
        sourceID: nil,
        canonicalPath: "/tmp/live-repository-job"
    )
    let lease = try #require(
        try RepositoryJobLease.acquire(
            databaseURL: databaseURL,
            jobID: job.id
        )
    )
    _ = try store.start(job.id)

    #expect(try store.recoverInterrupted().isEmpty)
    #expect(try store.record(id: job.id)?.status == .running)

    lease.release()
    #expect(try store.recoverInterrupted().map(\.id) == [job.id])
    #expect(try store.record(id: job.id)?.status == .failed)
}

@Test("repository job transitions fail closed and preserve bounded attempts")
func repositoryJobTransitionsFailClosedAndPreserveBoundedAttempts() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try RepositoryJobStore(
        databaseURL: root.appending(path: "vault.sqlite")
    )
    let job = try store.create(
        sourceID: nil,
        canonicalPath: "/tmp/example-repository",
        maxAttempts: 2,
        createdAt: Date(timeIntervalSince1970: 200)
    )

    #expect(
        throws: RepositoryJobTransitionError.invalidTransition(
            from: .pending,
            to: .completed
        )
    ) {
        _ = try store.complete(
            job.id,
            snapshotCommit: String(repeating: "a", count: 40),
            capturedSourceCount: 1,
            at: Date(timeIntervalSince1970: 201)
        )
    }

    _ = try store.start(job.id, at: Date(timeIntervalSince1970: 202))
    let cancelled = try store.cancel(
        job.id,
        at: Date(timeIntervalSince1970: 203)
    )
    #expect(cancelled.status == .cancelled)
    #expect(cancelled.attempts == 1)

    _ = try store.start(job.id, at: Date(timeIntervalSince1970: 204))
    let failed = try store.fail(
        job.id,
        errorCode: "ingestion_failed",
        at: Date(timeIntervalSince1970: 205)
    )
    #expect(failed.status == .failed)
    #expect(failed.attempts == 2)
    #expect(failed.errorCode == "ingestion_failed")
    #expect(
        throws: RepositoryJobTransitionError.attemptLimitReached(job.id)
    ) {
        _ = try store.start(
            job.id,
            at: Date(timeIntervalSince1970: 206)
        )
    }
}

@Test("repository job presentation exposes only valid bounded actions")
func repositoryJobPresentationExposesOnlyValidBoundedActions() {
    let jobID = UUID()
    let base = RepositoryJobRecord(
        id: jobID,
        sourceID: nil,
        canonicalPath: "/tmp/example-repository",
        status: .pending,
        attempts: 0,
        maxAttempts: 2,
        snapshotCommit: nil,
        capturedSourceCount: nil,
        errorCode: nil,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )

    let pending = RepositoryJobPresentation(record: base)
    #expect(pending.statusLabel == "Pending local indexing")
    #expect(pending.attemptLabel == "0 of 2 attempts")
    #expect(pending.availableAction == .cancel)

    let cancelled = RepositoryJobPresentation(
        record: repositoryJobRecord(
            from: base,
            status: .cancelled,
            attempts: 1
        )
    )
    #expect(cancelled.statusLabel == "Cancelled")
    #expect(cancelled.availableAction == .resume)

    let interrupted = RepositoryJobPresentation(
        record: repositoryJobRecord(
            from: base,
            status: .failed,
            attempts: 1,
            errorCode: "interrupted"
        )
    )
    #expect(interrupted.failureLabel == "Interrupted by app restart")
    #expect(interrupted.availableAction == .resume)

    let exhausted = RepositoryJobPresentation(
        record: repositoryJobRecord(
            from: base,
            status: .failed,
            attempts: 2,
            errorCode: "operation_failed"
        )
    )
    #expect(exhausted.failureLabel == "Local repository indexing failed")
    #expect(exhausted.availableAction == nil)

    let completed = RepositoryJobPresentation(
        record: repositoryJobRecord(
            from: base,
            status: .completed,
            attempts: 1,
            snapshotCommit: String(repeating: "a", count: 40),
            capturedSourceCount: 3
        )
    )
    #expect(completed.statusLabel == "Completed")
    #expect(completed.resultLabel == "Commit aaaaaaaaaaaa · 3 local sources")
    #expect(completed.availableAction == nil)
}

@Test("persistent repository job cancels and retries without changing the repository")
func persistentRepositoryJobCancelsAndRetriesWithoutChangingRepository() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }
    let databaseURL = vaultRoot.appending(path: "vault.sqlite")
    let contentRootURL = vaultRoot.appending(path: "content")
    let sourceURL = fixture.root.appending(path: "Sources/example.swift")
    let bytesBefore = try Data(contentsOf: sourceURL)
    let statusBefore = try fixture.git("status", "--porcelain")
    let jobStore = try RepositoryJobStore(databaseURL: databaseURL)
    let job = try jobStore.create(
        sourceID: UUID(),
        canonicalPath: fixture.root.path,
        maxAttempts: 3,
        createdAt: Date(timeIntervalSince1970: 300)
    )
    try jobStore.close()

    let firstCancellation = RepositoryIndexCancellation()
    #expect(firstCancellation.cancel())
    #expect(throws: RepositoryIncrementalIndexError.cancelled) {
        _ = try RepositoryJobRunner.run(
            jobID: job.id,
            root: fixture.root,
            databaseURL: databaseURL,
            contentRootURL: contentRootURL,
            cancellation: firstCancellation,
            capturedAt: Date(timeIntervalSince1970: 301)
        )
    }
    let cancelledStore = try RepositoryJobStore(databaseURL: databaseURL)
    let cancelled = try #require(try cancelledStore.record(id: job.id))
    #expect(cancelled.status == .cancelled)
    #expect(cancelled.attempts == 1)
    #expect(cancelled.snapshotCommit == nil)
    #expect(
        try RepositorySnapshotStore(databaseURL: databaseURL)
            .snapshots(forCanonicalPath: fixture.root.path)
            .isEmpty
    )
    try cancelledStore.close()
    #expect(try Data(contentsOf: sourceURL) == bytesBefore)
    #expect(try fixture.git("status", "--porcelain") == statusBefore)

    let result = try RepositoryJobRunner.run(
        jobID: job.id,
        root: fixture.root,
        databaseURL: databaseURL,
        contentRootURL: contentRootURL,
        cancellation: RepositoryIndexCancellation(),
        capturedAt: Date(timeIntervalSince1970: 302)
    )

    let completedStore = try RepositoryJobStore(databaseURL: databaseURL)
    let completed = try #require(try completedStore.record(id: job.id))
    #expect(completed.status == .completed)
    #expect(completed.attempts == 2)
    #expect(completed.snapshotCommit == result.snapshot.commit)
    #expect(completed.capturedSourceCount == result.capturedSourceIDs.count)
    #expect(
        try RepositorySnapshotStore(databaseURL: databaseURL)
            .snapshots(forCanonicalPath: fixture.root.path)
            .last?.commit == completed.snapshotCommit
    )
    let queue = try IngestQueue(
        databaseURL: databaseURL,
        contentStore: try ContentStore(rootDirectory: contentRootURL),
        extractors: .localDefaults
    )
    #expect(try queue.documents().count == 3)
    #expect(try Data(contentsOf: sourceURL) == bytesBefore)
    #expect(try fixture.git("status", "--porcelain") == statusBefore)
}

@Test("repository cancellation is refused after the terminal snapshot boundary")
func repositoryCancellationRefusesAfterTerminalBoundary() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }
    let databaseURL = vaultRoot.appending(path: "vault.sqlite")
    let contentRootURL = vaultRoot.appending(path: "content")
    let store = try RepositoryJobStore(databaseURL: databaseURL)
    let job = try store.create(
        sourceID: nil,
        canonicalPath: fixture.root.path
    )
    try store.close()
    let cancellation = RepositoryIndexCancellation()
    let result = try RepositoryJobRunner.run(
        jobID: job.id,
        root: fixture.root,
        databaseURL: databaseURL,
        contentRootURL: contentRootURL,
        cancellation: cancellation,
        beforeSnapshotSave: {
            #expect(cancellation.cancel() == false)
        }
    )

    let reopened = try RepositoryJobStore(databaseURL: databaseURL)
    let completed = try #require(try reopened.record(id: job.id))
    #expect(completed.status == .completed)
    #expect(completed.snapshotCommit == result.snapshot.commit)
    #expect(
        try RepositorySnapshotStore(databaseURL: databaseURL)
            .snapshots(forCanonicalPath: fixture.root.path)
            .last?.commit == result.snapshot.commit
    )
}

@Test("cancelled repository indexing never records a new snapshot receipt")
func cancelledRepositoryIndexingNeverRecordsSnapshotReceipt() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: RepositoryIncrementalIndexError.cancelled) {
        _ = try RepositoryLocalIndexOperation.index(
            root: fixture.root,
            databaseURL: root.appending(path: "vault.sqlite"),
            contentRootURL: root.appending(path: "content"),
            shouldCancel: { true }
        )
    }
    let snapshot = try RepositoryModule().intake(root: fixture.root)
    #expect(try RepositorySnapshotStore(databaseURL: root.appending(path: "vault.sqlite")).snapshots(forCanonicalPath: snapshot.canonicalPath).isEmpty)
}

@Test("repository idea cards require evidence and promote only to proposals")
func repositoryIdeaCardsRequireEvidenceAndPromoteOnlyToProposals() throws {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "a", count: 40),
        isDirty: false,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 1)]
    )
    let evidence = RepositoryObservation(
        snapshotCommit: snapshot.commit,
        filePath: "Sources/example.swift",
        line: 1,
        symbol: "evidence",
        statement: "The fixture uses an explicit evidence value."
    )
    let card = try RepositoryIdeaCard(
        id: "idea-1",
        title: "Preserve explicit evidence",
        evidence: [evidence],
        counterevidence: ["This is a minimal fixture."],
        confidence: 0.6,
        license: "MIT",
        validationExperiment: "Add a focused evidence test."
    )

    let proposal = try card.promote(snapshot: snapshot)
    #expect(proposal.kind == .researchPacket)
    #expect(proposal.sourceCommit == snapshot.commit)
    #expect(throws: RepositoryIdeaError.missingCounterevidence) {
        _ = try RepositoryIdeaCard(id: "idea-2", title: "Bad", evidence: [evidence], counterevidence: [], confidence: 0.5, license: "MIT", validationExperiment: "Test")
    }
}

@Test("repository idea card maps clean evidence to a local read task")
func repositoryIdeaCardMapsCleanEvidenceToLocalReadTask() throws {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "c", count: 40),
        isDirty: false,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 3)]
    )
    let evidence = RepositoryObservation(
        snapshotCommit: snapshot.commit,
        filePath: "Sources/example.swift",
        line: 2,
        symbol: "candidate",
        statement: "Committed Swift func declaration requires review."
    )
    let card = try RepositoryIdeaCard(
        id: "idea-task",
        title: "Review candidate",
        evidence: [evidence],
        counterevidence: ["One declaration is not proof of behavior."],
        confidence: 0.5,
        license: "MIT",
        validationExperiment: "Inspect callers and add a focused test."
    )

    let task = try card.localTask(snapshot: snapshot)

    #expect(task.authority == .localRead)
    #expect(task.title == "Review repository idea: Review candidate")
    #expect(task.acceptanceCriteria == [
        "Review cited repository evidence at commit \(snapshot.commit), Sources/example.swift:2.",
        "Run validation experiment: Inspect callers and add a focused test."
    ])
    #expect(task.citations == [
        Citation(
            sourceID: snapshot.canonicalPath,
            passageID: "\(snapshot.commit):Sources/example.swift:2",
            quote: evidence.statement
        )
    ])
    let taskRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: taskRoot) }
    let taskDatabaseURL = taskRoot.appending(path: "vault.sqlite")
    try TaskStore(databaseURL: taskDatabaseURL).save(task)
    #expect(try TaskStore(databaseURL: taskDatabaseURL).all().first?.proposal == task)

    let dirtySnapshot = RepositorySnapshot(canonicalPath: snapshot.canonicalPath, remote: snapshot.remote, branch: snapshot.branch, commit: snapshot.commit, isDirty: true, license: snapshot.license, files: snapshot.files)
    #expect(throws: RepositoryIdeaError.dirtySnapshotNotEligible) {
        _ = try card.localTask(snapshot: dirtySnapshot)
    }
}

@Test("repository idea card promotes clean cited evidence into a local research plan")
func repositoryIdeaCardPromotesToLocalResearchPlan() throws {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "f", count: 40),
        isDirty: false,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 3)]
    )
    let evidence = RepositoryObservation(
        snapshotCommit: snapshot.commit,
        filePath: "Sources/example.swift",
        line: 2,
        symbol: "candidate",
        statement: "Committed Swift func declaration requires review."
    )
    let card = try RepositoryIdeaCard(
        id: "idea-research",
        title: "Review candidate",
        evidence: [evidence],
        counterevidence: ["One declaration is not proof of behavior."],
        confidence: 0.5,
        license: "MIT",
        validationExperiment: "Inspect callers and add a focused test."
    )

    let run = try card.localResearchPlan(snapshot: snapshot)

    #expect(run.retention == .ephemeral)
    #expect(run.checkpoint == ResearchCheckpoint(phase: .planned, stateVersion: 0))
    #expect(run.queries == ["Investigate repository idea: Review candidate"])
    #expect(run.provenance == ResearchPlanProvenance(
        kind: .repositoryIdea,
        canonicalSourcePath: snapshot.canonicalPath,
        sourceCommit: snapshot.commit,
        citations: [Citation(
            sourceID: snapshot.canonicalPath,
            passageID: "\(snapshot.commit):Sources/example.swift:2",
            quote: evidence.statement
        )],
        counterevidence: ["One declaration is not proof of behavior."],
        confidence: 0.5,
        validationExperiment: "Inspect callers and add a focused test."
    ))

    let dirtySnapshot = RepositorySnapshot(canonicalPath: snapshot.canonicalPath, remote: snapshot.remote, branch: snapshot.branch, commit: snapshot.commit, isDirty: true, license: snapshot.license, files: snapshot.files)
    #expect(throws: RepositoryIdeaError.dirtySnapshotNotEligible) {
        _ = try card.localResearchPlan(snapshot: dirtySnapshot)
    }
}

@Test("repository idea card maps clean evidence to a local Codex plan handoff")
func repositoryIdeaCardMapsToLocalCodexPlanHandoff() throws {
    let snapshot = RepositorySnapshot(canonicalPath: "/tmp/example", remote: nil, branch: "main", commit: String(repeating: "b", count: 40), isDirty: false, license: "MIT", files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 2)])
    let evidence = RepositoryObservation(snapshotCommit: snapshot.commit, filePath: "Sources/example.swift", line: 1, symbol: "candidate", statement: "Candidate requires review.")
    let card = try RepositoryIdeaCard(id: "idea-codex", title: "Review candidate", evidence: [evidence], counterevidence: ["One observation is insufficient."], confidence: 0.5, license: "MIT", validationExperiment: "Inspect callers.")

    let plan = try card.localCodexPlan(snapshot: snapshot)

    #expect(plan.authority == .proposal)
    #expect(plan.title == "Codex plan handoff: Review candidate")
    #expect(plan.acceptanceCriteria == [
        "Review cited repository evidence at commit \(snapshot.commit), Sources/example.swift:1.",
        "Evaluate counterevidence: One observation is insufficient.",
        "Propose the smallest validation experiment: Inspect callers."
    ])
    #expect(plan.citations == [Citation(sourceID: snapshot.canonicalPath, passageID: "\(snapshot.commit):Sources/example.swift:1", quote: evidence.statement)])
}

@Test("repository idea cards retain explicit keep and reject decisions across restart")
func repositoryIdeaCardsRetainExplicitDecisionsAcrossRestart() throws {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "d", count: 40),
        isDirty: false,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 3)]
    )
    let evidence = RepositoryObservation(
        snapshotCommit: snapshot.commit,
        filePath: "Sources/example.swift",
        line: 2,
        symbol: "candidate",
        statement: "Committed Swift func declaration requires review."
    )
    let kept = try RepositoryIdeaCard(
        id: "kept-idea",
        title: "Keep candidate",
        evidence: [evidence],
        counterevidence: ["One declaration is not proof of behavior."],
        confidence: 0.5,
        license: "MIT",
        validationExperiment: "Inspect callers and add a focused test."
    )
    let rejected = try RepositoryIdeaCard(
        id: "rejected-idea",
        title: "Reject candidate",
        evidence: [evidence],
        counterevidence: ["The candidate may be too narrow."],
        confidence: 0.5,
        license: "MIT",
        validationExperiment: "Compare against a second repository."
    )
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appending(path: "vault.sqlite")

    let initial = try RepositoryIdeaStore(databaseURL: databaseURL)
    try initial.save(kept, snapshot: snapshot, disposition: .kept)
    try initial.save(rejected, snapshot: snapshot, disposition: .rejected)

    let restored = try RepositoryIdeaStore(databaseURL: databaseURL).all()
    #expect(restored.map(\.card) == [kept, rejected])
    #expect(restored.map(\.disposition) == [.kept, .rejected])
    #expect(restored.allSatisfy { $0.snapshotCanonicalPath == snapshot.canonicalPath && $0.snapshotCommit == snapshot.commit })

    let dirtySnapshot = RepositorySnapshot(canonicalPath: snapshot.canonicalPath, remote: snapshot.remote, branch: snapshot.branch, commit: snapshot.commit, isDirty: true, license: snapshot.license, files: snapshot.files)
    #expect(throws: RepositoryIdeaError.dirtySnapshotNotEligible) {
        try initial.save(kept, snapshot: dirtySnapshot, disposition: .kept)
    }
}

@Test("retained repository idea presentation preserves decision and commit-cited evidence")
func retainedRepositoryIdeaPresentationPreservesDecisionAndEvidence() throws {
    let card = try RepositoryIdeaCard(
        id: "idea-presentation",
        title: "Review candidate",
        evidence: [
            RepositoryObservation(
                snapshotCommit: String(repeating: "e", count: 40),
                filePath: "Sources/example.swift",
                line: 2,
                symbol: "candidate",
                statement: "Committed Swift func declaration requires review."
            ),
        ],
        counterevidence: ["One declaration is not proof of behavior."],
        confidence: 0.5,
        license: "MIT",
        validationExperiment: "Inspect callers and add a focused test."
    )
    let presentation = RepositoryIdeaListPresentation(records: [
        StoredRepositoryIdea(
            card: card,
            snapshotCanonicalPath: "/tmp/example",
            snapshotCommit: String(repeating: "e", count: 40),
            disposition: .rejected,
            recordedAt: .distantPast
        ),
    ])

    let row = try #require(presentation.rows.first)
    #expect(row.id == card.id)
    #expect(row.title == "Review candidate")
    #expect(row.dispositionLabel == "Rejected")
    #expect(row.evidenceLabel == "1 cited observation · commit eeeeeeeeeeee")
    #expect(row.counterevidence == "One declaration is not proof of behavior.")
    #expect(row.validationExperiment == "Inspect callers and add a focused test.")
}

@Test("selected repository sources persist locally and can be removed without inspecting a repository")
func selectedRepositorySourcesPersistAndCanBeRemoved() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let configurationURL = root.appending(path: "repository-sources.json")
    let service = RepositorySourceService(store: RepositorySourceConfigurationStore(url: configurationURL))

    let added = try service.add(path: "/tmp/example-repository")
    #expect(added.canonicalPath == "/tmp/example-repository")
    #expect(try RepositorySourceService(store: RepositorySourceConfigurationStore(url: configurationURL)).reload() == [added])
    #expect(throws: RepositorySourceConfigurationError.duplicatePath(added.canonicalPath)) {
        _ = try service.add(path: "/tmp/example-repository")
    }

    try service.remove(added.id)
    #expect(try RepositorySourceConfigurationStore(url: configurationURL).load().isEmpty)
}

@Test("repository source removal persists lifecycle without deleting snapshot history")
func repositorySourceRemovalPersistsLifecycleWithoutDeletingHistory() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let configurationURL = root.appending(path: "repository-sources.json")
    let databaseURL = root.appending(path: "vault.sqlite")
    let lifecycleStore = try RepositorySourceLifecycleStore(
        databaseURL: databaseURL
    )
    let service = RepositorySourceService(
        store: RepositorySourceConfigurationStore(url: configurationURL),
        lifecycleStore: lifecycleStore
    )
    let added = try service.add(path: "/tmp/example-repository")
    let active = try #require(
        try lifecycleStore.record(sourceID: added.id)
    )
    #expect(active.status == .active)

    let snapshot = RepositorySnapshot(
        canonicalPath: added.canonicalPath,
        remote: nil,
        branch: "main",
        commit: String(repeating: "a", count: 40),
        isDirty: false,
        license: "MIT",
        files: []
    )
    let snapshotStore = try RepositorySnapshotStore(databaseURL: databaseURL)
    #expect(try snapshotStore.saveIfNew(snapshot) == .recorded)

    try service.remove(added.id)

    #expect(
        try RepositorySourceConfigurationStore(url: configurationURL)
            .load()
            .isEmpty
    )
    let reopenedLifecycle = try RepositorySourceLifecycleStore(
        databaseURL: databaseURL
    )
    let removed = try #require(
        try reopenedLifecycle.record(sourceID: added.id)
    )
    #expect(removed.canonicalPath == added.canonicalPath)
    #expect(removed.status == .removed)
    #expect(
        try RepositorySnapshotStore(databaseURL: databaseURL)
            .snapshots(forCanonicalPath: added.canonicalPath) == [snapshot]
    )
}

@Test("repository source lifecycle failure rolls configuration back")
func repositorySourceLifecycleFailureRollsConfigurationBack() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let configurationURL = root.appending(path: "repository-sources.json")
    let configurationStore = RepositorySourceConfigurationStore(
        url: configurationURL
    )
    let failingLifecycle = FailingRepositorySourceLifecycleWriter()
    let addService = RepositorySourceService(
        store: configurationStore,
        lifecycleStore: failingLifecycle
    )

    #expect(throws: SyntheticRepositoryLifecycleError.writeFailed) {
        _ = try addService.add(path: "/tmp/add-rollback")
    }
    #expect(try configurationStore.load().isEmpty)

    let existing = try RepositorySource(path: "/tmp/remove-rollback")
    try configurationStore.save([existing])
    let failingRemoveLifecycle = FailingRepositorySourceLifecycleWriter(
        records: [
            RepositorySourceLifecycleRecord(
                sourceID: existing.id,
                canonicalPath: existing.canonicalPath,
                status: .active,
                updatedAt: Date()
            ),
        ]
    )
    let removeService = RepositorySourceService(
        store: configurationStore,
        lifecycleStore: failingRemoveLifecycle
    )
    _ = try removeService.reload()

    #expect(throws: SyntheticRepositoryLifecycleError.writeFailed) {
        try removeService.remove(existing.id)
    }
    #expect(try configurationStore.load() == [existing])
}

@Test("repository source reload reconciles JSON from authoritative lifecycle")
func repositorySourceReloadReconcilesCrashSplitState() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let configurationURL = root.appending(path: "repository-sources.json")
    let configurationStore = RepositorySourceConfigurationStore(
        url: configurationURL
    )
    let lifecycleStore = try RepositorySourceLifecycleStore(
        databaseURL: root.appending(path: "vault.sqlite")
    )
    let service = RepositorySourceService(
        store: configurationStore,
        lifecycleStore: lifecycleStore
    )
    let source = try service.add(path: "/tmp/crash-split-repository")

    try configurationStore.save([])
    let addRecovered = RepositorySourceService(
        store: configurationStore,
        lifecycleStore: lifecycleStore
    )
    #expect(try addRecovered.reload() == [source])
    #expect(try configurationStore.load() == [source])

    _ = try lifecycleStore.record(source, status: .removed)
    try configurationStore.save([source])
    let removeRecovered = RepositorySourceService(
        store: configurationStore,
        lifecycleStore: lifecycleStore
    )
    #expect(try removeRecovered.reload().isEmpty)
    #expect(try configurationStore.load().isEmpty)
}

@Test("repository intake receipts persist snapshots idempotently across restart")
func repositoryIntakeReceiptsPersistSnapshotsAcrossRestart() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let databaseURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let snapshot = try RepositoryModule().intake(root: fixture.root)

    let initialStore = try RepositorySnapshotStore(databaseURL: databaseURL)
    #expect(try initialStore.saveIfNew(snapshot) == .recorded)
    #expect(try initialStore.saveIfNew(snapshot) == .unchanged)
    try initialStore.close()

    let reopenedStore = try RepositorySnapshotStore(databaseURL: databaseURL)
    #expect(try reopenedStore.snapshots(forCanonicalPath: snapshot.canonicalPath) == [snapshot])
}

@Test("selected repository indexing captures permitted files locally with repository provenance")
func selectedRepositoryIndexingCapturesPermittedFilesLocallyWithRepositoryProvenance() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = fixture.root.appending(path: "Sources/example.swift")
    let bytesBefore = try Data(contentsOf: sourceURL)
    let statusBefore = try fixture.git("status", "--porcelain")
    let queue = try IngestQueue(
        databaseURL: root.appending(path: "vault.sqlite"),
        contentStore: try ContentStore(rootDirectory: root.appending(path: "content")),
        extractors: .localDefaults
    )

    let result = try RepositoryIntakeService(queue: queue).indexSelectedRepository(root: fixture.root)

    #expect(result.snapshot.commit.count == 40)
    #expect(result.capturedSourceIDs.count == 3)
    #expect(try queue.documents().count == 3)
    let provenance = try queue.provenance(for: result.capturedSourceIDs[0])
    #expect(provenance.first?.origin == .repository(
        canonicalPath: fixture.root.standardizedFileURL.path,
        commit: result.snapshot.commit
    ))
    #expect(try Data(contentsOf: sourceURL) == bytesBefore)
    #expect(try fixture.git("status", "--porcelain") == statusBefore)
}

@Test("repository comparison reports exact added removed and changed file evidence")
func repositoryComparisonReportsExactAddedRemovedAndChangedFileEvidence() throws {
    let before = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "a", count: 40),
        isDirty: false,
        license: "MIT",
        files: [
            RepositoryFileEvidence(path: "Sources/A.swift", lineCount: 1),
            RepositoryFileEvidence(path: "Sources/Removed.swift", lineCount: 3),
        ]
    )
    let after = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "b", count: 40),
        isDirty: false,
        license: "MIT",
        files: [
            RepositoryFileEvidence(path: "Sources/A.swift", lineCount: 2),
            RepositoryFileEvidence(path: "Sources/Added.swift", lineCount: 4),
        ]
    )

    let comparison = try RepositoryComparator().compare(before: before, after: after)

    #expect(comparison.fromCommit == before.commit)
    #expect(comparison.toCommit == after.commit)
    #expect(comparison.added == [RepositoryFileEvidence(path: "Sources/Added.swift", lineCount: 4)])
    #expect(comparison.removed == [RepositoryFileEvidence(path: "Sources/Removed.swift", lineCount: 3)])
    #expect(comparison.changed == [
        RepositoryFileChange(path: "Sources/A.swift", fromLineCount: 1, toLineCount: 2),
    ])
}

@Test("repository idea draft promotes only clean selected snapshot evidence")
func repositoryIdeaDraftPromotesOnlyCleanSelectedSnapshotEvidence() throws {
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/example",
        remote: nil,
        branch: "main",
        commit: String(repeating: "b", count: 40),
        isDirty: false,
        license: "MIT",
        files: [RepositoryFileEvidence(path: "Sources/example.swift", lineCount: 4)]
    )
    let evidence = RepositoryObservation(
        snapshotCommit: snapshot.commit,
        filePath: "Sources/example.swift",
        line: 2,
        symbol: "candidate",
        statement: "Committed Swift func declaration requires review."
    )
    let draft = try RepositoryIdeaDraft(
        title: "Review candidate",
        counterevidence: "One declaration is not proof of reusable behavior.",
        validationExperiment: "Inspect callers and add one focused test."
    )

    let proposal = try draft.promote(id: "idea-review", evidence: evidence, snapshot: snapshot)

    #expect(proposal == RepositoryIdeaProposal(kind: .researchPacket, sourceCommit: snapshot.commit, ideaID: "idea-review"))
    var dirtySnapshot = snapshot
    dirtySnapshot = RepositorySnapshot(canonicalPath: snapshot.canonicalPath, remote: snapshot.remote, branch: snapshot.branch, commit: snapshot.commit, isDirty: true, license: snapshot.license, files: snapshot.files)
    #expect(throws: RepositoryIdeaError.dirtySnapshotNotEligible) {
        try draft.promote(id: "idea-review", evidence: evidence, snapshot: dirtySnapshot)
    }
}

@Test("repository observation extractor returns cited TODO evidence without semantic claims")
func repositoryObservationExtractorReturnsCitedTODOEvidenceWithoutSemanticClaims() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try FileManager.default.createDirectory(
        at: fixture.root.appending(path: "Docs"),
        withIntermediateDirectories: true
    )
    try "TODO: add a deterministic repository comparison example.\n"
        .data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Docs/TODO.md"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "add todo")
    let snapshot = try RepositoryModule().intake(root: fixture.root)
    try "FIXME: this working-tree text must not replace commit-cited evidence.\n"
        .data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Docs/TODO.md"))

    let observations = try RepositoryObservationExtractor().extract(
        root: fixture.root,
        snapshot: snapshot
    )

    #expect(observations == [
        RepositoryObservation(
            snapshotCommit: snapshot.commit,
            filePath: "Docs/TODO.md",
            line: 1,
            symbol: "TODO",
            statement: "Explicit TODO marker requires review."
        ),
    ])
}

@Test("repository observation extractor returns commit-cited Swift declarations")
func repositoryObservationExtractorReturnsCommitCitedSwiftDeclarations() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try "struct SnapshotReader {}\nfunc inspect() {}\n".data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Sources/Symbols.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "add symbols")
    let snapshot = try RepositoryModule().intake(root: fixture.root)

    #expect(try RepositoryObservationExtractor().extract(root: fixture.root, snapshot: snapshot).filter {
        $0.filePath == "Sources/Symbols.swift"
    } == [
        RepositoryObservation(snapshotCommit: snapshot.commit, filePath: "Sources/Symbols.swift", line: 1, symbol: "SnapshotReader", statement: "Committed Swift struct declaration requires review."),
        RepositoryObservation(snapshotCommit: snapshot.commit, filePath: "Sources/Symbols.swift", line: 2, symbol: "inspect", statement: "Committed Swift func declaration requires review."),
    ])
}

@Test("repository observation extractor returns committed Swift import dependencies")
func repositoryObservationExtractorReturnsCommittedSwiftImportDependencies() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try "import Foundation\nimport SwiftUI\nstruct Screen {}\n".data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Sources/Imports.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "add imports")
    let snapshot = try RepositoryModule().intake(root: fixture.root)

    let imports = try RepositoryObservationExtractor().extract(root: fixture.root, snapshot: snapshot).filter {
        $0.filePath == "Sources/Imports.swift" && $0.statement.contains("module dependency")
    }

    #expect(imports == [
        RepositoryObservation(snapshotCommit: snapshot.commit, filePath: "Sources/Imports.swift", line: 1, symbol: "Foundation", statement: "Committed Swift import Foundation is a declared module dependency."),
        RepositoryObservation(snapshotCommit: snapshot.commit, filePath: "Sources/Imports.swift", line: 2, symbol: "SwiftUI", statement: "Committed Swift import SwiftUI is a declared module dependency."),
    ])
}

@Test("repository refresh persists the next snapshot and compares it to the prior local receipt")
func repositoryRefreshPersistsNextSnapshotAndComparesItToPriorLocalReceipt() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let databaseURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let store = try RepositorySnapshotStore(databaseURL: databaseURL)
    let module = RepositoryModule()
    let first = try module.intake(root: fixture.root)
    #expect(try store.saveIfNew(first) == .recorded)
    try "let next = true\n".data(using: .utf8)!.write(to: fixture.root.appending(path: "Sources/Next.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "next")

    let refresh = try RepositoryRefreshService(repositoryModule: module, snapshotStore: store)
        .refresh(root: fixture.root)

    #expect(refresh.snapshot.commit != first.commit)
    let added = try #require(refresh.comparison?.added)
    #expect(added.map(\.path) == ["Sources/Next.swift"])
    #expect(added.first?.lineCount == 1)
    #expect(added.first?.contentDigest?.count == 64)
    #expect(try store.snapshots(forCanonicalPath: first.canonicalPath).count == 2)
}

@Test("incremental repository indexing captures only changed committed permitted files")
func incrementalRepositoryIndexingCapturesOnlyChangedCommittedPermittedFiles() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }
    let queue = try IngestQueue(
        databaseURL: vaultRoot.appending(path: "vault.sqlite"),
        contentStore: try ContentStore(rootDirectory: vaultRoot.appending(path: "content")),
        extractors: .localDefaults
    )
    let receiptStore = try RepositorySnapshotStore(
        databaseURL: vaultRoot.appending(path: "repository-receipts.sqlite")
    )
    let service = RepositoryIncrementalIndexService(snapshotStore: receiptStore, queue: queue)

    let first = try service.indexChangedFiles(root: fixture.root)
    #expect(first.capturedSourceIDs.count == 3)
    #expect(try queue.documents().count == 3)

    try "let evidence = false\n".data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Sources/example.swift"))
    try "let next = true\n".data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Sources/Next.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "change committed source")
    try "let evidence = true\n".data(using: .utf8)!
        .write(to: fixture.root.appending(path: "Sources/example.swift"))

    let second = try service.indexChangedFiles(root: fixture.root)
    #expect(second.capturedSourceIDs.count == 2)
    #expect(second.comparison?.changed.map(\.path) == ["Sources/example.swift"])
    #expect(second.comparison?.added.map(\.path) == ["Sources/Next.swift"])
    #expect(try queue.documents().count == 5)
    let changedDocument = try #require((try queue.documents()).first { document in
        document.text == "let evidence = false\n"
    })
    #expect(try queue.provenance(for: changedDocument.sourceID).first?.origin == .repository(
        canonicalPath: fixture.root.standardizedFileURL.path,
        commit: second.snapshot.commit
    ))
    #expect(try Data(contentsOf: fixture.root.appending(path: "Sources/example.swift")) == "let evidence = true\n".data(using: .utf8)!)

    let replay = try service.indexChangedFiles(root: fixture.root)
    #expect(replay.capturedSourceIDs.isEmpty)
    #expect(try queue.documents().count == 5)
}

@Test("incremental repository indexing does not record a receipt when local extraction fails")
func incrementalRepositoryIndexingDoesNotRecordReceiptWhenExtractionFails() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }
    try Data([0xff]).write(to: fixture.root.appending(path: "Sources/invalid.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "add malformed source")
    let queue = try IngestQueue(
        databaseURL: vaultRoot.appending(path: "vault.sqlite"),
        contentStore: try ContentStore(rootDirectory: vaultRoot.appending(path: "content")),
        extractors: .localDefaults
    )
    let receiptStore = try RepositorySnapshotStore(
        databaseURL: vaultRoot.appending(path: "repository-receipts.sqlite")
    )
    let service = RepositoryIncrementalIndexService(snapshotStore: receiptStore, queue: queue)

    #expect(throws: RepositoryIncrementalIndexError.ingestionFailed) {
        _ = try service.indexChangedFiles(root: fixture.root)
    }
    let snapshot = try RepositoryModule().intake(root: fixture.root)
    #expect(try receiptStore.snapshots(forCanonicalPath: snapshot.canonicalPath).isEmpty)
}

@Test("incremental repository indexing skips committed files above the local size bound")
func incrementalRepositoryIndexingSkipsCommittedFilesAboveTheLocalSizeBound() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let vaultRoot = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: vaultRoot) }
    try Data(repeating: 0x61, count: 1_000_001)
        .write(to: fixture.root.appending(path: "Sources/oversized.swift"))
    _ = try fixture.git("add", ".")
    _ = try fixture.git("commit", "-m", "add oversized source")
    let queue = try IngestQueue(
        databaseURL: vaultRoot.appending(path: "vault.sqlite"),
        contentStore: try ContentStore(rootDirectory: vaultRoot.appending(path: "content")),
        extractors: .localDefaults
    )
    let receiptStore = try RepositorySnapshotStore(
        databaseURL: vaultRoot.appending(path: "repository-receipts.sqlite")
    )

    let result = try RepositoryIncrementalIndexService(snapshotStore: receiptStore, queue: queue)
        .indexChangedFiles(root: fixture.root)

    #expect(result.snapshot.files.contains(where: { $0.path == "Sources/oversized.swift" }))
    #expect(result.capturedSourceIDs.count == 3)
    #expect(try queue.documents().count == 3)
}

private struct TemporaryRepository {
    let root: URL

    static func make() throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appending(path: "Sources"), withIntermediateDirectories: true)
        try "let evidence = true\n".data(using: .utf8)!.write(to: root.appending(path: "Sources/example.swift"))
        try "# Fixture\n".data(using: .utf8)!.write(to: root.appending(path: "README.md"))
        try "{\"enabled\":true}\n".data(using: .utf8)!.write(to: root.appending(path: "fixture.json"))
        try "MIT License\n".data(using: .utf8)!.write(to: root.appending(path: "LICENSE"))
        let fixture = Self(root: root)
        _ = try fixture.git("init", "-b", "main")
        _ = try fixture.git("config", "user.email", "test@example.invalid")
        _ = try fixture.git("config", "user.name", "Test")
        _ = try fixture.git("add", ".")
        _ = try fixture.git("commit", "-m", "fixture")
        return fixture
    }

    func git(_ arguments: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = root
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw TemporaryRepositoryError.gitFailure }
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}

private enum TemporaryRepositoryError: Error { case gitFailure }

private func repositoryJobRecord(
    from base: RepositoryJobRecord,
    status: RepositoryJobStatus,
    attempts: Int,
    snapshotCommit: String? = nil,
    capturedSourceCount: Int? = nil,
    errorCode: String? = nil
) -> RepositoryJobRecord {
    RepositoryJobRecord(
        id: base.id,
        sourceID: base.sourceID,
        canonicalPath: base.canonicalPath,
        status: status,
        attempts: attempts,
        maxAttempts: base.maxAttempts,
        snapshotCommit: snapshotCommit,
        capturedSourceCount: capturedSourceCount,
        errorCode: errorCode,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt
    )
}

private enum SyntheticRepositoryLifecycleError: Error {
    case writeFailed
}

private struct FailingRepositorySourceLifecycleWriter:
    RepositorySourceLifecycleWriting
{
    let records: [RepositorySourceLifecycleRecord]

    init(records: [RepositorySourceLifecycleRecord] = []) {
        self.records = records
    }

    func all() throws -> [RepositorySourceLifecycleRecord] {
        records
    }

    func record(
        _ source: RepositorySource,
        status: RepositorySourceLifecycleStatus,
        at updatedAt: Date
    ) throws -> RepositorySourceLifecycleRecord {
        throw SyntheticRepositoryLifecycleError.writeFailed
    }
}
