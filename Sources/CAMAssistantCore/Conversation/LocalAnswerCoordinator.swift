import Foundation

public enum LocalAnswerMode: String, Equatable, Sendable {
    case localAI
    case matchingPassages
    case notEnoughInformation
}

public struct LocalAnswerResult: Equatable, Sendable {
    public let response: ConversationResponse
    public let mode: LocalAnswerMode
}

/// The single user-facing Ask policy. Retrieval always happens first. A
/// previously health-checked selected loopback model may synthesize from that
/// evidence; otherwise the evidence itself is returned. There is no provider,
/// cloud, web, CAM, retry, or alternate-model route in this coordinator.
public struct LocalAnswerCoordinator: Sendable {
    public typealias ContextLoader =
        @Sendable (String) async throws -> ContextBundle
    public typealias Generator =
        @Sendable (String, ContextBundle) async throws -> LocalModelGeneratedAnswer

    private let loadContext: ContextLoader
    private let isModelAvailable: Bool
    private let generate: Generator

    public init(
        loadContext: @escaping ContextLoader,
        isModelAvailable: Bool,
        generate: @escaping Generator
    ) {
        self.loadContext = loadContext
        self.isModelAvailable = isModelAvailable
        self.generate = generate
    }

    public func answer(_ question: String) async throws -> LocalAnswerResult {
        let context = try await loadContext(question)
        let extractive = try ConversationCoordinator().respond(
            question: question,
            context: context
        )
        guard !context.passages.isEmpty else {
            return LocalAnswerResult(
                response: extractive,
                mode: .notEnoughInformation
            )
        }
        guard isModelAvailable else {
            return LocalAnswerResult(
                response: extractive,
                mode: .matchingPassages
            )
        }

        do {
            let generated = try await generate(question, context)
            guard !generated.didAbstain,
                  Self.isGrounded(generated.citations, in: context) else {
                return LocalAnswerResult(
                    response: extractive,
                    mode: .matchingPassages
                )
            }
            let response = try ConversationCoordinator().respond(
                question: question,
                generated: generated
            )
            return LocalAnswerResult(response: response, mode: .localAI)
        } catch {
            return LocalAnswerResult(
                response: extractive,
                mode: .matchingPassages
            )
        }
    }

    private static func isGrounded(
        _ citations: [Citation],
        in context: ContextBundle
    ) -> Bool {
        guard !citations.isEmpty else { return false }
        return citations.allSatisfy { citation in
            context.passages.contains { passage in
                passage.sourceID == citation.sourceID
                    && passage.passageID == citation.passageID
                    && !citation.quote.isEmpty
                    && passage.text.contains(citation.quote)
            }
        }
    }
}
