import Foundation
import Testing
@testable import CAMAssistantCore

@Test("model profile applicator creates and updates local selection without CLI")
func modelProfileApplicatorCreatesAndUpdatesLocalSelection() throws {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "cam-model-selection-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appending(path: "models.json")

    let created = try ModelProfileApplicator.applyLocalSelection(
        stateURL: stateURL,
        modelID: "gemma-4-12b-it-optiq",
        endpoint: LocalModelCatalog.lmStudioDefaultEndpoint
    )
    #expect(created.id == "default-local")
    #expect(created.assignment(for: .local)?.modelID == "gemma-4-12b-it-optiq")

    let updated = try ModelProfileApplicator.applyLocalSelection(
        stateURL: stateURL,
        modelID: "vibethinker-3b-optiq-5bpw-mlx",
        endpoint: LocalModelCatalog.lmStudioDefaultEndpoint
    )
    #expect(updated.revision == 2)
    #expect(
        updated.assignment(for: .local)?.modelID
            == "vibethinker-3b-optiq-5bpw-mlx"
    )

    let registry = try ModelRegistry(stateURL: stateURL)
    #expect(try registry.activeProfile()?.id == "default-local")
}

@Test("local model catalog lists ids from openAI-compatible models response")
func localModelCatalogListsIDsFromOpenAICompatibleModelsResponse() async throws {
    let transport = CatalogTransport(
        response: LocalModelHTTPResponse(
            statusCode: 200,
            data: Data(
                #"{"data":[{"id":"b-model"},{"id":"a-model"}]}"#.utf8
            )
        )
    )
    let ids = try await LocalModelCatalog.listModelIDs(
        endpoint: "http://127.0.0.1:1234/v1",
        transport: transport
    )
    #expect(ids == ["a-model", "b-model"])
}

@Test("openrouter endpoint policy allows only openrouter https host")
func openRouterEndpointPolicyAllowsOnlyOpenRouterHTTPSHost() {
    #expect(
        OpenRouterSettings.isAllowedEndpoint(
            "https://openrouter.ai/api/v1"
        )
    )
    #expect(
        !OpenRouterSettings.isAllowedEndpoint(
            "http://openrouter.ai/api/v1"
        )
    )
    #expect(
        !OpenRouterSettings.isAllowedEndpoint(
            "https://evil.example/api/v1"
        )
    )
    #expect(
        !OpenRouterSettings.isAllowedEndpoint(
            "https://openrouter.ai/api/v1?x=1"
        )
    )
}

private struct CatalogTransport: LocalModelTransport {
    let response: LocalModelHTTPResponse

    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        response
    }
}
