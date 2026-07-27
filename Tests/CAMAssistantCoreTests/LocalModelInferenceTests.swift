import Foundation
import Testing
@testable import CAMAssistantCore

@Test("local model health proves the selected model at the configured loopback endpoint")
func localModelHealthProvesSelectedIdentity() async throws {
    let transport = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(#"{"data":[{"id":"local/qwen"}]}"#.utf8)
        ),
    ])
    let client = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: transport
    )

    let health = try await client.health()

    #expect(health.modelID == "local/qwen")
    #expect(health.endpointIdentity == "http://127.0.0.1:8080/v1")
    #expect(health.isAvailable)
    let requests = await transport.recordedRequests()
    #expect(requests.count == 1)
    #expect(requests[0].method == .get)
    #expect(requests[0].url.absoluteString == "http://127.0.0.1:8080/v1/models")
    #expect(requests[0].headers["Authorization"] == nil)
    #expect(requests[0].body == nil)
}

@Test("local model generation returns only exact retrieved passage citations")
func localModelGenerationReturnsExactRetrievedCitations() async throws {
    let responseContent =
        #"{"answer":"The vault remains local.","passage_ids":["source-1#0"]}"#
    let envelope = LocalModelTestEnvelope.chat(
        model: "local/qwen",
        content: responseContent
    )
    let transport = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(statusCode: 200, data: envelope),
    ])
    let client = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: transport
    )
    let context = localInferenceContext()

    let answer = try await client.generate(
        question: "Where does the vault remain?",
        context: context
    )

    #expect(answer.text == "The vault remains local.")
    #expect(answer.modelID == "local/qwen")
    #expect(answer.citations == [
        Citation(
            sourceID: "source-1",
            passageID: "source-1#0",
            quote: "The CAM Assistant vault remains local by default."
        ),
    ])
    #expect(answer.retention == .ephemeral)

    let requests = await transport.recordedRequests()
    #expect(requests.count == 1)
    #expect(requests[0].method == .post)
    #expect(requests[0].url.absoluteString == "http://127.0.0.1:8080/v1/chat/completions")
    #expect(requests[0].headers == ["Content-Type": "application/json"])
    let body = try #require(requests[0].body)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["model"] as? String == "local/qwen")
    #expect(json["stream"] as? Bool == false)
    #expect(json["max_tokens"] as? Int == 256)
    #expect(json["seed"] as? Int == 0)
    let responseFormat = try #require(
        json["response_format"] as? [String: Any]
    )
    #expect(responseFormat["type"] as? String == "json_schema")
    let jsonSchema = try #require(
        responseFormat["json_schema"] as? [String: Any]
    )
    #expect(jsonSchema["name"] as? String == "grounded_answer")
    let schema = try #require(jsonSchema["schema"] as? [String: Any])
    #expect(schema["additionalProperties"] as? Bool == false)
    #expect(
        Set(try #require(schema["required"] as? [String]))
            == ["answer", "passage_ids"]
    )
    let properties = try #require(
        schema["properties"] as? [String: Any]
    )
    let passageIDs = try #require(
        properties["passage_ids"] as? [String: Any]
    )
    let items = try #require(passageIDs["items"] as? [String: Any])
    #expect(
        items["enum"] as? [String]
            == ["source-1#0"]
    )
    let bodyText = try #require(String(data: body, encoding: .utf8))
    #expect(bodyText.contains("Valid passage IDs: source-1#0"))
}

@Test("local model generation fails closed for unknown or absent evidence")
func localModelGenerationFailsClosedForUngroundedOutput() async throws {
    let unknownCitation = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: LocalModelTestEnvelope.chat(
                model: "local/qwen",
                content: #"{"answer":"Unsupported.","passage_ids":["missing#0"]}"#
            )
        ),
    ])
    let client = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: unknownCitation
    )

    await #expect(throws: LocalModelInferenceError.ungroundedResponse) {
        _ = try await client.generate(
            question: "What is known?",
            context: localInferenceContext()
        )
    }

    let noContextTransport = RecordingLocalModelTransport(responses: [])
    let noContextClient = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: noContextTransport
    )
    let empty = ContextBundle(
        formatVersion: "context-v1",
        passages: [],
        serializedContext: "",
        totalCharacters: 0,
        estimatedTokens: 0,
        droppedPassages: 0,
        thrashRate: 0
    )
    await #expect(throws: LocalModelInferenceError.missingContext) {
        _ = try await noContextClient.generate(
            question: "What is known?",
            context: empty
        )
    }
    #expect(await noContextTransport.recordedRequests().isEmpty)
}

