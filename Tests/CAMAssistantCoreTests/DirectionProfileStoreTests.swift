import Foundation
import Testing
@testable import CAMAssistantCore

@Test("Direction profile loads empty when missing")
func directionProfileLoadsEmptyWhenMissing() throws {
    let fixture = try DirectionProfileFixture()
    #expect(try fixture.store.load() == .empty)
}

@Test("Direction profile adds person and survives restart")
func directionProfileAddsPersonAndSurvivesRestart() throws {
    let fixture = try DirectionProfileFixture()
    let profile = try fixture.store.addPerson(
        name: "Jordan",
        relation: "friend",
        now: fixture.now
    )

    #expect(profile.people.count == 1)
    #expect(profile.people[0].name == "Jordan")
    #expect(profile.people[0].relation == "friend")

    let restarted = DirectionProfileStore(url: fixture.url)
    let reloaded = try restarted.load()
    #expect(reloaded.people.map(\.name) == ["Jordan"])
}

@Test("Direction profile rejects blank person name")
func directionProfileRejectsBlankPersonName() throws {
    let fixture = try DirectionProfileFixture()
    #expect(throws: DirectionProfileError.blankPersonName) {
        _ = try fixture.store.addPerson(name: "   ")
    }
}

@Test("Direction profile adds promise and can mark done")
func directionProfileAddsPromiseAndMarksDone() throws {
    let fixture = try DirectionProfileFixture()
    var profile = try fixture.store.addPromise(
        text: "Call Jordan this week",
        toward: "Jordan",
        now: fixture.now
    )
    #expect(profile.openPromises.count == 1)

    let id = try #require(profile.promises.first?.id)
    profile = try fixture.store.setPromiseOpen(id: id, isOpen: false)
    #expect(profile.openPromises.isEmpty)
    #expect(profile.promises.first?.isOpen == false)
}

@Test("Direction profile rejects blank promise")
func directionProfileRejectsBlankPromise() throws {
    let fixture = try DirectionProfileFixture()
    #expect(throws: DirectionProfileError.blankPromiseText) {
        _ = try fixture.store.addPromise(text: "\n")
    }
}

@Test("Direction profile sets north star")
func directionProfileSetsNorthStar() throws {
    let fixture = try DirectionProfileFixture()
    let profile = try fixture.store.setNorthStar(
        "Show up for the people who matter"
    )
    #expect(profile.northStar == "Show up for the people who matter")
    #expect(try fixture.store.load().northStar == profile.northStar)
}

@Test("Direction continuity summary lists people and promises")
func directionContinuitySummaryListsPeopleAndPromises() throws {
    let fixture = try DirectionProfileFixture()
    _ = try fixture.store.addPerson(name: "Avery", relation: "partner")
    _ = try fixture.store.addPromise(text: "Walk together", toward: "Avery")
    _ = try fixture.store.setNorthStar("Be present")
    let summary = try fixture.store.load().continuitySummary
    #expect(summary.contains("Avery"))
    #expect(summary.contains("Walk together"))
    #expect(summary.contains("Be present"))
}

@Test("Direction profile removes person and promise")
func directionProfileRemovesPersonAndPromise() throws {
    let fixture = try DirectionProfileFixture()
    var profile = try fixture.store.addPerson(name: "Jordan")
    let personID = try #require(profile.people.first?.id)
    profile = try fixture.store.addPromise(text: "Call", toward: "Jordan")
    let promiseID = try #require(profile.promises.first?.id)

    profile = try fixture.store.removePromise(id: promiseID)
    #expect(profile.promises.isEmpty)
    profile = try fixture.store.removePerson(id: personID)
    #expect(profile.people.isEmpty)
}

@Test("Direction profile updates person name")
func directionProfileUpdatesPersonName() throws {
    let fixture = try DirectionProfileFixture()
    var profile = try fixture.store.addPerson(name: "Jo", relation: "friend")
    let id = try #require(profile.people.first?.id)
    profile = try fixture.store.updatePerson(
        id: id,
        name: "Jordan",
        relation: "close friend"
    )
    #expect(profile.people.first?.name == "Jordan")
    #expect(profile.people.first?.relation == "close friend")
}

private struct DirectionProfileFixture {
    let root: URL
    let url: URL
    let store: DirectionProfileStore
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(
            path: "cam-direction-\(UUID().uuidString)"
        )
        url = root.appending(path: "direction-profile.json")
        store = DirectionProfileStore(url: url)
    }
}
