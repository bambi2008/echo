import Foundation
#if canImport(Security)
import Security
#endif

public protocol AIAPIKeyStore: Sendable {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

#if canImport(Security)
/// Keychain-backed API key storage for the iOS and macOS application targets.
public struct KeychainAPIKeyStore: AIAPIKeyStore, Sendable {
    public let service: String
    public let account: String

    public init(
        service: String = "com.echo.ai",
        account: String = "deepseek_api_key"
    ) {
        self.service = service
        self.account = account
    }

    public func readAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { throw AIKeyStoreError.keychain(status) }
        return value
    }

    public func saveAPIKey(_ apiKey: String) throws {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AIKeyStoreError.emptyAPIKey }
        let data = Data(value.utf8)
        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecSuccess { return }
        if status != errSecItemNotFound { throw AIKeyStoreError.keychain(status) }

        var item = baseQuery
        item[kSecValueData as String] = data
        #if os(iOS)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw AIKeyStoreError.keychain(addStatus) }
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIKeyStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
#endif

public enum AIKeyStoreError: Error, Equatable, Sendable {
    case emptyAPIKey
    case keychain(Int32)
}

extension AIKeyStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey: "API key cannot be empty"
        case .keychain(let status): "Keychain operation failed with status \(status)"
        }
    }
}
