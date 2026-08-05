import Foundation
import Testing
@testable import CAMAssistantCore

@Test("one Ask uses a healthy selected local model and preserves citations")
func oneAskUsesHealthySelectedLocalModel() async throws {
    let context = localAnswerContext()
    let coordinator = LocalAnswerCoordinator(
        loadContext: { _ in context },
        isModelAvailable: true,
        generate: { _, _ in
            LocalModelGeneratedAnswer(
                text: "The appointment is Tuesday.",
                modelID: "local/test-model",
                endpointIdentity: "http://127.0.0.1:8080/v1",
                citations: [
                    Citation(
                        sourceID: "notes",
                        passageID: "notes#0",
                        quote: "The appointment is Tuesday at 10."
                    ),
                ],
                retention: .ephemeral
            )
        }
    )

    let result = try await coordinator.answer("When is the appointment?")

    #expect(result.mode == .localAI)
    #expect(result.response.route == .localModel)
    #expect(result.response.citations.map(\.passageID) == ["notes#0"])
}

@Test("one Ask shows matching passages without making a model request when unavailable")
func oneAskFallsBackLocallyWithoutOutboundRequest() async throws {
    let requestCount = RequestCount()
    let context = localAnswerContext()
    let coordinator = LocalAnswerCoordinator(
        loadContext: { _ in context },
        isModelAvailable: false,
        generate: { _, _ in
            await requestCount.record()
            throw LocalModelInferenceError.transportUnavailable
        }
    )

    let result = try await coordinator.answer("When is the appointment?")

    #expect(result.mode == .matchingPassages)
    #expect(result.response.route == .localRetrieval)
    #expect(result.response.citations.map(\.passageID) == ["notes#0"])
    #expect(await requestCount.value == 0)
}

@Test("one Ask admits insufficient evidence instead of inventing an answer")
func oneAskAdmitsInsufficientEvidence() async throws {
    let empty = ContextBundle(
        formatVersion: "context-v1",
        passages: [],
        serializedContext: "",
        totalCharacters: 0,
        estimatedTokens: 0,
        droppedPassages: 0,
        thrashRate: 0
    )
    let coordinator = LocalAnswerCoordinator(
        loadContext: { _ in empty },
        isModelAvailable: true,
        generate: { _, _ in
            Issue.record("The model must not run without supporting passages")
            throw LocalModelInferenceError.missingContext
        }
    )

    let result = try await coordinator.answer("What is the launch date?")

    #expect(result.mode == .notEnoughInformation)
    #expect(result.response.citations.isEmpty)
    #expect(result.response.confidence == .low)
}

private func localAnswerContext() -> ContextBundle {
    ContextBundle(
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
}

private actor RequestCount {
    private(set) var value = 0

    func record() {
        value += 1
    }
}
