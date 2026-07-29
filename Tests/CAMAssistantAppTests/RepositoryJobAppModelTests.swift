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

@MainActor
@Test("app model presents accepted and abstained repository semantics as ephemeral")
func appModelPresentsEphemeralRepositorySemanticOutcomes()
    async throws {
    let root = try makeSemanticAppRepository()
    defer { try? FileManager.default.removeItem(at: root) }

    let acceptedModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, snapshot in
                acceptedRuntimeAnalysis(snapshot: snapshot)
            }
        )
    )
    acceptedModel.repositoryPath = root.path
    acceptedModel.inspectSelectedRepository()
    acceptedModel.analyzeSelectedRepositorySemantics()
    await waitForRepositorySemanticAnalysis(acceptedModel)

    let accepted = try #require(
        acceptedModel.repositorySemanticAnalysis?
            .validatedCandidate
    )
    #expect(acceptedModel.repositorySemanticAnalysis?.retention == .ephemeral)
    #expect(accepted.statement.contains("restart recovery"))
    #expect(accepted.support.count == 1)
    #expect(accepted.counterevidence.count == 1)
    #expect(
        acceptedModel.repositorySemanticStatus
            == "Ephemeral local-model candidate ready for review. Nothing was retained or promoted."
    )
    #expect(acceptedModel.repositoryError == nil)

    acceptedModel.repositoryIdeaTitle =
        "Evaluate restart-safe runtime feature"
    acceptedModel.repositorySemanticRejectedAlternative =
        "Keep the current implementation without recovery coverage."
    acceptedModel.repositoryIdeaValidationExperiment =
        "Add and run one restart recovery test."
    acceptedModel.createRepositorySemanticIdeaProposal()

    #expect(
        acceptedModel.repositoryIdeaProposal?.sourceCommit
            == accepted.snapshotCommit
    )
    #expect(
        acceptedModel.repositoryIdeaProposal?.kind
            == .researchPacket
    )
    #expect(acceptedModel.repositoryError == nil)

    let abstainingModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, snapshot in
                RepositorySemanticV3RuntimeAnalysis(
                    snapshotCommit: snapshot.commit,
                    runtimeIdentity: "loopback:test",
                    modelID: "local/test",
                    retention: .ephemeral,
                    validatedCandidate: nil
                )
            }
        )
    )
    abstainingModel.repositoryPath = root.path
    abstainingModel.inspectSelectedRepository()
    abstainingModel.analyzeSelectedRepositorySemantics()
    await waitForRepositorySemanticAnalysis(abstainingModel)

    #expect(
        abstainingModel.repositorySemanticAnalysis?.didAbstain == true
    )
    #expect(
        abstainingModel.repositorySemanticStatus
            == "The selected local model abstained. No repository idea was created or retained."
    )
    #expect(abstainingModel.repositoryError == nil)
}

@MainActor
@Test("app model safely distinguishes stale unavailable and cancelled semantic analysis")
func appModelSafelyReportsRepositorySemanticFailures() async throws {
    let root = try makeSemanticAppRepository()
    defer { try? FileManager.default.removeItem(at: root) }

    let staleModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, _ in
                throw RepositorySemanticV3RuntimeBundleError.snapshotDrift
            }
        )
    )
    staleModel.repositoryPath = root.path
    staleModel.inspectSelectedRepository()
    staleModel.analyzeSelectedRepositorySemantics()
    await waitForRepositorySemanticAnalysis(staleModel)
    #expect(staleModel.repositorySemanticAnalysis == nil)
    #expect(
        staleModel.repositoryError
            == "The repository changed after inspection. Reinspect a clean commit before analyzing it."
    )

    let unavailableModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, _ in
                throw RepositorySemanticV3LocalGeneratorError
                    .selectedModelUnavailable("private-model-name")
            }
        )
    )
    unavailableModel.repositoryPath = root.path
    unavailableModel.inspectSelectedRepository()
    unavailableModel.analyzeSelectedRepositorySemantics()
    await waitForRepositorySemanticAnalysis(unavailableModel)
    #expect(
        unavailableModel.repositoryError
            == "The selected local model could not analyze this bounded evidence. No fallback, CAM call, or retention occurred."
    )
    #expect(
        unavailableModel.repositoryError?
            .contains("private-model-name") == false
    )

    let insufficientModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, _ in
                throw RepositorySemanticV3RuntimeBundleError
                    .insufficientEvidence
            }
        )
    )
    insufficientModel.repositoryPath = root.path
    insufficientModel.inspectSelectedRepository()
    insufficientModel.analyzeSelectedRepositorySemantics()
    await waitForRepositorySemanticAnalysis(insufficientModel)
    #expect(
        insufficientModel.repositoryError
            == "This commit does not contain both bounded support and counterevidence for local-model analysis. No model request occurred."
    )

    let cancellingModel = AppModel(
        repositorySourceService: nil,
        repositoryJobStore: nil,
        initializeFullWorkspace: false,
        repositorySemanticOperations: RepositorySemanticOperations(
            analyze: { _, _ in
                try await Task.sleep(for: .seconds(30))
                throw CancellationError()
            }
        )
    )
    cancellingModel.repositoryPath = root.path
    cancellingModel.inspectSelectedRepository()
    cancellingModel.analyzeSelectedRepositorySemantics()
    #expect(cancellingModel.isRepositorySemanticAnalyzing)
    cancellingModel.cancelRepositorySemanticAnalysis()
    await waitForRepositorySemanticAnalysis(cancellingModel)
    #expect(cancellingModel.repositorySemanticAnalysis == nil)
    #expect(cancellingModel.repositoryError == nil)
    #expect(
        cancellingModel.repositorySemanticStatus
            == "Local repository evidence analysis was cancelled. No result was retained."
    )
}

