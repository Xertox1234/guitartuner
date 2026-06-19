import Foundation
import Security

/// Abstraction over Keychain read/write/delete so tests can inject an
/// in-memory fake. Headless CI runs unsigned, where a real SecItem call risks
/// errSecMissingEntitlement or an interactive prompt — the fake keeps the
/// delete-purge test deterministic. `Sendable` because `LumaAPI.keychain` is a
/// `nonisolated let` read synchronously from `AccountModel.init` (@MainActor)
/// under Swift 6 strict concurrency.
protocol KeychainStoring: Sendable {
    @discardableResult func write(key: String, value: String) -> Bool
    func read(key: String) -> String?
    func delete(key: String)
}

/// Thread-safe Keychain read/write for a single service namespace.
struct KeychainStore: KeychainStoring {
    let service: String

    @discardableResult
    func write(key: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        // ...ThisDeviceOnly: same availability (background token refresh still
        // works) but the credential is excluded from encrypted-backup restore,
        // so it never migrates to another device. See docs/rules/security.md.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
