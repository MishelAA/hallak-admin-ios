import Foundation
import Security

/// Saves the login (site, username, Application Password) in the iPhone Keychain only:
/// never in UserDefaults, files or logs. Readable after first unlock, on this device only.
struct Keychain {
    let service: String

    init(service: String = "online.hallak.admin.login") { self.service = service }

    enum Key: String, CaseIterable { case site, username, password }

    func set(_ value: String, for key: Key) throws {
        let query = baseQuery(key)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add.merge(attributes) { $1 }
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func get(_ key: Key) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ key: Key) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    func removeAll() { Key.allCases.forEach(remove) }

    // MARK: Credentials

    func save(_ c: Credentials) throws {
        try set(c.site.absoluteString, for: .site)
        try set(c.username, for: .username)
        try set(c.password, for: .password)
    }

    func loadCredentials() -> Credentials? {
        guard let s = get(.site), let site = URL(string: s), site.scheme == "https",
              let u = get(.username), let p = get(.password) else { return nil }
        return Credentials(site: site, username: u, password: p)
    }

    private func baseQuery(_ key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}

struct KeychainError: Error, Equatable { let status: OSStatus }
