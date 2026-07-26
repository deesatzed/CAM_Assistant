import Foundation

public enum ModelCommandResult: Equatable, Sendable {
    case active(ModelProfile?)
    case profiles([ModelProfile])
    case profile(ModelProfile)
    case changed(ModelProfileChangeReceipt)
    case localCatalogNotConfigured
}

public enum ModelCommandExecutionError: Error, Equatable {
    case noActiveProfile
    case localEndpointRequired
    case outboundPolicyRequired(operation: String)
    case proofGateRequired(operation: String)
    case missingChangeReceipt
}

public final class ModelCommandExecutor {
    private let registry: ModelRegistry

    public init(registry: ModelRegistry) {
        self.registry = registry
    }

    public func execute(_ command: ModelCommand) throws -> ModelCommandResult {
        switch command {
        case .current:
            return .active(try registry.activeProfile())
        case .profileList:
            return .profiles(try registry.profiles())
        case let .profileShow(id):
            return .profile(try registry.profile(id))
        case let .profileCreate(id, localModelID, localEndpoint, cloudModels):
            var assignments: [ModelRouteRole: ModelAssignment] = [
                .local: try ModelAssignment(
                    provider: .local,
                    modelID: localModelID,
                    localEndpoint: localEndpoint
                )
            ]
            for (role, modelID) in cloudModels {
                assignments[role] = try ModelAssignment(
                    provider: provider(for: role),
                    modelID: modelID,
                    localEndpoint: nil
                )
            }
            try registry.create(try ModelProfile(id: id, revision: 1, assignments: assignments))
            return try latestReceipt()
        case let .profileUse(id):
            try registry.use(id)
            return try latestReceipt()
        case let .set(role, modelID):
            guard let active = try registry.activeProfile() else {
                throw ModelCommandExecutionError.noActiveProfile
            }
            var assignments = active.assignments
            let endpoint = assignments[role]?.localEndpoint
            if role == .local, endpoint == nil {
                throw ModelCommandExecutionError.localEndpointRequired
            }
            assignments[role] = try ModelAssignment(
                provider: provider(for: role),
                modelID: modelID,
                localEndpoint: endpoint
            )
            _ = try registry.replace(
                profileID: active.id,
                expectedRevision: active.revision,
                assignments: assignments
            )
            return try latestReceipt()
        case let .catalog(live):
            if live {
                throw ModelCommandExecutionError.outboundPolicyRequired(operation: "catalog --live")
            }
            return .localCatalogNotConfigured
        case let .providerTest(role):
            throw ModelCommandExecutionError.proofGateRequired(
                operation: "models test \(role.rawValue)"
            )
        case let .migrate(apply):
            throw ModelCommandExecutionError.proofGateRequired(
                operation: apply ? "models migrate --apply" : "models migrate --dry-run"
            )
        case let .embeddingsEvaluate(models, suite):
            throw ModelCommandExecutionError.proofGateRequired(
                operation: "embeddings evaluate \(models) \(suite)"
            )
        case let .embeddingsPromote(runID):
            throw ModelCommandExecutionError.proofGateRequired(
                operation: "embeddings promote \(runID)"
            )
        }
    }

    private func latestReceipt() throws -> ModelCommandResult {
        guard let receipt = try registry.changeReceipts().last else {
            throw ModelCommandExecutionError.missingChangeReceipt
        }
        return .changed(receipt)
    }

    private func provider(for role: ModelRouteRole) -> ModelProvider {
        switch role {
        case .local: .local
        case .claude: .claude
        case .grok: .grok
        case .openAI: .openAI
        }
    }
}
