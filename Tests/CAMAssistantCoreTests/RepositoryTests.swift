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

@Test("repository receipts preserve physical blank lines used by citations")
func repositoryReceiptsPreservePhysicalCitationLines() throws {
    let fixture = try TemporaryRepository.make()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let readme = """
    # Fixture

    Supporting context.

    TODO: verify the cited physical line.
    """
    try Data(readme.utf8).write(
        to: fixture.root.appending(path: "README.md"),
        options: .atomic
    )
    _ = try fixture.git("add", "README.md")
    _ = try fixture.git("commit", "-m", "Add blank-line citation fixture")

    let snapshot = try RepositoryModule().intake(root: fixture.root)
    let readmeEvidence = try #require(
        snapshot.files.first { $0.path == "README.md" }
    )
    let observation = try #require(
        try RepositoryObservationExtractor()
            .extract(root: fixture.root, snapshot: snapshot)
            .first { $0.filePath == "README.md" && $0.symbol == "TODO" }
    )
    let card = try RepositoryIdeaCard(
        id: "physical-lines",
        title: "Verify physical line counting",
        evidence: [observation],
        counterevidence: ["The marker may be intentionally deferred."],
        confidence: 0.5,
        license: snapshot.license ?? "Unknown",
        validationExperiment: "Inspect the cited line."
    )

    #expect(readmeEvidence.lineCount == 5)
    #expect(observation.line == 5)
    #expect(try card.promote(snapshot: snapshot).ideaID == card.id)
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

@Test("repository semantic evaluation fixture is frozen and valid")
func repositorySemanticEvaluationFixtureIsFrozenAndValid() throws {
    let fixtureURL = repositorySemanticFixtureURL()
    let data = try Data(contentsOf: fixtureURL)
    let manifest = try RepositorySemanticEvaluationManifest.decode(data)

    try manifest.validate()

    #expect(manifest.manifestVersion == 2)
    #expect(manifest.cases.count == 4)
    #expect(
        manifest.cases.filter { $0.expectedOutcome == .observation }.count == 2
    )
    #expect(
        manifest.cases.filter { $0.expectedOutcome == .abstain }.count == 2
    )
    #expect(manifest.cases.flatMap(\.evidence).count == 13)
    #expect(
        manifest.cases.flatMap(\.evidence)
            .filter { $0.id.contains("distractor") }.count == 4
    )
    #expect(manifest.thresholds.evidencePrecision == 1)
    #expect(manifest.thresholds.counterevidenceRecall == 1)
    #expect(
        RepositorySemanticEvaluationManifest.sha256(of: data)
            == "5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25"
    )
}

@Test("repository semantic candidate requires exact support counterevidence and concepts")
func repositorySemanticCandidateRequiresExactEvidenceAndConcepts() throws {
    let manifest = try repositorySemanticManifest()
    let evaluationCase = try #require(
        manifest.cases.first { $0.id == "actor-cache-boundary" }
    )
    let candidate = RepositorySemanticCandidate(
        snapshotCommit: evaluationCase.snapshotCommit,
        statement: "Cache mutations are actor-isolated and have a concurrent access test, but values are not persisted across restart.",
        supportIDs: ["cache-actor", "cache-concurrency-test"],
        counterevidenceIDs: ["cache-no-persistence"],
        confidence: 0.82,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted",
        retention: .ephemeral
    )

    let validated = try #require(
        try RepositorySemanticCandidateValidator().validate(
            candidate,
            for: evaluationCase
        )
    )

    #expect(validated.caseID == evaluationCase.id)
    #expect(validated.snapshotCommit == evaluationCase.snapshotCommit)
    #expect(validated.license == evaluationCase.license)
    #expect(validated.support.map(\.id) == [
        "cache-actor",
        "cache-concurrency-test",
    ])
    #expect(validated.counterevidence.map(\.id) == [
        "cache-no-persistence",
    ])
    #expect(validated.retention == .ephemeral)
}

