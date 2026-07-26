import Foundation

public enum ModelCatalogProvider: String, Codable, Equatable, Sendable {
    case openRouter = "openrouter"
}

public struct CatalogModel: Codable, Equatable, Sendable {
    public let id: String
    public let contextWindow: Int
    public let inputPricePerMillion: Double
    public let outputPricePerMillion: Double
    public let modalities: [String]
}

public enum ModelCatalogError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case duplicateModelID(String)
    case invalidModel(String)
}

public struct ModelCatalog: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let provider: ModelCatalogProvider
    public let recordedAt: String
    public let models: [CatalogModel]

    public static func decode(_ data: Data) throws -> Self {
        let catalog = try JSONDecoder().decode(Self.self, from: data)
        try catalog.validate()
        return catalog
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw ModelCatalogError.unsupportedSchemaVersion(schemaVersion)
        }
        var seen: Set<String> = []
        for model in models {
            guard seen.insert(model.id).inserted else {
                throw ModelCatalogError.duplicateModelID(model.id)
            }
            guard !model.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  model.contextWindow > 0,
                  model.inputPricePerMillion.isFinite,
                  model.inputPricePerMillion >= 0,
                  model.outputPricePerMillion.isFinite,
                  model.outputPricePerMillion >= 0,
                  !model.modalities.isEmpty,
                  model.modalities.allSatisfy({
                      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }) else {
                throw ModelCatalogError.invalidModel(model.id)
            }
        }
    }
}
