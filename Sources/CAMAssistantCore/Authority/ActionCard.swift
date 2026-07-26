import Foundation

public struct ActionCard: Equatable, Sendable {
    public let id: UUID
    public let goal: String
    public let moduleID: String
    public let target: String
    public let accessedResources: [String]
    public let excludedResources: [String]
    public let riskReason: String
    public let outboundManifest: OutboundManifest
    public let approvalClass: ApprovalClass
    public let expiresAt: Date
    public let rollbackDescription: String

    public init(
        id: UUID = UUID(),
        goal: String,
        moduleID: String,
        target: String,
        accessedResources: [String],
        excludedResources: [String],
        riskReason: String,
        outboundManifest: OutboundManifest,
        expiresAt: Date,
        rollbackDescription: String
    ) throws {
        guard [goal, moduleID, target, riskReason, rollbackDescription].allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }), !accessedResources.isEmpty, !excludedResources.isEmpty else {
            throw ActionCardError.missingRequiredDetail
        }
        self.id = id
        self.goal = goal
        self.moduleID = moduleID
        self.target = target
        self.accessedResources = accessedResources
        self.excludedResources = excludedResources
        self.riskReason = riskReason
        self.outboundManifest = outboundManifest
        self.approvalClass = .exact
        self.expiresAt = expiresAt
        self.rollbackDescription = rollbackDescription
    }
}

public enum ActionCardError: Error, Equatable {
    case missingRequiredDetail
}
