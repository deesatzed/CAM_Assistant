import Foundation
import Testing
@testable import CAMAssistantCore

@Test("Mac Care assessment is read-only and produces a digest-bound plan")
func macCareAssessmentIsReadOnlyAndProducesDigestBoundPlan() throws {
    let observation = MacCareObservation(
        availableBytes: 100,
        totalBytes: 1_000,
        applicationPaths: ["/Applications/Example.app"],
        startupItemPaths: ["/Library/LaunchAgents/example.plist"]
    )
    let assessment = try MacWiseAdapter().assess(observation: observation)
    let plan = try MacCarePlanner().propose(
        assessment: assessment,
        action: .reviewStorage,
        expectedAssessmentDigest: assessment.digest
    )

    #expect(assessment.availableBytes == 100)
    #expect(assessment.applicationCount == 1)
    #expect(plan.approvalClass == .exact)
    #expect(plan.assessmentDigest == assessment.digest)
    #expect(
        throws: MacCarePlannerError.staleAssessment
    ) {
        _ = try MacCarePlanner().propose(assessment: assessment, action: .reviewStorage, expectedAssessmentDigest: "stale")
    }
}

@Test("Mac Care has no apply or undo executor")
func macCareHasNoApplyOrUndoExecutor() throws {
    let assessment = try MacWiseAdapter().assess(
        observation: MacCareObservation(availableBytes: 1, totalBytes: 2, applicationPaths: [], startupItemPaths: [])
    )
    let plan = try MacCarePlanner().propose(assessment: assessment, action: .reviewStartupItems, expectedAssessmentDigest: assessment.digest)

    #expect(throws: MacCarePlannerError.executionUnavailable) {
        try MacCarePlanner().apply(plan)
    }
    #expect(throws: MacCarePlannerError.executionUnavailable) {
        try MacCarePlanner().undo(plan)
    }
}

@Test("Mac Care read-only probe reports selected directory counts")
func macCareReadOnlyProbeReportsSelectedDirectoryCounts() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let apps = root.appending(path: "Applications")
    let startup = root.appending(path: "LaunchAgents")
    try FileManager.default.createDirectory(at: apps, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: startup, withIntermediateDirectories: true)
    try Data().write(to: apps.appending(path: "Example.app"))
    try Data().write(to: startup.appending(path: "example.plist"))
    defer { try? FileManager.default.removeItem(at: root) }

    let assessment = try MacWiseAdapter().inspectReadOnly(
        volumeURL: root,
        applicationDirectory: apps,
        startupDirectories: [startup]
    )

    #expect(assessment.applicationCount == 1)
    #expect(assessment.startupItemCount == 1)
}

@Test("Mac Care presentation reports only read-only assessment facts")
func macCarePresentationReportsOnlyReadOnlyAssessmentFacts() throws {
    let assessment = try MacWiseAdapter().assess(observation: MacCareObservation(availableBytes: 100, totalBytes: 1_000, applicationPaths: ["/Applications/A.app"], startupItemPaths: []))
    let presentation = MacCarePresentation(assessment: assessment)
    #expect(presentation.storageLabel == "100 bytes free of 1000 bytes")
    #expect(presentation.applicationLabel == "1 application")
    #expect(presentation.mutationStatus.contains("Apply and undo are unavailable"))
    #expect(presentation.mutationStatus.contains("does not move files"))
}

@Test("Mac Care presentation offers bounded read-only storage and inventory review findings")
func macCarePresentationOffersReadOnlyReviewFindings() throws {
    let assessment = try MacWiseAdapter().assess(
        observation: MacCareObservation(
            availableBytes: 50,
            totalBytes: 1_000,
            applicationPaths: ["/Applications/A.app", "/Applications/B.app"],
            startupItemPaths: ["/Library/LaunchAgents/example.plist"]
        )
    )

    let presentation = MacCarePresentation(assessment: assessment)

    #expect(presentation.storageStatusLabel == "Low free space: 5.0%")
    #expect(presentation.reviewFindings == [
        "Review storage before proposing any cleanup.",
        "Review 1 startup item; no change has been applied.",
        "Review the 2-application inventory; usage and removal recommendations are unavailable.",
    ])
}