@Test("repository semantic candidate fails closed for unknown and role-swapped evidence")
func repositorySemanticCandidateFailsClosedForEvidenceMismatch() throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "actor-cache-boundary"
        }
    )
    let base = RepositorySemanticCandidate(
        snapshotCommit: evaluationCase.snapshotCommit,
        statement: "Cache mutations are actor-isolated and have a concurrent access test, but values are not persisted across restart.",
        supportIDs: ["cache-actor", "cache-concurrency-test"],
        counterevidenceIDs: ["cache-no-persistence"],
        confidence: 0.8,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted",
        retention: .ephemeral
    )

    #expect(throws: RepositorySemanticValidationError.unknownEvidence(
        "invented"
    )) {
        _ = try RepositorySemanticCandidateValidator().validate(
            RepositorySemanticCandidate(
                snapshotCommit: base.snapshotCommit,
                statement: base.statement,
                supportIDs: ["cache-actor", "invented"],
                counterevidenceIDs: base.counterevidenceIDs,
                confidence: base.confidence,
                runtimeIdentity: base.runtimeIdentity,
                modelID: base.modelID,
                retention: base.retention
            ),
            for: evaluationCase
        )
    }
    #expect(throws: RepositorySemanticValidationError.evidenceRoleMismatch(
        "cache-no-persistence"
    )) {
        _ = try RepositorySemanticCandidateValidator().validate(
            RepositorySemanticCandidate(
                snapshotCommit: base.snapshotCommit,
                statement: base.statement,
                supportIDs: [
                    "cache-actor",
                    "cache-concurrency-test",
                    "cache-no-persistence",
                ],
                counterevidenceIDs: [],
                confidence: base.confidence,
                runtimeIdentity: base.runtimeIdentity,
                modelID: base.modelID,
                retention: base.retention
            ),
            for: evaluationCase
        )
    }
}

@Test("repository semantic candidate rejects missing concepts and non-finite confidence")
func repositorySemanticCandidateRejectsUnsupportedProseAndConfidence() throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "idempotent-request-boundary"
        }
    )
    let unsupported = RepositorySemanticCandidate(
        snapshotCommit: evaluationCase.snapshotCommit,
        statement: "The request runner is robust.",
        supportIDs: evaluationCase.requiredSupportIDs,
        counterevidenceIDs: evaluationCase.requiredCounterevidenceIDs,
        confidence: 0.9,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted",
        retention: .ephemeral
    )

    #expect(throws: RepositorySemanticValidationError.missingRequiredConcept) {
        _ = try RepositorySemanticCandidateValidator().validate(
            unsupported,
            for: evaluationCase
        )
    }
    #expect(throws: RepositorySemanticValidationError.invalidConfidence) {
        _ = try RepositorySemanticCandidateValidator().validate(
            RepositorySemanticCandidate(
                snapshotCommit: evaluationCase.snapshotCommit,
                statement: "Requests use an idempotency key and duplicate requests return the same receipt, but crash recovery is not implemented.",
                supportIDs: evaluationCase.requiredSupportIDs,
                counterevidenceIDs: evaluationCase.requiredCounterevidenceIDs,
                confidence: .nan,
                runtimeIdentity: "scripted/semantic-v1",
                modelID: "scripted",
                retention: .ephemeral
            ),
            for: evaluationCase
        )
    }
}

@Test("repository semantic abstention must be explicit and citation free")
func repositorySemanticAbstentionMustBeExplicitAndCitationFree() throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "encryption-abstention"
        }
    )
    let validator = RepositorySemanticCandidateValidator()
    let abstention = RepositorySemanticCandidate.abstention(
        snapshotCommit: evaluationCase.snapshotCommit,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted"
    )

    #expect(try validator.validate(abstention, for: evaluationCase) == nil)
    #expect(throws: RepositorySemanticValidationError.malformedCandidate) {
        _ = try validator.validate(
            RepositorySemanticCandidate(
                snapshotCommit: evaluationCase.snapshotCommit,
                statement: "",
                supportIDs: ["snapshot-local-path"],
                counterevidenceIDs: [],
                confidence: 0,
                runtimeIdentity: "scripted/semantic-v1",
                modelID: "scripted",
                retention: .ephemeral
            ),
            for: evaluationCase
        )
    }
    #expect(throws: RepositorySemanticValidationError.expectedAbstention) {
        _ = try validator.validate(
            RepositorySemanticCandidate(
                snapshotCommit: evaluationCase.snapshotCommit,
                statement: "AES protects the snapshots.",
                supportIDs: ["snapshot-local-path"],
                counterevidenceIDs: [],
                confidence: 0.4,
                runtimeIdentity: "scripted/semantic-v1",
                modelID: "scripted",
                retention: .ephemeral
            ),
            for: evaluationCase
        )
    }
}

