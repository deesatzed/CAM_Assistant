import Foundation
import Security

/// Durable OpenRouter selection (endpoint + model). API key is Keychain-only.
public struct OpenRouterSettings: Codable, Equatable, Sendable {
    public var endpoint: String
    public var modelID: String
    public var isEnabled: Bool

    public init(
        endpoint: String = LocalModelCatalog.openRouterDefaultEndpoint,
        modelID: String = "",
        isEnabled: Bool = false
    ) {
        self.endpoint = endpoint
        self.modelID = modelID
        self.isEnabled = isEnabled
    }

    public static func stateURL(applicationSupportRoot: URL) -> URL {
        applicationSupportRoot
            .appending(path: "CAMAssistant", directoryHint: .isDirectory)
            .appending(path: "openrouter-settings.json")
    }

    public static func defaultStateURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        stateURL(
            applicationSupportRoot: try LocalVaultPaths
                .applicationSupportRootURL(
                    fileManager: fileManager,
                    environment: environment
                )
        )
    }

    public static func load(from url: URL) throws -> OpenRouterSettings {
        guard fileExists(url) else { return OpenRouterSettings() }
        return try JSONDecoder().decode(
            OpenRouterSettings.self,
            from: Data(contentsOf: url)
        )
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    public static func isAllowedEndpoint(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == "openrouter.ai",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return false
        }
        return true
    }

    private static func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

public enum OpenRouterCredentialStore: Sendable {
    private static let service = "com.deesatzed.cam-assistant.openrouter"
    private static let account = "api-key"

    public static func saveAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenRouterCredentialError.emptyKey
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw OpenRouterCredentialError.keychainFailure(status)
        }
    }

    public static func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            throw OpenRouterCredentialError.keychainFailure(status)
        }
        return key
    }

    public static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OpenRouterCredentialError.keychainFailure(status)
        }
    }
}

public enum OpenRouterCredentialError: Error, Equatable {
    case emptyKey
    case keychainFailure(OSStatus)
}