@Test("Mac Care organization plan binds one regular fixture file inside one root")
func macCareOrganizationPlanBindsOneRegularFixtureFileInsideOneRoot() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceDirectory = root.appending(path: "Inbox", directoryHint: .isDirectory)
    let destinationDirectory = root.appending(path: "Archive", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    let source = sourceDirectory.appending(path: "notes.txt")
    try Data("local notes".utf8).write(to: source)

    let plan = try MacCareOrganizationPlanner().propose(
        rootURL: root,
        sourceURL: source,
        destinationDirectoryURL: destinationDirectory,
        replacementName: "reviewed-notes.txt"
    )

    #expect(plan.actionID == "mac-care.move-one-selected-file.v1")
    #expect(plan.sourceRelativePath == "Inbox/notes.txt")
    #expect(plan.destinationRelativePath == "Archive/reviewed-notes.txt")
    #expect(plan.sourceByteCount == 11)
    #expect(plan.sourceSHA256.count == 64)
    #expect(plan.stateRevision == 1)

    try Data("existing".utf8).write(
        to: destinationDirectory.appending(path: "conflict.txt")
    )
    #expect(throws: MacCareOrganizationPlanError.destinationExists) {
        _ = try MacCareOrganizationPlanner().propose(
            rootURL: root,
            sourceURL: source,
            destinationDirectoryURL: destinationDirectory,
            replacementName: "conflict.txt"
        )
    }
    #expect(throws: MacCareOrganizationPlanError.invalidReplacementName) {
        _ = try MacCareOrganizationPlanner().propose(
            rootURL: root,
            sourceURL: source,
            destinationDirectoryURL: destinationDirectory,
            replacementName: "../escape.txt"
        )
    }
}

@Test("Mac Care organization executor refuses app-owned mutation and leaves files untouched")
func macCareOrganizationExecutorRefusesAppOwnedMutationAndLeavesFilesUntouched() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let inbox = root.appending(path: "Inbox", directoryHint: .isDirectory)
    let archive = root.appending(path: "Archive", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
    let source = inbox.appending(path: "notes.txt")
    try Data("local notes".utf8).write(to: source)
    let plan = try MacCareOrganizationPlanner().propose(
        rootURL: root, sourceURL: source, destinationDirectoryURL: archive
    )
    let card = try plan.actionCard(expiresAt: Date(timeIntervalSince1970: 100))
    let approvals = try ApprovalStore(stateURL: root.appending(path: "approvals.json"))
    let approval = try approvals.approve(card, source: "user", now: Date(timeIntervalSince1970: 10))

    #expect(throws: MacCareOrganizationExecutorError.appOwnedMutationUnavailable) {
        _ = try MacCareOrganizationExecutor().execute(
            plan: plan, rootURL: root, approvalID: approval.id,
            approvalStore: approvals, card: card, now: Date(timeIntervalSince1970: 20)
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: archive.appending(path: "notes.txt").path))
    #expect(try approvals.approvals().count == 1)
}

@Test("Mac Care organization manual guide emits user-run shell and Finder steps")
func macCareOrganizationManualGuideEmitsUserRunShellAndFinderSteps() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let inbox = root.appending(path: "Inbox", directoryHint: .isDirectory)
    let archive = root.appending(path: "Archive", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
    let source = inbox.appending(path: "notes.txt")
    try Data("local notes".utf8).write(to: source)
    let plan = try MacCareOrganizationPlanner().propose(
        rootURL: root, sourceURL: source, destinationDirectoryURL: archive
    )

    let guide = MacCareOrganizationManualGuide.make(plan: plan, rootURL: root)

    #expect(guide.notice == MacCareOrganizationManualGuide.userResponsibilityNotice)
    #expect(guide.shellCommand.contains("mv "))
    #expect(guide.shellCommand.contains("Inbox/notes.txt"))
    #expect(guide.shellCommand.contains("Archive/notes.txt"))
    #expect(guide.inverseShellCommand.contains("mv "))
    #expect(guide.finderSteps.count == 4)
    #expect(FileManager.default.fileExists(atPath: source.path))
}
