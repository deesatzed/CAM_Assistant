import Foundation

public enum MeaningPreviewAuditReason: String, Codable, Sendable, Equatable {
    case surfaced
    case now
    case later
    case released
    case helpful
    case notHelpful = "not-helpful"
    case rejected
    case corrected
    case expired
    case restrictedContext = "restricted-context"
    case proposalOnly = "proposal-only"
    case proposalBlocked = "proposal-blocked"
}

public struct MeaningPreviewAuditReceipt: Sendable, Equatable {
    public let timestamp: Date
    public let decisionID: String
    public let version: UInt64
    public let status: AuditStatus
    public let reason: MeaningPreviewAuditReason
    public let exclusions: [MeaningContextExclusion]
    public let riskClass: RiskClass?
    public let privacyDecision: AuditPrivacyDecision
    public let outboundByteCount: Int

    public init(
        timestamp: Date,
        decisionID: String,
        version: UInt64,
        status: AuditStatus,
        reason: MeaningPreviewAuditReason,
        exclusions: [MeaningContextExclusion] = [],
        riskClass: RiskClass? = nil,
        privacyDecision: AuditPrivacyDecision = .localOnly,
        outboundByteCount: Int = 0
    ) {
        self.timestamp = timestamp
        self.decisionID = decisionID
        self.version = version
        self.status = status
        self.reason = reason
        self.exclusions = exclusions
        self.riskClass = riskClass
        self.privacyDecision = privacyDecision
        self.outboundByteCount = max(0, outboundByteCount)
    }
}

public protocol MeaningPreviewAuditRecording: Sendable {
    /// Audit delivery is deliberately nonthrowing after a state commit. A
    /// false result marks audit health degraded without misreporting the
    /// already-committed user operation as failed.
    @discardableResult
    func record(_ receipt: MeaningPreviewAuditReceipt) -> Bool
}

/// Persists only typed status facts through CAM's existing audit store. The
/// receipt type has no field for context text, source bytes, or model output.
/// The coordinator is the sole owner of an injected sink and serializes calls.
public final class MeaningPreviewAuditSink: MeaningPreviewAuditRecording, @unchecked Sendable {
    private let store: AuditStore
    private let lock = NSLock()

    public init(store: AuditStore) {
        self.store = store
    }

    @discardableResult
    public func record(_ receipt: MeaningPreviewAuditReceipt) -> Bool {
        lock.withLock {
            do {
                let decisionID = Self.boundedIdentifier(receipt.decisionID)
                let exclusions = receipt.exclusions
                    .map(Self.boundedExclusionName)
                    .sorted()
                    .joined(separator: ",")
                let route = exclusions.isEmpty
                    ? receipt.reason.rawValue
                    : "\(receipt.reason.rawValue)|\(exclusions)"
                try store.append(
                    AuditEvent(
                        timestamp: receipt.timestamp,
                        operation: .system,
                        status: receipt.status,
                        resourceID: "meaning-preview:\(decisionID):v\(receipt.version)",
                        route: route,
                        privacyRisk: receipt.riskClass,
                        privacyDecision: receipt.privacyDecision,
                        outboundByteCount: receipt.outboundByteCount
                    )
                )
                return true
            } catch {
                return false
            }
        }
    }

    private static func boundedIdentifier(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !value.isEmpty,
              value.utf8.count <= 64,
              value.unicodeScalars.allSatisfy(allowed.contains) else {
            return "invalid"
        }
        return value
    }

    private static func boundedExclusionName(_ exclusion: MeaningContextExclusion) -> String {
        switch exclusion {
        case .hidden: "hidden"
        case .inactive: "inactive"
        case .restricted: "restricted"
        case .secretLike: "secret-like"
        case .stale: "stale"
        case .unsupported: "unsupported"
        case .missing: "missing"
        case .notPermitted: "not-permitted"
        case .invalidCommitment: "invalid-commitment"
        case .identifierCollision: "identifier-collision"
        }
    }
}
