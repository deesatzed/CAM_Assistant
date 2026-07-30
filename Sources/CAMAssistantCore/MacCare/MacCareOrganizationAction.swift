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
            riskReason: "Moves one selected local file and requires verified undo.",
            outboundManifest: OutboundManifest(operation: actionID, requestedRole: nil, stateVersion: stateRevision, riskClass: .generic, redactedPayload: payload, payloadSHA256: GoldenRetrievalManifest.sha256(of: data), outboundByteCount: data.count),
            expiresAt: expiresAt,
            rollbackDescription: "Move the verified destination file back to its original vacant path."
        )
    }
}

public enum MacCareOrganizationActionStatus: String, Codable, Equatable, Sendable { case verified }
public struct MacCareOrganizationActionResult: Equatable, Sendable { public let status: MacCareOrganizationActionStatus; public let approvalID: UUID }
public struct MacCareOrganizationExecutor: Sendable {
    public init() {}
    public func execute(plan: MacCareOrganizationPlan, rootURL: URL, approvalID: UUID, approvalStore: ApprovalStore, card: ActionCard, now: Date = Date()) throws -> MacCareOrganizationActionResult {
        let receipt = try approvalStore.consume(approvalID: approvalID, for: card, now: now)
        let root = rootURL.standardizedFileURL
        let source = root.appending(path: plan.sourceRelativePath)
        let destination = root.appending(path: plan.destinationRelativePath)
        let data = try Data(contentsOf: source)
        guard Int64(data.count) == plan.sourceByteCount, GoldenRetrievalManifest.sha256(of: data) == plan.sourceSHA256, !FileManager.default.fileExists(atPath: destination.path) else { throw MacCareOrganizationPlanError.sourceReadFailed }
        try FileManager.default.moveItem(at: source, to: destination)
        let moved = try Data(contentsOf: destination)
        guard GoldenRetrievalManifest.sha256(of: moved) == plan.sourceSHA256 else { throw MacCareOrganizationPlanError.sourceReadFailed }
        return MacCareOrganizationActionResult(status: .verified, approvalID: receipt.approvalID)
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
