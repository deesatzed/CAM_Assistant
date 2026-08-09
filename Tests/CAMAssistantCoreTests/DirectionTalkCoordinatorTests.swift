import Foundation
import Testing
@testable import CAMAssistantCore

@Test("Talk offline coach never calls model or invents partner prose path")
func talkOfflineCoachNeverCallsModel() async throws {
    let callCounter = CallCounter()
    let coordinator = DirectionTalkCoordinator(
        isModelAvailable: false,
        loadContext: { _ in
            Issue.record("context must not load when offline coach short-circuits")
            throw LocalModelInferenceError.transportUnavailable
        },
        answerLibrary: { _ in
            await callCounter.increment()
            throw LocalModelInferenceError.transportUnavailable
        }
    )
    let result = try await coordinator.respond(
        question: "Who matters?",
        profile: DirectionProfile.empty
    )
    #expect(result.mode == DirectionTalkMode.offlineCoach)
    #expect(result.text == DirectionTalkCoordinator.offlineCoachMessage)
    #expect(result.response == nil)
    #expect(await callCounter.value == 0)
}

@Test("Talk admits absence when Library is empty and question is not direction-only")
func talkAdmitsAbsenceWithoutInventingLibrary() async throws {
    let empty = ContextBundle(
        formatVersion: "context-v1",
        passages: [],
        serializedContext: "",
        totalCharacters: 0,
        estimatedTokens: 0,
        droppedPassages: 0,
        thrashRate: 0
    )
    let coordinator = DirectionTalkCoordinator(
        isModelAvailable: true,
        loadContext: { _ in empty },
        answerLibrary: { _ in
            Issue.record("library answerer must not run without passages")
            throw LocalModelInferenceError.missingContext
        }
    )
    let result = try await coordinator.respond(
        question: "What does my saved contract say about renewal?",
        profile: DirectionProfile.empty
    )
    #expect(result.mode == DirectionTalkMode.admitAbsence)
    #expect(result.text == DirectionTalkCoordinator.admitAbsenceMessage)
}

@Test("Talk returns profile continuity without Library citations")
func talkReturnsProfileContinuity() async throws {
    let empty = ContextBundle(
        formatVersion: "context-v1",
        passages: [],
        serializedContext: "",
        totalCharacters: 0,
        estimatedTokens: 0,
        droppedPassages: 0,
        thrashRate: 0
    )
    let profile = DirectionProfile(
        people: [DirectionPerson(name: "Jordan", relation: "friend")],
        promises: [
            DirectionPromise(text: "Call this week", toward: "Jordan"),
        ],
        northStar: "Show up"
    )
    let coordinator = DirectionTalkCoordinator(
        isModelAvailable: true,
        loadContext: { _ in empty },
        answerLibrary: { _ in
            Issue.record("must not invent library path")
            throw LocalModelInferenceError.missingContext
        }
    )
    let result = try await coordinator.respond(
        question: "Who matters to me?",
        profile: profile
    )
    #expect(result.mode == DirectionTalkMode.profileContinuity)
    #expect(result.text.contains("Jordan"))
    #expect(result.text.contains("Call this week"))
    #expect(result.response == nil)
}

@Test("Talk library path preserves grounded local AI answer")
func talkLibraryPathPreservesGroundedAnswer() async throws {
    let context = ContextBundle(
        formatVersion: "context-v1",
        passages: [
            ContextPassage(
                sourceID: "notes",
                passageID: "notes#0",
                modality: "text",
                text: "The appointment is Tuesday at 10."
            ),
        ],
        serializedContext: "[source=notes; passage=notes#0]\nThe appointment is Tuesday at 10.",
        totalCharacters: 37,
        estimatedTokens: 10,
        droppedPassages: 0,
        thrashRate: 0
    )
    let grounded = ConversationResponse(
        id: "a1",
        text: "The appointment is Tuesday.",
        route: .localModel,
        confidence: .supported,
        citations: [
            Citation(
                sourceID: "notes",
                passageID: "notes#0",
                quote: "The appointment is Tuesday at 10."
            ),
        ],
        retention: .ephemeral,
        modelIdentity: "local/test",
        endpointIdentity: "http://127.0.0.1:8080/v1",
        followUp: nil
    )
    let coordinator = DirectionTalkCoordinator(
        isModelAvailable: true,
        loadContext: { _ in context },
        answerLibrary: { _ in
            LocalAnswerResult(response: grounded, mode: .localAI)
        }
    )
    let result = try await coordinator.respond(
        question: "When is the appointment?",
        profile: DirectionProfile.empty
    )
    #expect(result.mode == DirectionTalkMode.libraryGrounded)
    #expect(result.response?.citations.map(\.passageID) == ["notes#0"])
}

private actor CallCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
