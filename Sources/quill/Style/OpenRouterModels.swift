import Foundation

struct OpenRouterModelInfo: Identifiable, Decodable {
    let id: String
    let name: String?
}

private struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModelInfo]
}

/// Fetches OpenRouter's public model catalog for Enhancement Engine's
/// model picker (OpenRouter only — its whole point is access to hundreds
/// of models through one key, unlike OpenAI/Anthropic/Google's single
/// fixed default in `StyleRewriter.modelName`). No API key required for
/// this specific endpoint, it's just a public listing of what's
/// available; the user's own key is still what the actual rewrite call
/// needs.
enum OpenRouterModels {
    static func fetch() async throws -> [OpenRouterModelInfo] {
        let (data, response) = try await URLSession.shared.data(
            from: URL(string: "https://openrouter.ai/api/v1/models")!
        )
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return decoded.data.sorted { $0.id < $1.id }
    }
}
