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

public struct AuditEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let operation: AuditOperation
    public let status: AuditStatus
    public let resourceID: String?
    public let route: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: AuditOperation,
        status: AuditStatus,
        resourceID: String?,
        route: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.status = status
        self.resourceID = SecretRedactor.statusValue(resourceID)
        self.route = SecretRedactor.statusValue(route)
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
