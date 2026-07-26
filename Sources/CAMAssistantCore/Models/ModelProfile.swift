import Foundation

public enum ModelProvider: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case local
    case claude
    case grok
    case openAI
}

public enum ModelProfileError: Error, Equatable {
    case invalidProfileID
    case invalidRevision
    case emptyModelID
    case missingLocalAssignment
    case invalidProviderForRole
    case invalidLocalEndpoint
}

public struct ModelAssignment: Codable, Equatable, Sendable {
    public let provider: ModelProvider
    public let modelID: String
    public let localEndpoint: String?

    public init(
        provider: ModelProvider,
        modelID: String,
        localEndpoint: String?
    ) throws {
        guard !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModelProfileError.emptyModelID
        }
        if provider == .local {
            guard let localEndpoint, Self.isSafeLocalEndpoint(localEndpoint) else {
                throw ModelProfileError.invalidLocalEndpoint
            }
        } else if localEndpoint != nil {
            throw ModelProfileError.invalidProviderForRole
        }
        self.provider = provider
        self.modelID = modelID
        self.localEndpoint = localEndpoint
    }

    private static func isSafeLocalEndpoint(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.scheme == "http" || components.scheme == "https",
              let host = components.host?.lowercased(),
              host == "localhost" || host == "127.0.0.1" || host == "::1",
              components.user == nil,
              components.password == nil else {
            return false
        }
        let queryNames = Set((components.queryItems ?? []).map { $0.name.lowercased() })
        return queryNames.isDisjoint(with: ["api_key", "apikey", "token", "secret"])
    }
}

public struct ModelProfile: Codable, Equatable, Sendable {
    public let id: String
    public let revision: Int
    public let assignments: [ModelRouteRole: ModelAssignment]

    public init(
        id: String,
        revision: Int,
        assignments: [ModelRouteRole: ModelAssignment]
    ) throws {
        guard Self.isValidID(id) else { throw ModelProfileError.invalidProfileID }
        guard revision > 0 else { throw ModelProfileError.invalidRevision }
        guard assignments[.local] != nil else {
            throw ModelProfileError.missingLocalAssignment
        }
        for (role, assignment) in assignments {
            guard Self.provider(for: role) == assignment.provider else {
                throw ModelProfileError.invalidProviderForRole
            }
        }
        self.id = id
        self.revision = revision
        self.assignments = assignments
    }

    public func assignment(for role: ModelRouteRole) -> ModelAssignment? {
        assignments[role]
    }

    private static func provider(for role: ModelRouteRole) -> ModelProvider {
        switch role {
        case .local: .local
        case .claude: .claude
        case .grok: .grok
        case .openAI: .openAI
        }
    }

    private static func isValidID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.first?.isLetter == true else { return false }
        return value.allSatisfy {
            $0.isLowercase || $0.isNumber || $0 == "-"
        }
    }
}