private func acceptedRuntimeAnalysis(
    snapshot: RepositorySnapshot
) -> RepositorySemanticV3RuntimeAnalysis {
    let support = RepositorySemanticEvidence(
        id: "support",
        snapshotCommit: snapshot.commit,
        filePath: "Sources/RuntimeFeature.swift",
        line: 1,
        symbol: "RuntimeFeature",
        role: .support,
        excerpt: "struct RuntimeFeature {"
    )
    let counterevidence = RepositorySemanticEvidence(
        id: "counter",
        snapshotCommit: snapshot.commit,
        filePath: "Sources/RuntimeFeature.swift",
        line: 2,
        symbol: "TODO",
        role: .counterevidence,
        excerpt: "// TODO: add restart recovery."
    )
    return RepositorySemanticV3RuntimeAnalysis(
        snapshotCommit: snapshot.commit,
        runtimeIdentity: "loopback:test",
        modelID: "local/test",
        retention: .ephemeral,
        validatedCandidate:
            RepositorySemanticV3ValidatedCandidate(
                caseID: "runtime-test",
                snapshotCommit: snapshot.commit,
                license: snapshot.license ?? "Unknown",
                statement:
                    "The type is declared, but restart recovery remains open.",
                claims: [
                    RepositorySemanticClaim(
                        id: "declared-architecture-boundary",
                        description: "A declared boundary."
                    ),
                    RepositorySemanticClaim(
                        id: "explicit-implementation-gap",
                        description: "An explicit gap."
                    ),
                ],
                support: [support],
                counterevidence: [counterevidence],
                confidence: 0.8,
                runtimeIdentity: "loopback:test",
                modelID: "local/test",
                retention: .ephemeral
            )
    )
}

private func makeSemanticAppRepository() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root.appending(path: "Sources"),
        withIntermediateDirectories: true
    )
    try Data(
        """
        struct RuntimeFeature {
            // TODO: add restart recovery.
        }
        """.utf8
    ).write(
        to: root.appending(path: "Sources/RuntimeFeature.swift")
    )
    try runSemanticAppGit(["init", "-q"], root: root)
    try runSemanticAppGit(
        ["config", "user.email", "cam@example.invalid"],
        root: root
    )
    try runSemanticAppGit(
        ["config", "user.name", "CAM Test"],
        root: root
    )
    try runSemanticAppGit(["add", "."], root: root)
    try runSemanticAppGit(
        ["commit", "-q", "-m", "semantic fixture"],
        root: root
    )
    return root
}

private func runSemanticAppGit(
    _ arguments: [String],
    root: URL
) throws {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = root
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.fileReadUnknown)
    }
}

@MainActor
private func waitForRepositorySemanticAnalysis(
    _ model: AppModel
) async {
    for _ in 0..<200 where model.isRepositorySemanticAnalyzing {
        await Task.yield()
    }
}
