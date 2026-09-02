// The Keychain behind every secret (spec §5): HOney session, school login,
// portal session, ownership keys. Generic-password items, this device only,
// available after first unlock (silent reconnect must work in the
// background without a biometric prompt), never synchronised to iCloud —
// a deliberate choice (§22.2): control keys and school passwords do not
// travel between devices on their own; the transfer bundle does that.

import Foundation
import Security
import HOneyCore

final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    init(service: String) {
        self.service = service
    }

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    func read(_ key: String) throws -> Data? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        switch status {
        case errSecSuccess: return out as? Data
        case errSecItemNotFound: return nil
        case errSecInteractionNotAllowed, errSecNotAvailable: throw SecretStoreError.unavailable
        default: throw SecretStoreError.unavailable
        }
    }

    func write(_ key: String, _ data: Data) throws {
        var attributes = query(key)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(query(key) as CFDictionary, [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ] as CFDictionary)
        }
        guard status == errSecSuccess else { throw SecretStoreError.writeFailed }
    }

    func delete(_ key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError.writeFailed }
    }

    func keys(withPrefix prefix: String) throws -> [String] {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let items = out as? [[String: Any]] else { throw SecretStoreError.unavailable }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }.filter { $0.hasPrefix(prefix) }.sorted()
    }
}
