import Foundation
import Testing
@testable import CAMAssistantCore

@Test("model command parser recognizes local profile controls without a transport")
func modelCommandParserRecognizesProfileControls() throws {
    #expect(try ModelCommand.parse(["models", "current"]) == .current)
    #expect(try ModelCommand.parse(["models", "profile", "list"]) == .profileList)
    #expect(
        try ModelCommand.parse(["models", "profile", "show", "personal"])
            == .profileShow("personal")
    )
    #expect(
        try ModelCommand.parse([
            "models", "profile", "create", "personal",
            "--local", "mlx-community/Qwen3-4B",
            "--local-endpoint", "http://127.0.0.1:8080/v1",
            "--claude", "anthropic/claude-sonnet",
        ]) == .profileCreate(
            id: "personal",
            localModelID: "mlx-community/Qwen3-4B",
            localEndpoint: "http://127.0.0.1:8080/v1",
            cloudModels: [.claude: "anthropic/claude-sonnet"]
        )
    )
    #expect(
        try ModelCommand.parse(["models", "profile", "use", "personal"])
            == .profileUse("personal")
    )
    #expect(
        try ModelCommand.parse(["models", "set", "claude", "anthropic/claude-opus"])
            == .set(role: .claude, modelID: "anthropic/claude-opus")
    )
    #expect(try ModelCommand.parse(["models", "catalog"]) == .catalog(live: false))
    #expect(try ModelCommand.parse(["models", "catalog", "--live"]) == .catalog(live: true))
}

@Test("model command parser rejects malformed local profile creation")
func modelCommandParserRejectsMalformedProfileCreation() throws {
    #expect(throws: ModelCommandError.missingRequiredOption("--local")) {
        _ = try ModelCommand.parse([
            "models", "profile", "create", "personal",
            "--local-endpoint", "http://127.0.0.1:8080/v1",
        ])
    }
}

@Test("future provider and embedding commands are parsed but remain gated")
func futureProviderAndEmbeddingCommandsRemainGated() throws {
    #expect(
        try ModelCommand.parse(["models", "test", "grok"])
            == .providerTest(.grok)
    )
    #expect(
        try ModelCommand.parse(["models", "migrate", "--dry-run"])
            == .migrate(apply: false)
    )
    #expect(
        try ModelCommand.parse(["embeddings", "evaluate", "--models", "one,two", "--suite", "frozen"])
            == .embeddingsEvaluate(models: "one,two", suite: "frozen")
    )
    #expect(
        try ModelCommand.parse(["embeddings", "promote", "candidate-1"])
            == .embeddingsPromote(runID: "candidate-1")
    )

    let root = try modelCommandTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let executor = ModelCommandExecutor(
        registry: try ModelRegistry(stateURL: root.appending(path: "models.json"))
    )
    #expect(
        throws: ModelCommandExecutionError.proofGateRequired(operation: "models test grok")
    ) {
        _ = try executor.execute(.providerTest(.grok))
    }
}

@Test("local model commands mutate only the supplied registry and live catalog fails closed")
func localModelCommandsUseExplicitRegistryAndGateLiveCatalog() throws {
    let root = try modelCommandTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ModelRegistry(stateURL: root.appending(path: "models.json"))
    let executor = ModelCommandExecutor(registry: registry)

    _ = try executor.execute(
        .profileCreate(
            id: "personal",
            localModelID: "mlx-community/Qwen3-4B",
            localEndpoint: "http://127.0.0.1:8080/v1",
            cloudModels: [.claude: "anthropic/claude-sonnet"]
        )
    )
    _ = try executor.execute(.profileUse("personal"))
    _ = try executor.execute(.set(role: .claude, modelID: "anthropic/claude-opus"))

    #expect(try registry.activeProfile()?.revision == 2)
    #expect(
        try registry.activeProfile()?.assignment(for: .claude)?.modelID
            == "anthropic/claude-opus"
    )
    #expect(
        throws: ModelCommandExecutionError.outboundPolicyRequired(operation: "catalog --live")
    ) {
        _ = try executor.execute(.catalog(live: true))
    }
}

@Test("model state location is stable beneath the supplied application support root")
func modelStateLocationUsesStableApplicationSupportPath() {
    let root = URL(filePath: "/tmp/cam-assistant-app-support")
    #expect(
        ModelProfileStorage.stateURL(applicationSupportRoot: root).path
            == "/tmp/cam-assistant-app-support/CAMAssistant/models.json"
    )
}

private func modelCommandTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-model-command-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
