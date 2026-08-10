import Foundation
import Security

enum StyleProvider: String, CaseIterable, Identifiable, Codable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    var id: String { rawValue }
}

/// Stores the user's own OpenAI/Anthropic API key in the macOS Keychain —
/// deliberately NOT UserDefaults and NOT a plain file. It's a credential,
/// not a preference: never written to disk in plain text, never committed
/// to git (there's no file to commit — Keychain items live outside the
/// repo entirely), and read only by StyleRewriter at the moment a rewrite
/// is requested.
enum APIKeyStore {
    private static let service = "com.tamiliniyan.quill.apikey"

    static func key(for provider: StyleProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setKey(_ key: String, for provider: StyleProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = Data(key.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func clearKey(for provider: StyleProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func hasKey(for provider: StyleProvider) -> Bool {
        (key(for: provider) ?? "").isEmpty == false
    }
}
