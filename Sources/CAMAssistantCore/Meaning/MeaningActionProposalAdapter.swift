import Foundation

public enum MeaningActionProposalKind: String, Codable, Sendable, Equatable {
    case external
    case mutating
}

public enum MeaningActionProposalAuthority: String, Codable, Sendable, Equatable {
    case proposalOnly
}

public struct MeaningActionProposal: Sendable, Equatable {
    public let id: String
    public let kind: MeaningActionProposalKind
    public let authority: MeaningActionProposalAuthority
    public let privacyDecision: AuditPrivacyDecision
    public let riskClass: RiskClass
    public let outboundByteCount: Int
    public let outboundManifest: OutboundManifest?

    public init(
        id: String,
        kind: MeaningActionProposalKind,
        authority: MeaningActionProposalAuthority = .proposalOnly,
        privacyDecision: AuditPrivacyDecision,
        riskClass: RiskClass,
        outboundByteCount: Int,
        outboundManifest: OutboundManifest?
    ) {
        self.id = id
        self.kind = kind
        self.authority = authority
        self.privacyDecision = privacyDecision
        self.riskClass = riskClass
        self.outboundByteCount = outboundByteCount
        self.outboundManifest = outboundManifest
    }
}

/// Converts a possibility into inert proposal data. It owns no transport,
/// executor, approval store, or mutation capability.
public struct MeaningActionProposalAdapter: Sendable {
    private let policy: OutboundPolicy

    public init(policy: OutboundPolicy = .init()) {
        self.policy = policy
    }

    public func propose(
        id: String,
        kind: MeaningActionProposalKind,
        description: String,
        requestedRole: ModelRouteRole? = .local,
        stateVersion: Int
    ) -> MeaningActionProposal {
        let decision = policy.evaluate(
            OutboundRequest(
                operation: "meaning-preview-\(kind.rawValue)-proposal",
                requestedRole: requestedRole,
                fragments: [description],
                stateVersion: stateVersion,
                explicitlyRequestedWeb: kind == .external
            )
        )

        switch decision {
        case let .localOnly(riskClass):
            return MeaningActionProposal(
                id: id,
                kind: kind,
                privacyDecision: .localOnly,
                riskClass: riskClass,
                outboundByteCount: 0,
                outboundManifest: nil
            )
        case let .proposal(manifest):
            return MeaningActionProposal(
                id: id,
                kind: kind,
                privacyDecision: .proposal,
                riskClass: manifest.riskClass,
                outboundByteCount: manifest.outboundByteCount,
                outboundManifest: manifest
            )
        case let .blocked(block):
            return MeaningActionProposal(
                id: id,
                kind: kind,
                privacyDecision: .blocked,
                riskClass: block.riskClass,
                outboundByteCount: block.outboundByteCount,
                outboundManifest: nil
            )
        }
    }
}
