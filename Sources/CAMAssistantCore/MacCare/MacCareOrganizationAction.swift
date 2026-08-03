import Foundation

/// Immutable, status-safe intent for one user-selected organization move. It
/// never stores an absolute path or file bytes; the caller supplies the root
/// again when a later exact-approved executor validates and performs it.
public struct MacCareOrganizationPlan: Codable, Equatable, Sendable {
    public let id: UUID
    public let actionID: String
    public let sourceRelativePath: String
    public let destinationRelativePath: String
    public let sourceByteCount: Int64
    public let sourceSHA256: String
    public let stateRevision: Int

    fileprivate init(
        id: UUID = UUID(),
        sourceRelativePath: String,
        destinationRelativePath: String,
        sourceByteCount: Int64,
        sourceSHA256: String
    ) {
        self.id = id
        actionID = "mac-care.move-one-selected-file.v1"
        self.sourceRelativePath = sourceRelativePath
        self.destinationRelativePath = destinationRelativePath
        self.sourceByteCount = sourceByteCount
        self.sourceSHA256 = sourceSHA256
        stateRevision = 1
    }

    public func actionCard(expiresAt: Date) throws -> ActionCard {
        let payload = "\(actionID)|\(id.uuidString)|\(sourceSHA256)|\(destinationRelativePath)"
        let data = Data(payload.utf8)
        return try ActionCard(
            goal: "Move one explicitly selected file inside an approved organization root.",
            moduleID: "mac-care.organization",
            target: "Mac Care organization action \(id.uuidString)",
            accessedResources: [sourceRelativePath, destinationRelativePath],
            excludedResources: ["vault", "CAM", "repositories", "credentials"],
            riskReason: "Describes one selected local move for the user to perform manually. CAM Assistant will not move the file.",
            outboundManifest: OutboundManifest(operation: actionID, requestedRole: nil, stateVersion: stateRevision, riskClass: .generic, redactedPayload: payload, payloadSHA256: GoldenRetrievalManifest.sha256(of: data), outboundByteCount: data.count),
            expiresAt: expiresAt,
            rollbackDescription: "If you moved the file yourself, move it back with an inverse mv or Finder drag. The app has no undo executor."
        )
    }
}

public enum MacCareOrganizationActionStatus: String, Codable, Equatable, Sendable { case verified }
public struct MacCareOrganizationActionResult: Equatable, Sendable { public let status: MacCareOrganizationActionStatus; public let approvalID: UUID }

/// App-owned organization mutation is gated closed until a complete reversible
/// design (verified undo, durable receipts, postconditions) is approved.
/// Callers must use ``MacCareOrganizationManualGuide`` so the user moves files.
public enum MacCareOrganizationExecutorError: Error, Equatable, Sendable {
    case appOwnedMutationUnavailable
}

public struct MacCareOrganizationExecutor: Sendable {
    public init() {}

    /// Always refuses. Does not consume approvals, open paths, or move files.
    public func execute(
        plan: MacCareOrganizationPlan,
        rootURL: URL,
        approvalID: UUID,
        approvalStore: ApprovalStore,
        card: ActionCard,
        now: Date = Date()
    ) throws -> MacCareOrganizationActionResult {
        _ = plan
        _ = rootURL
        _ = approvalID
        _ = approvalStore
        _ = card
        _ = now
        throw MacCareOrganizationExecutorError.appOwnedMutationUnavailable
    }
}

/// Copyable manual steps for a planned organization move. The user runs these
/// outside the app; the assistant never executes them.
public struct MacCareOrganizationManualGuide: Equatable, Sendable {
    public let notice: String
    public let shellCommand: String
    public let finderSteps: [String]
    public let inverseShellCommand: String

    public static let userResponsibilityNotice =
        "CAM Assistant will not move, rename, or delete this file. Copy the command and run it yourself if you choose."

    public static func make(
        plan: MacCareOrganizationPlan,
        rootURL: URL
    ) -> MacCareOrganizationManualGuide {
        let root = rootURL.standardizedFileURL
        let source = root.appending(path: plan.sourceRelativePath).path
        let destination = root.appending(path: plan.destinationRelativePath).path
        return MacCareOrganizationManualGuide(
            notice: userResponsibilityNotice,
            shellCommand: "mv \(shellQuote(source)) \(shellQuote(destination))",
            finderSteps: [
                "Open the organization root in Finder.",
                "Locate \(plan.sourceRelativePath).",
                "Move or drag it to \(plan.destinationRelativePath) only if you intend the change.",
                "Confirm the destination path is vacant before replacing anything.",
            ],
            inverseShellCommand: "mv \(shellQuote(destination)) \(shellQuote(source))"
        )
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum MacCareOrganizationPlanError: Error, Equatable {
    case invalidRoot
    case pathOutsideRoot
    case invalidSource
    case invalidDestinationDirectory
    case invalidReplacementName
    case destinationExists
    case sourceReadFailed
}

/// Builds a plan from explicit caller selections. It makes no recommendation,
/// creates no directories, and does not move or rename a file.
public struct MacCareOrganizationPlanner: Sendable {
    public init() {}

    public func propose(
        rootURL: URL,
        sourceURL: URL,
        destinationDirectoryURL: URL,
        replacementName: String? = nil
    ) throws -> MacCareOrganizationPlan {
        let root = rootURL.standardizedFileURL
        guard root.isFileURL,
              isDirectory(root),
              !isSymbolicLink(root) else {
            throw MacCareOrganizationPlanError.invalidRoot
        }
        let source = sourceURL.standardizedFileURL
        let destinationDirectory = destinationDirectoryURL.standardizedFileURL
        guard isDescendant(source, of: root),
              isDescendant(destinationDirectory, of: root) else {
            throw MacCareOrganizationPlanError.pathOutsideRoot
        }
        guard isRegularFile(source), !isSymbolicLink(source) else {
            throw MacCareOrganizationPlanError.invalidSource
        }
        guard isDirectory(destinationDirectory),
              !isSymbolicLink(destinationDirectory) else {
            throw MacCareOrganizationPlanError.invalidDestinationDirectory
        }
        let name = try destinationName(
            replacementName,
            fallback: source.lastPathComponent
        )
        let destination = destinationDirectory.appending(path: name)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw MacCareOrganizationPlanError.destinationExists
        }
        let data: Data
        do {
            data = try Data(contentsOf: source)
        } catch {
            throw MacCareOrganizationPlanError.sourceReadFailed
        }
        return MacCareOrganizationPlan(
            sourceRelativePath: relativePath(source, root: root),
            destinationRelativePath: relativePath(destination, root: root),
            sourceByteCount: Int64(data.count),
            sourceSHA256: GoldenRetrievalManifest.sha256(of: data)
        )
    }

    private func destinationName(
        _ replacementName: String?,
        fallback: String
    ) throws -> String {
        let name = (replacementName ?? fallback)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\\"),
              URL(filePath: name).lastPathComponent == name else {
            throw MacCareOrganizationPlanError.invalidReplacementName
        }
        return name
    }

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(prefix)
    }

    private func relativePath(_ value: URL, root: URL) -> String {
        String(value.path.dropFirst(root.path.count + 1))
    }

    private func isDirectory(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory)
            == true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile)
            == true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?
            .isSymbolicLink) == true
    }
}