@Test("repository semantic evaluator measures evidence counterevidence and abstention")
func repositorySemanticEvaluatorMeasuresFrozenContract() async throws {
    let manifest = try repositorySemanticManifest()
    let generator = ScriptedRepositorySemanticGenerator(
        candidates: try validRepositorySemanticCandidates(manifest: manifest)
    )

    let report = try await RepositorySemanticEvaluator().evaluate(
        manifestURL: repositorySemanticFixtureURL(),
        generator: generator
    )

    #expect(report.evaluatorVersion == "repository-semantic-evaluator-v2")
    #expect(
        report.manifestHash
            == "5fe3b45ab5bbfdabd08eadf0871348a5830a5d4cd6c2213350be493293f64b25"
    )
    #expect(report.runtimeIdentity == "scripted/semantic-v1")
    #expect(report.modelID == "scripted")
    #expect(report.caseCount == 4)
    #expect(report.observationCaseCount == 2)
    #expect(report.abstentionCaseCount == 2)
    #expect(report.observationRecall == 1)
    #expect(report.evidencePrecision == 1)
    #expect(report.counterevidenceRecall == 1)
    #expect(report.abstentionAccuracy == 1)
    #expect(report.failedCaseIDs.isEmpty)
    #expect(report.unansweredCaseIDs.isEmpty)
    #expect(report.caseResults.allSatisfy { $0.passed })
    #expect(
        report.caseResults.map(\.caseID)
            == report.caseResults.map(\.caseID).sorted()
    )
    #expect(report.meetsFrozenThresholds)
    #expect(RepositorySemanticEvaluationExitCode.forReport(report) == 0)
}

@Test("repository semantic evaluator exposes invalid and unanswered cases")
func repositorySemanticEvaluatorExposesFailuresWithoutPersuasiveProse()
    async throws {
    let manifest = try repositorySemanticManifest()
    let cases = Dictionary(
        uniqueKeysWithValues: manifest.cases.map { ($0.id, $0) }
    )
    let actorCase = try #require(cases["actor-cache-boundary"])
    let idempotentCase = try #require(
        cases["idempotent-request-boundary"]
    )
    var candidates = try validRepositorySemanticCandidates(
        manifest: manifest
    )
    candidates[actorCase.id] = RepositorySemanticCandidate(
        snapshotCommit: actorCase.snapshotCommit,
        statement: "Cache mutations are actor-isolated and have a concurrent access test, but values are not persisted across restart.",
        supportIDs: ["cache-actor", "invented"],
        counterevidenceIDs: ["cache-no-persistence"],
        confidence: 0.8,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted",
        retention: .ephemeral
    )
    candidates[idempotentCase.id] = .abstention(
        snapshotCommit: idempotentCase.snapshotCommit,
        runtimeIdentity: "scripted/semantic-v1",
        modelID: "scripted"
    )

    let report = try await RepositorySemanticEvaluator().evaluate(
        manifestURL: repositorySemanticFixtureURL(),
        generator: ScriptedRepositorySemanticGenerator(
            candidates: candidates
        )
    )

    #expect(report.observationRecall == 0)
    #expect(report.failedCaseIDs == ["actor-cache-boundary"])
    #expect(report.unansweredCaseIDs == ["idempotent-request-boundary"])
    #expect(
        report.caseResults.first {
            $0.caseID == actorCase.id
        }?.errorCode == "unknown_evidence"
    )
    #expect(
        report.caseResults.first {
            $0.caseID == idempotentCase.id
        }?.abstained == true
    )
    #expect(!report.meetsFrozenThresholds)
    #expect(RepositorySemanticEvaluationExitCode.forReport(report) == 2)
}

