import Foundation

public struct ContextBudget: Equatable, Sendable {
    public let maxCharacters: Int
    public let maxEstimatedTokens: Int
    public let maxPassages: Int

    public init(
        maxCharacters: Int,
        maxEstimatedTokens: Int,
        maxPassages: Int
    ) {
        self.maxCharacters = max(0, maxCharacters)
        self.maxEstimatedTokens = max(0, maxEstimatedTokens)
        self.maxPassages = max(0, maxPassages)
    }
}

public struct ContextPassage: Codable, Equatable, Sendable {
    public let sourceID: String
    public let passageID: String
    public let modality: String
    public let text: String
}

public struct ContextBundle: Codable, Equatable, Sendable {
    public let formatVersion: String
    public let passages: [ContextPassage]
    public let serializedContext: String
    public let totalCharacters: Int
    public let estimatedTokens: Int
    public let droppedPassages: Int
    public let thrashRate: Double

    public init(
        formatVersion: String,
        passages: [ContextPassage],
        serializedContext: String,
        totalCharacters: Int,
        estimatedTokens: Int,
        droppedPassages: Int,
        thrashRate: Double
    ) {
        self.formatVersion = formatVersion
        self.passages = passages
        self.serializedContext = serializedContext
        self.totalCharacters = totalCharacters
        self.estimatedTokens = estimatedTokens
        self.droppedPassages = droppedPassages
        self.thrashRate = thrashRate
    }
}

public struct ContextAssembler {
    public init() {}

    public func assemble(
        _ results: [RetrievalResult],
        budget: ContextBudget
    ) -> ContextBundle {
        var passages: [ContextPassage] = []
        var serializedParts: [String] = []
        var characters = 0
        var tokens = 0

        for result in results {
            let serializedPassage = Self.serializedPassage(for: result)
            let passageCharacters = serializedPassage.count
            let passageTokens = Self.estimatedTokens(forCharacterCount: passageCharacters)
            guard passages.count < budget.maxPassages,
                  characters + passageCharacters <= budget.maxCharacters,
                  tokens + passageTokens <= budget.maxEstimatedTokens else {
                continue
            }
            passages.append(
                ContextPassage(
                    sourceID: result.sourceID,
                    passageID: result.passageID,
                    modality: result.modality,
                    text: result.text
                )
            )
            serializedParts.append(serializedPassage)
            characters += passageCharacters
            tokens += passageTokens
        }

        let dropped = results.count - passages.count
        return ContextBundle(
            formatVersion: "context-v1",
            passages: passages,
            serializedContext: serializedParts.joined(),
            totalCharacters: characters,
            estimatedTokens: tokens,
            droppedPassages: dropped,
            thrashRate: results.isEmpty ? 0 : Double(dropped) / Double(results.count)
        )
    }

    private static func estimatedTokens(forCharacterCount count: Int) -> Int {
        (count + 3) / 4
    }

    private static func serializedPassage(for result: RetrievalResult) -> String {
        "[source=\(result.sourceID); passage=\(result.passageID); modality=\(result.modality)]\n\(result.text)\n"
    }
}
