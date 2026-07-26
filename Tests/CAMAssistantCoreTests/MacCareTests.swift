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
    #expect(presentation.mutationStatus == "Apply and undo are unavailable")
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
