import Foundation

public enum AuditOperation: String, Codable, Sendable {
    case capture
    case retrieval
    case modelRequest
    case research
    case actionProposal
    case actionExecution
    case system
}

public enum AuditStatus: String, Codable, Sendable {
    case proposed
    case started
    case succeeded
    case failed
    case denied
    case cancelled
}

public enum AuditPrivacyDecision: String, Codable, Equatable, Sendable {
    case localOnly
    case proposal
    case blocked
}

public struct AuditEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let operation: AuditOperation
    public let status: AuditStatus
    public let resourceID: String?
    public let route: String?
    public let privacyRisk: RiskClass?
    public let privacyDecision: AuditPrivacyDecision?
    public let payloadSHA256: String?
    public let outboundByteCount: Int?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: AuditOperation,
        status: AuditStatus,
        resourceID: String?,
        route: String?,
        privacyRisk: RiskClass? = nil,
        privacyDecision: AuditPrivacyDecision? = nil,
        payloadSHA256: String? = nil,
        outboundByteCount: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.status = status
        self.resourceID = SecretRedactor.statusValue(resourceID)
        self.route = SecretRedactor.statusValue(route)
        self.privacyRisk = privacyRisk
        self.privacyDecision = privacyDecision
        self.payloadSHA256 = SecretRedactor.statusValue(payloadSHA256)
        self.outboundByteCount = outboundByteCount
    }
}

enum SecretRedactor {
    static func statusValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let lowercased = value.lowercased()
        let forbiddenMarkers = [
            "sk-",
            "ghp_",
            "github_pat_",
            "xoxb-",
            "xoxp-",
            "api_key",
            "apikey",
            "-----begin ",
        ]
        return forbiddenMarkers.contains(where: lowercased.contains)
            ? "[REDACTED]"
            : value
    }
}