@Test("repository semantic v2 metrics reject same-role distractor citations")
func repositorySemanticEvaluatorRejectsDistractorCitations() async throws {
    let manifest = try repositorySemanticManifest()
    var candidates = try validRepositorySemanticCandidates(
        manifest: manifest
    )
    let evaluationCase = try #require(
        manifest.cases.first { $0.id == "actor-cache-boundary" }
    )
    let base = try #require(candidates[evaluationCase.id])
    candidates[evaluationCase.id] = RepositorySemanticCandidate(
        snapshotCommit: base.snapshotCommit,
        statement: base.statement,
        supportIDs: base.supportIDs + ["cache-support-distractor"],
        counterevidenceIDs: base.counterevidenceIDs,
        confidence: base.confidence,
        runtimeIdentity: base.runtimeIdentity,
        modelID: base.modelID,
        retention: base.retention
    )

    let report = try await RepositorySemanticEvaluator().evaluate(
        manifestURL: repositorySemanticFixtureURL(),
        generator: ScriptedRepositorySemanticGenerator(
            candidates: candidates
        )
    )

    #expect(report.observationRecall == 1)
    #expect(report.evidencePrecision < 1)
    #expect(!report.meetsFrozenThresholds)
}

@Test("repository semantic evaluator propagates cancellation without a completed report")
func repositorySemanticEvaluatorPropagatesCancellation() async throws {
    let generator = CancellingRepositorySemanticGenerator()

    await #expect(throws: CancellationError.self) {
        _ = try await RepositorySemanticEvaluator().evaluate(
            manifestURL: repositorySemanticFixtureURL(),
            generator: generator
        )
    }
    #expect(await generator.requestCount() == 1)
}

@Test("repository semantic local generator requires health and sends bounded evidence")
func repositorySemanticLocalGeneratorRequiresHealthAndBoundedEvidence()
    async throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "actor-cache-boundary"
        }
    )
    let transport = RecordingRepositorySemanticTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/semantic"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: repositorySemanticChatEnvelope(
                model: "local/semantic",
                content: #"{"statement":"Cache mutations are actor-isolated and have a concurrent access test, but values are not persisted across restart.","support_ids":["cache-actor","cache-concurrency-test"],"counterevidence_ids":["cache-no-persistence"],"confidence":0.82}"#
            )
        ),
    ])
    let generator = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: transport
    )

    await #expect(
        throws: RepositorySemanticLocalGeneratorError.healthRequired
    ) {
        _ = try await generator.generate(for: evaluationCase)
    }
    #expect(await transport.recordedRequests().isEmpty)

    let health = try await generator.health()
    #expect(health.modelID == "local/semantic")
    #expect(health.isAvailable)
    let candidate = try await generator.generate(for: evaluationCase)
    let validated = try #require(
        try RepositorySemanticCandidateValidator().validate(
            candidate,
            for: evaluationCase
        )
    )
    #expect(validated.support.map(\.id) == evaluationCase.requiredSupportIDs)
    #expect(
        validated.counterevidence.map(\.id)
            == evaluationCase.requiredCounterevidenceIDs
    )
    #expect(candidate.retention == .ephemeral)

    let requests = await transport.recordedRequests()
    #expect(requests.count == 2)
    #expect(requests[0].method == .get)
    #expect(
        requests[0].url.absoluteString
            == "http://127.0.0.1:8080/v1/models"
    )
    #expect(requests[0].headers["Authorization"] == nil)
    #expect(requests[1].method == .post)
    #expect(
        requests[1].url.absoluteString
            == "http://127.0.0.1:8080/v1/chat/completions"
    )
    #expect(requests[1].headers == ["Content-Type": "application/json"])
    let body = try #require(requests[1].body)
    let bodyText = try #require(String(data: body, encoding: .utf8))
    #expect(bodyText.contains("cache-actor"))
    #expect(bodyText.contains("cache-no-persistence"))
    #expect(!bodyText.contains("Authorization"))
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["model"] as? String == "local/semantic")
    #expect(json["stream"] as? Bool == false)
    #expect(json["temperature"] as? Int == 0)
    let messages = try #require(json["messages"] as? [[String: Any]])
    let systemMessage = try #require(messages.first?["content"] as? String)
    let evidenceMarker = "Evidence JSON: "
    let evidenceMarkerRange = try #require(
        systemMessage.range(of: evidenceMarker)
    )
    let embeddedEvidence = Data(
        systemMessage[evidenceMarkerRange.upperBound...].utf8
    )
    let evidenceJSON = try #require(
        JSONSerialization.jsonObject(
            with: embeddedEvidence
        ) as? [[String: Any]]
    )
    #expect(evidenceJSON.first?["filePath"] as? String == "Sources/Cache.swift")
    let responseFormat = try #require(
        json["response_format"] as? [String: Any]
    )
    let jsonSchema = try #require(
        responseFormat["json_schema"] as? [String: Any]
    )
    #expect(jsonSchema["name"] as? String == "repository_semantic_candidate")
}

