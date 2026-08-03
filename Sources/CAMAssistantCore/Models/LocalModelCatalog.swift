import Foundation

/// Lists models from an OpenAI-compatible `/models` endpoint (LM Studio, Ollama,
/// or OpenRouter with a bearer token).
public enum LocalModelCatalog: Sendable {
    public static let lmStudioDefaultEndpoint = "http://127.0.0.1:1234/v1"
    public static let ollamaDefaultEndpoint = "http://127.0.0.1:11434/v1"
    public static let openRouterDefaultEndpoint = "https://openrouter.ai/api/v1"

    public static func listModelIDs(
        endpoint: String,
        authorizationBearer: String? = nil,
        transport: any LocalModelTransport = URLSessionLocalModelTransport()
    ) async throws -> [String] {
        let normalized = endpoint.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard let base = URL(string: normalized) else {
            throw LocalModelInferenceError.invalidAssignment
        }
        var headers: [String: String] = [:]
        if let authorizationBearer,
           !authorizationBearer.trimmingCharacters(in: .whitespacesAndNewlines)
               .isEmpty {
            headers["Authorization"] = "Bearer \(authorizationBearer)"
            headers["HTTP-Referer"] = "https://github.com/deesatzed/cam_wiki"
            headers["X-Title"] = "CAM Assistant"
        }
        let response = try await transport.send(
            LocalModelHTTPRequest(
                method: .get,
                url: base.appending(path: "models"),
                headers: headers
            )
        )
        guard (200..<300).contains(response.statusCode) else {
            throw LocalModelInferenceError.httpStatus(response.statusCode)
        }
        let catalog: ModelListEnvelope
        do {
            catalog = try JSONDecoder().decode(
                ModelListEnvelope.self,
                from: response.data
            )
        } catch {
            throw LocalModelInferenceError.invalidResponse
        }
        return catalog.data.map(\.id).sorted()
    }
}

private struct ModelListEnvelope: Decodable {
    let data: [ModelListItem]
}

private struct ModelListItem: Decodable {
    let id: String
}
