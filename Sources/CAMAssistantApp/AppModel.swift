import CAMAssistantCore
import SwiftUI

enum AssistantSection: String, CaseIterable, Identifiable {
    case assistant = "Assistant"
    case library = "Library"
    case activity = "Activity"
    case settings = "Settings"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .assistant:
            "sparkles"
        case .library:
            "books.vertical"
        case .activity:
            "clock.arrow.circlepath"
        case .settings:
            "gearshape"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: AssistantSection = .assistant
    @Published private(set) var health: AppHealth

    init(
        health: AppHealth = .evaluate(
            localModelAvailable: false,
            camRuntimeAvailable: false,
            networkAvailable: false
        )
    ) {
        self.health = health
    }

    func updateHealth(
        localModelAvailable: Bool,
        camRuntimeAvailable: Bool,
        networkAvailable: Bool
    ) {
        health = .evaluate(
            localModelAvailable: localModelAvailable,
            camRuntimeAvailable: camRuntimeAvailable,
            networkAvailable: networkAvailable
        )
    }
}
