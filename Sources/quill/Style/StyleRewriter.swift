import Foundation

enum StyleTone: String, CaseIterable, Identifiable {
    case cleanUp = "Clean Up"
    case formal = "Formal"
    case casual = "Casual"
    case concise = "Concise"

    var id: String { rawValue }

    var instruction: String {
        switch self {
        case .cleanUp:
            return "Fix grammar, punctuation, and remove filler words. Keep the meaning and tone exactly the same. Don't add anything new."
        case .formal:
            return "Rewrite in a more formal, professional tone. Fix grammar and punctuation. Keep the same meaning."
        case .casual:
            return "Rewrite in a relaxed, casual tone, like texting a friend. Fix grammar. Keep the same meaning."
        case .concise:
            return "Rewrite to be shorter and more direct, cutting unnecessary words. Keep the same meaning."
        }
    }
}

enum StyleRewriteError: Error, LocalizedError {
    case noAPIKey
    case network(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key set for this provider."
        case .network(let msg): return msg
        case .badResponse: return "Unexpected response from the provider."
        }
    }
}

/// The only code path in Quill that sends dictation content over the
/// network — and only when the user has explicitly added their own API
/// key here AND pressed Rewrite. Nothing here runs automatically, and
/// "Clean Up" (StyleView's default tone) never reaches this file at all —
/// it's handled entirely locally by TranscriptSanitizer.cleanUpFillers.
enum StyleRewriter {
    static func rewrite(_ text: String, tone: StyleTone, provider: StyleProvider) async throws -> String {
        guard let key = APIKeyStore.key(for: provider), !key.isEmpty else {
            throw StyleRewriteError.noAPIKey
        }
        switch provider {
        case .openAI: return try await rewriteOpenAI(text, tone: tone, key: key)
        case .anthropic: return try await rewriteAnthropic(text, tone: tone, key: key)
        }
    }

    private static func rewriteOpenAI(_ text: String, tone: StyleTone, key: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You rewrite dictated text. \(tone.instruction) Reply with only the rewritten text, nothing else — no preamble, no quotes."],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw StyleRewriteError.badResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func rewriteAnthropic(_ text: String, tone: StyleTone, key: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": "You rewrite dictated text. \(tone.instruction) Reply with only the rewritten text, nothing else — no preamble, no quotes.",
            "messages": [
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data: data)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let resultText = content.first?["text"] as? String
        else { throw StyleRewriteError.badResponse }
        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let snippet = body.count > 200 ? String(body.prefix(200)) + "…" : body
            throw StyleRewriteError.network("HTTP \(http.statusCode): \(snippet)")
        }
    }
}
