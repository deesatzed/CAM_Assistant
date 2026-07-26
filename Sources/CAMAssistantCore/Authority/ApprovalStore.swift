import Foundation

public enum ApprovalStatus: String, Codable, Equatable, Sendable {
    case approved
    case consumed
}

public struct ExactApproval: Codable, Equatable, Sendable {
    public let id: UUID
    public let cardID: UUID
    public let operation: String
    public let target: String
    public let payloadSHA256: String
    public let stateVersion: Int
    public let expiresAt: Date
    public let source: String
    public var status: ApprovalStatus
}

public struct ApprovalReceipt: Codable, Equatable, Sendable {
    public let approvalID: UUID
    public let consumedAt: Date
}

public enum ApprovalStoreError: Error, Equatable {
    case approvalNotFound(UUID)
    case alreadyConsumed(UUID)
    case expired(UUID)
    case mismatchedBinding(UUID)
    case emptySource
}

public final class ApprovalStore {
    private let stateURL: URL
    private let lock = NSRecursiveLock()
    private var state: ApprovalState

    public init(stateURL: URL) throws {
        self.stateURL = stateURL
        state = try ApprovalState.load(from: stateURL)
    }

    public func approve(
        _ card: ActionCard,
        source: String,
        now: Date = Date()
    ) throws -> ExactApproval {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ApprovalStoreError.emptySource
        }
        lock.lock()
        defer { lock.unlock() }
        let approval = ExactApproval(
            id: UUID(),
            cardID: card.id,
            operation: card.outboundManifest.operation,
            target: card.target,
            payloadSHA256: card.outboundManifest.payloadSHA256,
            stateVersion: card.outboundManifest.stateVersion,
            expiresAt: card.expiresAt,
            source: source,
            status: .approved
        )
        var candidate = state
        candidate.approvals.append(approval)
        try candidate.save(to: stateURL)
        state = candidate
        return approval
    }

    public func consume(
        approvalID: UUID,
        for card: ActionCard,
        now: Date = Date()
    ) throws -> ApprovalReceipt {
        lock.lock()
        defer { lock.unlock() }
        guard let index = state.approvals.firstIndex(where: { $0.id == approvalID }) else {
            throw ApprovalStoreError.approvalNotFound(approvalID)
        }
        let approval = state.approvals[index]
        guard approval.status != .consumed else {
            throw ApprovalStoreError.alreadyConsumed(approvalID)
        }
        guard now < approval.expiresAt else {
            throw ApprovalStoreError.expired(approvalID)
        }
        guard approval.cardID == card.id,
              approval.operation == card.outboundManifest.operation,
              approval.target == card.target,
              approval.payloadSHA256 == card.outboundManifest.payloadSHA256,
              approval.stateVersion == card.outboundManifest.stateVersion,
              approval.expiresAt == card.expiresAt else {
            throw ApprovalStoreError.mismatchedBinding(approvalID)
        }
        var candidate = state
        candidate.approvals[index].status = .consumed
        try candidate.save(to: stateURL)
        state = candidate
        return ApprovalReceipt(approvalID: approvalID, consumedAt: now)
    }

    public func approvals() throws -> [ExactApproval] {
        lock.lock()
        defer { lock.unlock() }
        return state.approvals
    }
}

private struct ApprovalState: Codable, Equatable {
    var schemaVersion: Int = 1
    var approvals: [ExactApproval] = []

    static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