@Test("repository semantic local generator preserves explicit abstention")
func repositorySemanticLocalGeneratorPreservesExplicitAbstention()
    async throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "encryption-abstention"
        }
    )
    let transport = RecordingRepositorySemanticTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/semantic"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: repositorySemanticChatEnvelope(
                model: "local/semantic",
                content: #"{"statement":"","support_ids":[],"counterevidence_ids":[],"confidence":0}"#
            )
        ),
    ])
    let generator = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: transport
    )
    _ = try await generator.health()

    let candidate = try await generator.generate(for: evaluationCase)

    #expect(candidate.statement.isEmpty)
    #expect(candidate.supportIDs.isEmpty)
    #expect(candidate.counterevidenceIDs.isEmpty)
    #expect(
        try RepositorySemanticCandidateValidator().validate(
            candidate,
            for: evaluationCase
        ) == nil
    )

    let requests = await transport.recordedRequests()
    let body = try #require(requests.last?.body)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    let responseFormat = try #require(
        json["response_format"] as? [String: Any]
    )
    let jsonSchema = try #require(
        responseFormat["json_schema"] as? [String: Any]
    )
    let schema = try #require(
        jsonSchema["schema"] as? [String: Any]
    )
    let properties = try #require(
        schema["properties"] as? [String: Any]
    )
    let supportProperty = try #require(
        properties["support_ids"] as? [String: Any]
    )
    let supportItems = try #require(
        supportProperty["items"] as? [String: Any]
    )
    #expect(supportItems["type"] as? String == "string")
    #expect(
        supportItems["enum"] as? [String]
            == evaluationCase.evidence
                .filter { $0.role == .support }
                .map(\.id)
    )

    let counterevidenceProperty = try #require(
        properties["counterevidence_ids"] as? [String: Any]
    )
    let counterevidenceItems = try #require(
        counterevidenceProperty["items"] as? [String: Any]
    )
    #expect(counterevidenceItems["type"] as? String == "string")
    #expect(counterevidenceItems["enum"] == nil)
}

@Test("repository semantic local generator rejects assignment drift and unknown evidence")
func repositorySemanticLocalGeneratorFailsClosed() async throws {
    let remote = try ModelAssignment(
        provider: .openAI,
        modelID: "remote/model",
        localEndpoint: nil
    )
    #expect(
        throws: RepositorySemanticLocalGeneratorError.invalidAssignment
    ) {
        _ = try RepositorySemanticLocalGenerator(
            assignment: remote,
            transport: RecordingRepositorySemanticTransport(responses: [])
        )
    }

    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "actor-cache-boundary"
        }
    )
    let driftTransport = RecordingRepositorySemanticTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/semantic"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: repositorySemanticChatEnvelope(
                model: "other/model",
                content: #"{"statement":"","support_ids":[],"counterevidence_ids":[],"confidence":0}"#
            )
        ),
    ])
    let drifted = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: driftTransport
    )
    _ = try await drifted.health()
    await #expect(
        throws: RepositorySemanticLocalGeneratorError.modelIdentityMismatch(
            expected: "local/semantic",
            actual: "other/model"
        )
    ) {
        _ = try await drifted.generate(for: evaluationCase)
    }

    let unknownTransport = RecordingRepositorySemanticTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/semantic"}]}"#.utf8)
        ),
        LocalModelHTTPResponse(
            statusCode: 200,
            data: repositorySemanticChatEnvelope(
                model: "local/semantic",
                content: #"{"statement":"Invented.","support_ids":["invented"],"counterevidence_ids":[],"confidence":0.9}"#
            )
        ),
    ])
    let unknown = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: unknownTransport
    )
    _ = try await unknown.health()
    await #expect(
        throws: RepositorySemanticLocalGeneratorError.unknownEvidence(
            "invented"
        )
    ) {
        _ = try await unknown.generate(for: evaluationCase)
    }

    let unknownKeyTransport = RecordingRepositorySemanticTransport(
        responses: [
            LocalModelHTTPResponse(
                statusCode: 200,
                data: Data(
                    #"{"data":[{"id":"local/semantic"}]}"#.utf8
                )
            ),
            LocalModelHTTPResponse(
                statusCode: 200,
                data: repositorySemanticChatEnvelope(
                    model: "local/semantic",
                    content: #"{"statement":"","support_ids":[],"counterevidence_ids":[],"confidence":0,"unexpected":"reject"}"#
                )
            ),
        ]
    )
    let unknownKeyGenerator = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: unknownKeyTransport
    )
    _ = try await unknownKeyGenerator.health()
    await #expect(
        throws: RepositorySemanticLocalGeneratorError.invalidResponse
    ) {
        _ = try await unknownKeyGenerator.generate(for: evaluationCase)
    }
}

