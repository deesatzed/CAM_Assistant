import Foundation

public enum LocalModelHTTPMethod: String, Equatable, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct LocalModelHTTPRequest: Equatable, Sendable {
    public let method: LocalModelHTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: Data?

    public init(
        method: LocalModelHTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct LocalModelHTTPResponse: Equatable, Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol LocalModelTransport: Sendable {
    func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse
}

public struct URLSessionLocalModelTransport: LocalModelTransport {
    public init() {}

    public static func allowsRedirect(to _: URL) -> Bool {
        false
    }

    public func send(_ request: LocalModelHTTPRequest) async throws
        -> LocalModelHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let session = URLSession(
            configuration: .ephemeral,
            delegate: LocalModelURLSessionDelegate(),
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw LocalModelInferenceError.transportUnavailable
        }
        return LocalModelHTTPResponse(
            statusCode: response.statusCode,
            data: data
        )
    }
}

private final class LocalModelURLSessionDelegate: NSObject,
    URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let redirectURL = request.url,
              URLSessionLocalModelTransport.allowsRedirect(to: redirectURL)
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

public struct LocalModelHealth: Equatable, Sendable {
    public let modelID: String
    public let endpointIdentity: String
    public let isAvailable: Bool
}

public struct LocalModelGeneratedAnswer: Equatable, Sendable {
    public let text: String
    public let modelID: String
    public let endpointIdentity: String
    public let citations: [Citation]
    public let retention: ResearchRetention
}

public enum LocalModelInferenceError: Error, Equatable {
    case invalidAssignment
    case blankQuestion
    case missingContext
    case transportUnavailable
    case httpStatus(Int)
    case invalidResponse
    case selectedModelUnavailable(String)
    case modelIdentityMismatch(expected: String, actual: String)
    case ungroundedResponse
}

public struct LocalModelClient: Sendable {
    private let modelID: String
    private let endpointIdentity: String
    private let baseURL: URL
    private let transport: any LocalModelTransport

    public init(
        assignment: ModelAssignment,
        transport: any LocalModelTransport = URLSessionLocalModelTransport()
    ) throws {
        guard assignment.provider == .local,
              let endpoint = assignment.localEndpoint,
              let baseURL = URL(string: endpoint) else {
            throw LocalModelInferenceError.invalidAssignment
        }
        modelID = assignment.modelID
        endpointIdentity = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseURL = baseURL
        self.transport = transport
    }

    public func health() async throws -> LocalModelHealth {
        let response = try await perform(
            LocalModelHTTPRequest(
                method: .get,
                url: baseURL.appending(path: "models")
            )
        )
        let catalog: ModelListEnvelope
        do {
            catalog = try JSONDecoder().decode(
                ModelListEnvelope.self,
                from: response.data
            )
        } catch {
            throw LocalModelInferenceError.invalidResponse
        }
        guard catalog.data.contains(where: { $0.id == modelID }) else {
            throw LocalModelInferenceError.selectedModelUnavailable(modelID)
        }
        return LocalModelHealth(
            modelID: modelID,
            endpointIdentity: endpointIdentity,
            isAvailable: true
        )
    }

    public func generate(
        question: String,
        context: ContextBundle
    ) async throws -> LocalModelGeneratedAnswer {
        let normalizedQuestion = question.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedQuestion.isEmpty else {
            throw LocalModelInferenceError.blankQuestion
        }
        guard !context.passages.isEmpty else {
            throw LocalModelInferenceError.missingContext
        }

        let requestBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: modelID,
                messages: [
                    ChatMessage(
                        role: "system",
                        content: """
                        Answer only from the supplied local evidence. Return JSON with exactly two keys: answer (string) and passage_ids (array of cited passage IDs). Cite every passage used. If the evidence does not answer the question, return an empty answer and empty passage_ids. Never invent a passage ID.

                        \(context.serializedContext)
                        """
                    ),
                    ChatMessage(role: "user", content: normalizedQuestion),
                ],
                stream: false,
                temperature: 0
            )
        )
        let response = try await perform(
            LocalModelHTTPRequest(
                method: .post,
                url: baseURL.appending(path: "chat/completions"),
                headers: ["Content-Type": "application/json"],
                body: requestBody
            )
        )

        let envelope: ChatCompletionEnvelope
        do {
            envelope = try JSONDecoder().decode(
                ChatCompletionEnvelope.self,
                from: response.data
            )
        } catch {
            throw LocalModelInferenceError.invalidResponse
        }
        guard envelope.model == modelID else {
            throw LocalModelInferenceError.modelIdentityMismatch(
                expected: modelID,
                actual: envelope.model
            )
        }
        guard let content = envelope.choices.first?.message.content,
              let contentData = content.data(using: .utf8),
              let grounded = try? JSONDecoder().decode(
                GroundedModelOutput.self,
                from: contentData
              ) else {
            throw LocalModelInferenceError.invalidResponse
        }
        let answer = grounded.answer.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !answer.isEmpty,
              !grounded.passageIDs.isEmpty,
              Set(grounded.passageIDs).count == grounded.passageIDs.count else {
            throw LocalModelInferenceError.ungroundedResponse
        }

        let passages = Dictionary(
            uniqueKeysWithValues: context.passages.map { ($0.passageID, $0) }
        )
        var citations: [Citation] = []
        for passageID in grounded.passageIDs {
            guard let passage = passages[passageID] else {
                throw LocalModelInferenceError.ungroundedResponse
            }
            citations.append(
                Citation(
                    sourceID: passage.sourceID,
                    passageID: passage.passageID,
                    quote: String(passage.text.prefix(500))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        guard citations.allSatisfy({ !$0.quote.isEmpty }) else {
            throw LocalModelInferenceError.ungroundedResponse
        }

        return LocalModelGeneratedAnswer(
            text: answer,
            modelID: modelID,
            endpointIdentity: endpointIdentity,
            citations: citations,
            retention: .ephemeral
        )
    }

    private func perform(
        _ request: LocalModelHTTPRequest
    ) async throws -> LocalModelHTTPResponse {
        let response: LocalModelHTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as LocalModelInferenceError {
            throw error
        } catch {
            throw LocalModelInferenceError.transportUnavailable
        }
        guard (200..<300).contains(response.statusCode) else {
            throw LocalModelInferenceError.httpStatus(response.statusCode)
        }
        return response
    }
}

private struct ModelListEnvelope: Decodable {
    let data: [ModelListItem]
}

private struct ModelListItem: Decodable {
    let id: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool
    let temperature: Int
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionEnvelope: Decodable {
    let model: String
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatMessage
}

private struct GroundedModelOutput: Decodable {
    let answer: String
    let passageIDs: [String]

    enum CodingKeys: String, CodingKey {
        case answer
        case passageIDs = "passage_ids"
    }
}