@Test("local model accepts only an explicit empty answer as abstention")
func localModelAcceptsOnlyExplicitEmptyAbstention() async throws {
    let abstaining = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: LocalModelTestEnvelope.chat(
                model: "local/qwen",
                content: #"{"answer":"","passage_ids":[]}"#
            )
        ),
    ])
    let abstainingClient = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: abstaining
    )

    let answer = try await abstainingClient.generate(
        question: "What is not supported?",
        context: localInferenceContext()
    )

    #expect(answer.didAbstain)
    #expect(answer.text.isEmpty)
    #expect(answer.citations.isEmpty)
    #expect(answer.retention == .ephemeral)

    let mixed = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: LocalModelTestEnvelope.chat(
                model: "local/qwen",
                content: #"{"answer":"","passage_ids":["source-1#0"]}"#
            )
        ),
    ])
    let mixedClient = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: mixed
    )
    await #expect(throws: LocalModelInferenceError.ungroundedResponse) {
        _ = try await mixedClient.generate(
            question: "What is not supported?",
            context: localInferenceContext()
        )
    }
}

@Test("local model endpoint errors and identity drift fail visibly")
func localModelEndpointErrorsAndIdentityDriftFailVisibly() async throws {
    let unavailable = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(statusCode: 503, data: Data()),
    ])
    let unavailableClient = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: unavailable
    )
    await #expect(throws: LocalModelInferenceError.httpStatus(503)) {
        _ = try await unavailableClient.health()
    }

    let drifted = RecordingLocalModelTransport(responses: [
        LocalModelHTTPResponse(
            statusCode: 200,
            data: LocalModelTestEnvelope.chat(
                model: "unexpected/model",
                content: #"{"answer":"Text.","passage_ids":["source-1#0"]}"#
            )
        ),
    ])
    let driftedClient = try LocalModelClient(
        assignment: localInferenceAssignment(),
        transport: drifted
    )
    await #expect(
        throws: LocalModelInferenceError.modelIdentityMismatch(
            expected: "local/qwen",
            actual: "unexpected/model"
        )
    ) {
        _ = try await driftedClient.generate(
            question: "Where?",
            context: localInferenceContext()
        )
    }
}

@Test("grounded local model answer becomes an identified ephemeral conversation response")
func groundedLocalModelAnswerBecomesIdentifiedConversationResponse() throws {
    let generated = LocalModelGeneratedAnswer(
        text: "The vault remains local.",
        modelID: "local/qwen",
        endpointIdentity: "http://127.0.0.1:8080/v1",
        citations: [
            Citation(
                sourceID: "source-1",
                passageID: "source-1#0",
                quote: "The CAM Assistant vault remains local by default."
            ),
        ],
        retention: .ephemeral
    )

    let response = try ConversationCoordinator().respond(
        question: "Where does the vault remain?",
        generated: generated
    )

    #expect(response.route == .localModel)
    #expect(response.text == "The vault remains local.")
    #expect(response.modelIdentity == "local/qwen")
    #expect(response.endpointIdentity == "http://127.0.0.1:8080/v1")
    #expect(response.citations == generated.citations)
    #expect(response.confidence == .supported)
    #expect(response.retention == .ephemeral)
    #expect(response.followUp == nil)
}

@Test("live local model transport rejects every redirect")
func liveLocalModelTransportRejectsEveryRedirect() throws {
    #expect(
        !URLSessionLocalModelTransport.allowsRedirect(
            to: try #require(URL(string: "https://example.com/v1/models"))
        )
    )
    #expect(
        !URLSessionLocalModelTransport.allowsRedirect(
            to: try #require(URL(string: "http://127.0.0.1:8081/v1/models"))
        )
    )
}

private actor RecordingLocalModelTransport: LocalModelTransport {
    private var responses: [LocalModelHTTPResponse]
    private var requests: [LocalModelHTTPRequest] = []

    init(responses: [LocalModelHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: LocalModelHTTPRequest) async throws -> LocalModelHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw LocalModelInferenceError.transportUnavailable
        }
        return responses.removeFirst()
    }

    func recordedRequests() -> [LocalModelHTTPRequest] {
        requests
    }
}

private enum LocalModelTestEnvelope {
    static func chat(model: String, content: String) -> Data {
        let object: [String: Any] = [
            "model": model,
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": content,
                    ],
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }
}

private func localInferenceAssignment() throws -> ModelAssignment {
    try ModelAssignment(
        provider: .local,
        modelID: "local/qwen",
        localEndpoint: "http://127.0.0.1:8080/v1"
    )
}

private func localInferenceContext() -> ContextBundle {
    let passage = ContextPassage(
        sourceID: "source-1",
        passageID: "source-1#0",
        modality: "text",
        text: "The CAM Assistant vault remains local by default."
    )
    return ContextBundle(
        formatVersion: "context-v1",
        passages: [passage],
        serializedContext: """
        [source=source-1; passage=source-1#0]
        The CAM Assistant vault remains local by default.
        """,
        totalCharacters: passage.text.count,
        estimatedTokens: 12,
        droppedPassages: 0,
        thrashRate: 0
    )
}
