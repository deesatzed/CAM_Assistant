import Foundation

public struct ModelSettingsState: Equatable, Sendable {
    public let activeProfile: ModelProfile?
    public let availableRoles: [ModelRouteRole]
    public let unavailableRoles: [ModelRouteRole]
    public let availabilityMessage: String

    public init(registry: ModelRegistry) throws {
        activeProfile = try registry.activeProfile()
        let available = try registry.availableRoles()
        availableRoles = ModelRouteRole.allCases.filter(available.contains)
        unavailableRoles = ModelRouteRole.allCases.filter { !available.contains($0) }
        availabilityMessage = Self.message(
            profile: activeProfile,
            unavailableRoles: unavailableRoles
        )
    }

    private static func message(
        profile: ModelProfile?,
        unavailableRoles: [ModelRouteRole]
    ) -> String {
        guard let profile else { return "No active local model profile." }
        guard !unavailableRoles.isEmpty else {
            return "Local profile \(profile.id) is active; all configured roles are available."
        }
        let names = unavailableRoles.map { role in
            switch role {
            case .local: "Local"
            case .claude: "Claude"
            case .grok: "Grok"
            case .openAI: "OpenAI"
            }
        }
        return "Local profile \(profile.id) is active; \(names.joined(separator: " and ")) are unavailable."
    }
}
