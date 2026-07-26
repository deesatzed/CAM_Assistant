import CryptoKit
import Foundation

public struct OutboundRequest: Equatable, Sendable {
    public let operation: String
    public let requestedRole: ModelRouteRole?
    public let fragments: [String]
    public let stateVersion: Int
    public let explicitlyRequestedWeb: Bool

    public init(
        operation: String,
        requestedRole: ModelRouteRole?,
        fragments: [String],
        stateVersion: Int,
        explicitlyRequestedWeb: Bool
    ) {
        self.operation = operation
        self.requestedRole = requestedRole
        self.fragments = fragments
        self.stateVersion = stateVersion
        self.explicitlyRequestedWeb = explicitlyRequestedWeb
    }
}

public struct OutboundManifest: Equatable, Sendable {
    public let operation: String
    public let requestedRole: ModelRouteRole?
    public let stateVersion: Int
    public let riskClass: RiskClass
    public let redactedPayload: String
    public let payloadSHA256: String
    public let outboundByteCount: Int
}

public struct OutboundBlock: Equatable, Sendable {
    public let riskClass: RiskClass
    public let reasons: [PrivacySignal]
    public let outboundByteCount: Int

    public init(
        riskClass: RiskClass,
        reasons: [PrivacySignal],
        outboundByteCount: Int
    ) {
        self.riskClass = riskClass
        self.reasons = reasons
        self.outboundByteCount = outboundByteCount
    }
}

public enum OutboundPolicyDecision: Equatable, Sendable {
    case localOnly(riskClass: RiskClass)
    case proposal(OutboundManifest)
    case blocked(OutboundBlock)
}

public struct OutboundPolicy: Sendable {
    private let classifier: DataClassifier

    public init(classifier: DataClassifier = DataClassifier()) {
        self.classifier = classifier
    }

    public func evaluate(_ request: OutboundRequest) -> OutboundPolicyDecision {
        let classification = classifier.classify(request.fragments)
        let requiresOutbound = request.explicitlyRequestedWeb || request.requestedRole != .local
        guard requiresOutbound else {
            return .localOnly(riskClass: classification.riskClass)
        }
        guard classification.riskClass == .public || classification.riskClass == .generic else {
            return .blocked(
                OutboundBlock(
                    riskClass: classification.riskClass,
                    reasons: classification.signals,
                    outboundByteCount: 0
                )
            )
        }

        let payload = classification.sanitizedText
        let bytes = Data(payload.utf8)
        return .proposal(
            OutboundManifest(
                operation: request.operation,
                requestedRole: request.requestedRole,
                stateVersion: request.stateVersion,
                riskClass: classification.riskClass,
                redactedPayload: payload,
                payloadSHA256: SHA256.hash(data: bytes).hexString,
                outboundByteCount: bytes.count
            )
        )
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