@Test("repository semantic local transport preserves cancellation")
func repositorySemanticLocalTransportPreservesCancellation() async throws {
    let generator = try RepositorySemanticLocalGenerator(
        assignment: repositorySemanticLocalAssignment(),
        transport: CancellingRepositorySemanticTransport()
    )

    await #expect(throws: CancellationError.self) {
        _ = try await generator.health()
    }
}

@Test("validated repository semantic candidate forms only an evidence-complete idea card")
func validatedRepositorySemanticCandidateFormsEvidenceCompleteIdeaCard()
    throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "actor-cache-boundary"
        }
    )
    let candidate = try #require(
        try validRepositorySemanticCandidates(
            manifest: repositorySemanticManifest()
        )[evaluationCase.id]
    )
    let validated = try #require(
        try RepositorySemanticCandidateValidator().validate(
            candidate,
            for: evaluationCase
        )
    )

    let card = try validated.ideaCard(
        id: "semantic-cache",
        title: "Evaluate actor-isolated cache",
        rejectedAlternatives: [
            "Keep the current unsynchronized dictionary.",
        ],
        validationExperiment:
            "Run the concurrent test under Thread Sanitizer and add a restart test."
    )

    #expect(card.evidence.map(\.filePath) == [
        "Sources/Cache.swift",
        "Tests/CacheTests.swift",
    ])
    #expect(card.counterevidence == [
        "Cache contents are memory-only and are not persisted across process restart.",
    ])
    #expect(card.counterevidenceCitations.map(\.filePath) == [
        "README.md",
    ])
    #expect(card.rejectedAlternatives == [
        "Keep the current unsynchronized dictionary.",
    ])
    #expect(card.confidence == 0.82)
    #expect(card.license == "MIT")
    #expect(card.rationale == candidate.statement)
    #expect(
        card.validationExperiment
            == "Run the concurrent test under Thread Sanitizer and add a restart test."
    )
    #expect(
        throws: RepositoryIdeaError.missingRejectedAlternatives
    ) {
        _ = try validated.ideaCard(
            id: "semantic-cache-incomplete",
            title: "Incomplete",
            rejectedAlternatives: [],
            validationExperiment: "Run one focused test."
        )
    }
}

