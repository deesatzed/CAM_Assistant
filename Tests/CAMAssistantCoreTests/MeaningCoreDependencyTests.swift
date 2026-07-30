import MeaningCore
import Testing

@Test("pinned MeaningCore exposes the verified pilot contracts")
func pinnedMeaningCoreContractsAreAvailable() {
    #expect(ScenarioSuite.verify())
    #expect(FamiliarityTracker().stage(for: "pilot") == .usefulStranger)
    #expect(GlanceProjection(item: nil).actions.isEmpty)
}
