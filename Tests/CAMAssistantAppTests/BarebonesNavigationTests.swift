import Testing
@testable import CAMAssistantApp

@Test("primary experience exposes only the ordinary three destinations")
func primarySectionsAreSmall() {
    #expect(
        AppExperience.primary.visibleSections
            == [.home, .library, .settings]
    )
}

@Test("production defaults to the primary experience")
func productionDefaultIsPrimary() {
    #expect(AppExperience.productionDefault == .primary)
}

@Test("specialist destinations require explicit developer injection")
func specialistSectionsStayHidden() {
    #expect(!AppExperience.primary.visibleSections.contains(.cam))
    #expect(!AppExperience.primary.visibleSections.contains(.meaningPreview))
    #expect(AppExperience.developer.visibleSections.contains(.cam))
    #expect(AppExperience.developer.visibleSections.contains(.meaningPreview))
}

@MainActor
@Test("AppModel receives the primary experience by default")
func appModelDefaultsToPrimaryExperience() {
    let model = AppModel(initializeFullWorkspace: false)
    #expect(model.experience == .primary)
    #expect(model.selection == .home)
}
