import Foundation

public enum ModelCommand: Equatable, Sendable {
    case current
    case profileList
    case profileShow(String)
    case profileCreate(
        id: String,
        localModelID: String,
        localEndpoint: String,
        cloudModels: [ModelRouteRole: String]
    )
    case profileUse(String)
    case set(role: ModelRouteRole, modelID: String)
    case catalog(live: Bool)
    case providerTest(ModelRouteRole)
    case migrate(apply: Bool)
    case embeddingsEvaluate(models: String, suite: String)
    case embeddingsPromote(runID: String)

    public static func parse(_ arguments: [String]) throws -> Self {
        if arguments.first == "embeddings" {
            return try parseEmbeddings(arguments)
        }
        guard arguments.first == "models" else {
            throw ModelCommandError.unsupportedCommand(arguments)
        }
        let values = Array(arguments.dropFirst())
        if values == ["current"] {
            return .current
        }
        if values == ["profile", "list"] {
            return .profileList
        }
        if values.count == 3, values[0] == "profile", values[1] == "show" {
            return .profileShow(values[2])
        }
        if values.count == 3, values[0] == "profile", values[1] == "use" {
            return .profileUse(values[2])
        }
        if values.count == 3, values[0] == "set" {
            let roleText = values[1]
            guard let role = ModelRouteRole(rawValue: roleText) else {
                throw ModelCommandError.invalidRole(roleText)
            }
            return .set(role: role, modelID: values[2])
        }
        if values == ["catalog"] {
            return .catalog(live: false)
        }
        if values == ["catalog", "--live"] {
            return .catalog(live: true)
        }
        if values.count == 2, values[0] == "test" {
            guard let role = ModelRouteRole(rawValue: values[1]) else {
                throw ModelCommandError.invalidRole(values[1])
            }
            return .providerTest(role)
        }
        if values == ["migrate", "--dry-run"] {
            return .migrate(apply: false)
        }
        if values == ["migrate", "--apply"] {
            return .migrate(apply: true)
        }
        if values.starts(with: ["profile", "create"]) {
            return try parseCreate(values)
        }
        throw ModelCommandError.unsupportedCommand(arguments)
    }

    private static func parseEmbeddings(_ arguments: [String]) throws -> Self {
        let values = Array(arguments.dropFirst())
        if values.count == 5,
           values[0] == "evaluate",
           values[1] == "--models",
           values[3] == "--suite" {
            return .embeddingsEvaluate(models: values[2], suite: values[4])
        }
        if values.count == 2, values[0] == "promote" {
            return .embeddingsPromote(runID: values[1])
        }
        throw ModelCommandError.unsupportedCommand(arguments)
    }

    private static func parseCreate(_ values: [String]) throws -> Self {
        guard values.count >= 3 else {
            throw ModelCommandError.missingRequiredOption("PROFILE_ID")
        }
        let id = values[2]
        var localModelID: String?
        var localEndpoint: String?
        var cloudModels: [ModelRouteRole: String] = [:]
        var index = 3

        while index < values.count {
            let option = values[index]
            guard index + 1 < values.count else {
                throw ModelCommandError.missingValue(option)
            }
            let value = values[index + 1]
            switch option {
            case "--local":
                guard localModelID == nil else { throw ModelCommandError.duplicateOption(option) }
                localModelID = value
            case "--local-endpoint":
                guard localEndpoint == nil else { throw ModelCommandError.duplicateOption(option) }
                localEndpoint = value
            case "--claude", "--grok", "--openai":
                let role: ModelRouteRole = switch option {
                case "--claude": .claude
                case "--grok": .grok
                default: .openAI
                }
                guard cloudModels[role] == nil else {
                    throw ModelCommandError.duplicateOption(option)
                }
                cloudModels[role] = value
            default:
                throw ModelCommandError.unsupportedOption(option)
            }
            index += 2
        }

        guard let localModelID else {
            throw ModelCommandError.missingRequiredOption("--local")
        }
        guard let localEndpoint else {
            throw ModelCommandError.missingRequiredOption("--local-endpoint")
        }
        return .profileCreate(
            id: id,
            localModelID: localModelID,
            localEndpoint: localEndpoint,
            cloudModels: cloudModels
        )
    }
}

public enum ModelCommandError: Error, Equatable {
    case unsupportedCommand([String])
    case unsupportedOption(String)
    case missingRequiredOption(String)
    case missingValue(String)
    case duplicateOption(String)
    case invalidRole(String)
}
