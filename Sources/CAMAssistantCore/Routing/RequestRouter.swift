import Foundation

public enum ModelRouteRole: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case local
    case claude
    case grok
    case openAI
}

public enum DeferredPrivacyRequest: Codable, Equatable, Sendable {
    case automaticRouting
    case webResearch(provider: ModelRouteRole?)
}

public enum RouteDecision: Codable, Equatable, Sendable {
    case local
    case namedProvider(ModelRouteRole)
    case deferredPrivacyPolicy(DeferredPrivacyRequest)
    case deferredCAM
}

public enum RequestRoutingError: Error, Equatable {
    case roleUnavailable(ModelRouteRole)
}

public struct RequestRouter {
    public init() {}

    public func route(
        _ request: ParsedRequest,
        availability: Set<ModelRouteRole>
    ) throws -> RouteDecision {
        if request.markers.contains(.cam) {
            return .deferredCAM
        }

        let selectedProvider = providerRole(for: request.markers)
        if let selectedProvider, !availability.contains(selectedProvider) {
            throw RequestRoutingError.roleUnavailable(selectedProvider)
        }

        if request.markers.contains(.autoRoute) {
            return .deferredPrivacyPolicy(.automaticRouting)
        }
        if request.markers.contains(.web) {
            return .deferredPrivacyPolicy(.webResearch(provider: selectedProvider))
        }
        if let selectedProvider {
            return .namedProvider(selectedProvider)
        }
        guard availability.contains(.local) else {
            throw RequestRoutingError.roleUnavailable(.local)
        }
        return .local
    }

    public func outboundPolicyDecision(
        for request: ParsedRequest,
        stateVersion: Int,
        policy: OutboundPolicy = OutboundPolicy()
    ) -> OutboundPolicyDecision {
        let selectedRole = providerRole(for: request.markers)
        let explicitWeb = request.markers.contains(.web)
        let automaticRoute = request.markers.contains(.autoRoute)
        let needsPrivacyPolicy = explicitWeb || selectedRole != nil || automaticRoute
        return policy.evaluate(
            OutboundRequest(
                operation: explicitWeb ? "web-research" : "model-request",
                requestedRole: needsPrivacyPolicy ? selectedRole : .local,
                fragments: [request.text],
                stateVersion: stateVersion,
                explicitlyRequestedWeb: explicitWeb
            )
        )
    }

    private func providerRole(for markers: [RoutingMarker]) -> ModelRouteRole? {
        if markers.contains(.claude) { return .claude }
        if markers.contains(.grok) { return .grok }
        if markers.contains(.openAI) { return .openAI }
        return nil
    }
}
