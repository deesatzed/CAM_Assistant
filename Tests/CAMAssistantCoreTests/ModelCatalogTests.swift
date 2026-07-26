import Foundation
import Testing
@testable import CAMAssistantCore

@Test("recorded catalog preserves model facts without selecting a profile")
func recordedCatalogPreservesFactsWithoutSelection() throws {
    let catalog = try ModelCatalog.decode(
        Data(contentsOf: modelCatalogFixtureURL())
    )
    let root = try modelCatalogTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = try ModelRegistry(stateURL: root.appending(path: "models.json"))

    #expect(catalog.schemaVersion == 1)
    #expect(catalog.provider == .openRouter)
    #expect(catalog.models.map(\.id) == [
        "example/local-compatible-chat",
        "example/vision-chat",
    ])
    #expect(catalog.models[1].contextWindow == 128000)
    #expect(catalog.models[1].modalities == ["text", "image"])
    #expect(try registry.activeProfile() == nil)
}

@Test("catalog rejects duplicate model identifiers")
func catalogRejectsDuplicateModelIdentifiers() throws {
    let data = Data(
        """
        {
          "schemaVersion": 1,
          "provider": "openrouter",
          "recordedAt": "2026-07-26T00:00:00Z",
          "models": [
            {"id": "duplicate", "contextWindow": 1, "inputPricePerMillion": 0, "outputPricePerMillion": 0, "modalities": ["text"]},
            {"id": "duplicate", "contextWindow": 1, "inputPricePerMillion": 0, "outputPricePerMillion": 0, "modalities": ["text"]}
          ]
        }
        """.utf8
    )

    #expect(throws: ModelCatalogError.duplicateModelID("duplicate")) {
        _ = try ModelCatalog.decode(data)
    }
}

private func modelCatalogFixtureURL() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Tests/Fixtures/Models/catalog-v1.json")
}

private func modelCatalogTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "cam-assistant-model-catalog-tests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
