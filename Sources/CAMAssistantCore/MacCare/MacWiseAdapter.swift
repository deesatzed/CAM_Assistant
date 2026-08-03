import Foundation

public struct MacCareObservation: Codable, Equatable, Sendable {
    public let availableBytes: Int64
    public let totalBytes: Int64
    public let applicationPaths: [String]
    public let startupItemPaths: [String]

    public init(availableBytes: Int64, totalBytes: Int64, applicationPaths: [String], startupItemPaths: [String]) {
        self.availableBytes = availableBytes
        self.totalBytes = totalBytes
        self.applicationPaths = applicationPaths.sorted()
        self.startupItemPaths = startupItemPaths.sorted()
    }
}

public struct MacCareAssessment: Codable, Equatable, Sendable {
    public let availableBytes: Int64
    public let totalBytes: Int64
    public let applicationCount: Int
    public let startupItemCount: Int
    public let digest: String
}

public struct MacCarePresentation: Equatable, Sendable {
    public let storageLabel: String
    public let storageStatusLabel: String
    public let applicationLabel: String
    public let startupLabel: String
    public let reviewFindings: [String]
    public let mutationStatus: String

    public init(assessment: MacCareAssessment) {
        storageLabel = "\(assessment.availableBytes) bytes free of \(assessment.totalBytes) bytes"
        let freePercent = Double(assessment.availableBytes) / Double(assessment.totalBytes) * 100
        storageStatusLabel = freePercent < 10
            ? "Low free space: \(String(format: "%.1f", freePercent))%"
            : "Free space: \(String(format: "%.1f", freePercent))%"
        applicationLabel = "\(assessment.applicationCount) \(assessment.applicationCount == 1 ? "application" : "applications")"
        startupLabel = "\(assessment.startupItemCount) \(assessment.startupItemCount == 1 ? "startup item" : "startup items")"
        var findings: [String] = []
        if freePercent < 10 {
            findings.append("Review storage before proposing any cleanup.")
        }
        if assessment.startupItemCount > 0 {
            findings.append("Review \(assessment.startupItemCount) \(assessment.startupItemCount == 1 ? "startup item" : "startup items"); no change has been applied.")
        }
        if assessment.applicationCount > 0 {
            findings.append("Review the \(assessment.applicationCount)-application inventory; usage and removal recommendations are unavailable.")
        }
        reviewFindings = findings
        mutationStatus =
            "Apply and undo are unavailable. CAM Assistant does not move files; use copyable manual steps if you reorganize yourself."
    }
}

public struct MacCareReadOnlyOperation: Sendable {
    public static func inspectStandardLocations(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> MacCareAssessment {
        try MacWiseAdapter().inspectReadOnly(
            volumeURL: URL(filePath: "/"),
            applicationDirectory: URL(filePath: "/Applications"),
            startupDirectories: [URL(filePath: "/Library/LaunchAgents"), homeDirectory.appending(path: "Library/LaunchAgents")]
        )
    }
}

/// Converts read-only observation facts to a stable assessment. It does not
/// invoke removal, installation, login-item, service, or preference APIs.
public struct MacWiseAdapter: Sendable {
    public init() {}

    /// Reads only filesystem capacity and directory entries from caller-selected
    /// locations. The caller controls all roots; this does not enumerate or
    /// mutate the whole machine.
    public func inspectReadOnly(
        volumeURL: URL,
        applicationDirectory: URL,
        startupDirectories: [URL]
    ) throws -> MacCareAssessment {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: volumeURL.path)
        guard let available = attributes[.systemFreeSize] as? NSNumber,
              let total = attributes[.systemSize] as? NSNumber else {
            throw MacCareAssessmentError.invalidStorage
        }
        let applications = try directoryEntries(at: applicationDirectory)
        let startupItems = try startupDirectories.flatMap { try directoryEntries(at: $0) }
        return try assess(observation: MacCareObservation(
            availableBytes: available.int64Value,
            totalBytes: total.int64Value,
            applicationPaths: applications,
            startupItemPaths: startupItems
        ))
    }

    public func assess(observation: MacCareObservation) throws -> MacCareAssessment {
        guard observation.availableBytes >= 0,
              observation.totalBytes > 0,
              observation.totalBytes >= observation.availableBytes else {
            throw MacCareAssessmentError.invalidStorage
        }
        let canonical = "\(observation.availableBytes)|\(observation.totalBytes)|\(observation.applicationPaths.joined(separator: "\n"))|\(observation.startupItemPaths.joined(separator: "\n"))"
        return MacCareAssessment(
            availableBytes: observation.availableBytes,
            totalBytes: observation.totalBytes,
            applicationCount: observation.applicationPaths.count,
            startupItemCount: observation.startupItemPaths.count,
            digest: GoldenRetrievalManifest.sha256(of: Data(canonical.utf8))
        )
    }

    private func directoryEntries(at directory: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).map(\.path).sorted()
    }
}

public enum MacCareAssessmentError: Error, Equatable {
    case invalidStorage
}

public enum MacCareAction: String, Codable, Equatable, Sendable {
    case reviewStorage
    case reviewStartupItems
}

public struct MacCarePlan: Codable, Equatable, Sendable {
    public let action: MacCareAction
    public let assessmentDigest: String
    public let approvalClass: ApprovalClass
}

/// Proposal boundary for future exact-approved maintenance executors.
public struct MacCarePlanner: Sendable {
    public init() {}

    public func propose(assessment: MacCareAssessment, action: MacCareAction, expectedAssessmentDigest: String) throws -> MacCarePlan {
        guard assessment.digest == expectedAssessmentDigest else { throw MacCarePlannerError.staleAssessment }
        return MacCarePlan(action: action, assessmentDigest: assessment.digest, approvalClass: .exact)
    }

    public func apply(_ plan: MacCarePlan) throws { throw MacCarePlannerError.executionUnavailable }
    public func undo(_ plan: MacCarePlan) throws { throw MacCarePlannerError.executionUnavailable }
}

public enum MacCarePlannerError: Error, Equatable {
    case staleAssessment
    case executionUnavailable
}