@Test("semantic idea promotion revalidates counterevidence and license")
func semanticIdeaPromotionRevalidatesAllEvidenceAndLicense() throws {
    let evaluationCase = try #require(
        try repositorySemanticManifest().cases.first {
            $0.id == "actor-cache-boundary"
        }
    )
    let candidate = try #require(
        try validRepositorySemanticCandidates(
            manifest: repositorySemanticManifest()
        )[evaluationCase.id]
    )
    let validated = try #require(
        try RepositorySemanticCandidateValidator().validate(
            candidate,
            for: evaluationCase
        )
    )
    let card = try validated.ideaCard(
        id: "semantic-promotion",
        title: "Evaluate cache",
        rejectedAlternatives: ["Keep the current dictionary."],
        validationExperiment: "Run concurrency and restart tests."
    )
    let snapshot = RepositorySnapshot(
        canonicalPath: "/tmp/semantic",
        remote: nil,
        branch: "main",
        commit: evaluationCase.snapshotCommit,
        isDirty: false,
        license: evaluationCase.license,
        files: evaluationCase.evidence.map {
            RepositoryFileEvidence(
                path: $0.filePath,
                lineCount: $0.line
            )
        }
    )

    #expect(try card.promote(snapshot: snapshot).ideaID == card.id)

    let staleCounter = try RepositoryIdeaCard(
        id: "stale-counter",
        title: card.title,
        rationale: card.rationale,
        evidence: card.evidence,
        counterevidence: card.counterevidence,
        counterevidenceCitations: card.counterevidenceCitations.map {
            RepositoryObservation(
                snapshotCommit: String(repeating: "f", count: 40),
                filePath: $0.filePath,
                line: $0.line,
                symbol: $0.symbol,
                statement: $0.statement
            )
        },
        rejectedAlternatives: card.rejectedAlternatives,
        confidence: card.confidence,
        license: card.license,
        validationExperiment: card.validationExperiment
    )
    #expect(throws: RepositoryIdeaError.staleEvidence) {
        _ = try staleCounter.promote(snapshot: snapshot)
    }

    let wrongLicense = try RepositoryIdeaCard(
        id: "wrong-license",
        title: card.title,
        rationale: card.rationale,
        evidence: card.evidence,
        counterevidence: card.counterevidence,
        counterevidenceCitations: card.counterevidenceCitations,
        rejectedAlternatives: card.rejectedAlternatives,
        confidence: card.confidence,
        license: "GPL",
        validationExperiment: card.validationExperiment
    )
    #expect(throws: RepositoryIdeaError.licenseMismatch) {
        _ = try wrongLicense.promote(snapshot: snapshot)
    }
}

@Test("legacy repository idea cards decode through current validation")
func legacyRepositoryIdeaCardsDecodeThroughCurrentValidation() throws {
    let legacy = Data(
        """
        {
          "id": "legacy-card",
          "title": "Legacy card",
          "evidence": [{
            "snapshotCommit": "1111111111111111111111111111111111111111",
            "filePath": "Sources/Legacy.swift",
            "line": 4,
            "symbol": "Legacy",
            "statement": "Legacy evidence."
          }],
          "counterevidence": ["Legacy limitation."],
          "confidence": 0.5,
          "license": "MIT",
          "validationExperiment": "Run the legacy test."
        }
        """.utf8
    )

    let card = try JSONDecoder().decode(
        RepositoryIdeaCard.self,
        from: legacy
    )
    #expect(card.rationale == nil)
    #expect(card.counterevidenceCitations.isEmpty)
    #expect(card.rejectedAlternatives.isEmpty)
    #expect(
        try JSONDecoder().decode(
            RepositoryIdeaCard.self,
            from: JSONEncoder().encode(card)
        ) == card
    )
}

@Test("repository semantic evaluation request accepts only explicit loopback model")
func repositorySemanticEvaluationRequestRequiresExplicitLoopback() throws {
    let request = try RepositorySemanticEvaluationRequest.parse(
        arguments: [
            "evaluate-repository-semantic",
            "manifest.json",
            "report.json",
            "local/semantic",
            "http://127.0.0.1:8080/v1",
        ]
    )

    #expect(request.manifestURL.path.hasSuffix("/manifest.json"))
    #expect(request.outputURL.path.hasSuffix("/report.json"))
    #expect(request.assignment.provider == .local)
    #expect(request.assignment.modelID == "local/semantic")
    #expect(
        throws: RepositorySemanticEvaluationRequestError
            .invalidArguments
    ) {
        _ = try RepositorySemanticEvaluationRequest.parse(
            arguments: ["evaluate-repository-semantic"]
        )
    }
    #expect(throws: ModelProfileError.invalidLocalEndpoint) {
        _ = try RepositorySemanticEvaluationRequest.parse(
            arguments: [
                "evaluate-repository-semantic",
                "manifest.json",
                "report.json",
                "remote/model",
                "https://example.com/v1",
            ]
        )
    }
}

private struct ScriptedRepositorySemanticGenerator:
    RepositorySemanticCandidateGenerator {
    let runtimeIdentity = "scripted/semantic-v1"
    let modelID = "scripted"
    let candidates: [String: RepositorySemanticCandidate]

    func generate(
        for evaluationCase: RepositorySemanticEvaluationCase
    ) async throws -> RepositorySemanticCandidate {
        guard let candidate = candidates[evaluationCase.id] else {
            throw RepositorySemanticGeneratorError.missingCandidate(
                evaluationCase.id
            )
        }
        return candidate
    }
}

