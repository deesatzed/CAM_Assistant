enum AppExperience: Sendable, Equatable {
    case primary
    case developer

    static let productionDefault: Self = .primary

    var visibleSections: [AssistantSection] {
        switch self {
        case .primary:
            [.home, .library, .settings]
        case .developer:
            AssistantSection.allCases.filter { $0 != .home }
        }
    }

    var rootSection: AssistantSection {
        switch self {
        case .primary: .home
        case .developer: .assistant
        }
    }
}