private actor CancellingRepositorySemanticGenerator:
    RepositorySemanticCandidateGenerator {
    nonisolated let runtimeIdentity = "scripted/cancelling"
    nonisolated let modelID = "scripted"
    private var requests = 0

    func generate(
        for evaluationCase: RepositorySemanticEvaluationCase
    ) async throws -> RepositorySemanticCandidate {
        requests += 1
        throw CancellationError()
    }

    func requestCount() -> Int {
        requests
    }
}

private actor RecordingRepositorySemanticTransport: LocalModelTransport {
    private var responses: [LocalModelHTTPResponse]
    private var requests: [LocalModelHTTPRequest] = []

    init(responses: [LocalModelHTTPResponse]) {
        self.responses = responses
    }

    func send(
        _ request: LocalModelHTTPRequest
    ) async throws -> LocalModelHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw LocalModelInferenceError.transportUnavailable
        }
        return responses.removeFirst()
    }

    func recordedRequests() -> [LocalModelHTTPRequest] {
        requests
    }
}

private struct CancellingRepositorySemanticTransport:
    LocalModelTransport {
    func send(
        _ request: LocalModelHTTPRequest
    ) async throws -> LocalModelHTTPResponse {
        throw CancellationError()
    }
}

private func repositorySemanticChatEnvelope(
    model: String,
    content: String
) -> Data {
    try! JSONSerialization.data(
        withJSONObject: [
            "model": model,
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": content,
                    ],
                ],
            ],
        ]
    )
}

private func repositorySemanticLocalAssignment() throws -> ModelAssignment {
    try ModelAssignment(
        provider: .local,
        modelID: "local/semantic",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )
}

private func validRepositorySemanticCandidates(
    manifest: RepositorySemanticEvaluationManifest
) throws -> [String: RepositorySemanticCandidate] {
    let cases = Dictionary(
        uniqueKeysWithValues: manifest.cases.map { ($0.id, $0) }
    )
    let actor = try #require(cases["actor-cache-boundary"])
    let idempotent = try #require(
        cases["idempotent-request-boundary"]
    )
    let encryption = try #require(cases["encryption-abstention"])
    let performance = try #require(cases["performance-abstention"])
    return [
        actor.id: RepositorySemanticCandidate(
            snapshotCommit: actor.snapshotCommit,
            statement: "Cache mutations are actor-isolated and have a concurrent access test, but values are not persisted across restart.",
            supportIDs: actor.requiredSupportIDs,
            counterevidenceIDs: actor.requiredCounterevidenceIDs,
            confidence: 0.82,
            runtimeIdentity: "scripted/semantic-v1",
            modelID: "scripted",
            retention: .ephemeral
        ),
        idempotent.id: RepositorySemanticCandidate(
            snapshotCommit: idempotent.snapshotCommit,
            statement: "The idempotency key makes a duplicate request return the same receipt, but crash recovery is not implemented.",
            supportIDs: idempotent.requiredSupportIDs,
            counterevidenceIDs: idempotent.requiredCounterevidenceIDs,
            confidence: 0.78,
            runtimeIdentity: "scripted/semantic-v1",
            modelID: "scripted",
            retention: .ephemeral
        ),
        encryption.id: .abstention(
            snapshotCommit: encryption.snapshotCommit,
            runtimeIdentity: "scripted/semantic-v1",
            modelID: "scripted"
        ),
        performance.id: .abstention(
            snapshotCommit: performance.snapshotCommit,
            runtimeIdentity: "scripted/semantic-v1",
            modelID: "scripted"
        ),
    ]
}

private func repositorySemanticManifest() throws
    -> RepositorySemanticEvaluationManifest {
    let data = try Data(contentsOf: repositorySemanticFixtureURL())
    let manifest = try RepositorySemanticEvaluationManifest.decode(data)
    try manifest.validate()
    return manifest
}

private func repositorySemanticFixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(
            path: "Fixtures/Repositories/semantic-v2/manifest.json"
        )
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
