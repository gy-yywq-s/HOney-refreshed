//
//  Keychain.swift
//  HOney — a small generic Keychain wrapper (Band 2/4, no SwiftUI).
//
//  All items use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly so that silent
//  background recovery never triggers a Face ID / passcode prompt, and secrets
//  never leave the device (no iCloud Keychain sync).
//

import Foundation
import Security

enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
}

/// Thread-safe: the Security framework serialises access internally.
struct Keychain: Sendable {
    let service: String

    init(service: String) {
        self.service = service
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func set(_ data: Data, for account: String) throws {
        var query = baseQuery(account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func data(for account: String) throws -> Data? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func remove(_ account: String) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // Codable convenience.
    func setCodable<T: Encodable>(_ value: T, for account: String) throws {
        try set(try JSONEncoder().encode(value), for: account)
    }

    func codable<T: Decodable>(_ type: T.Type, for account: String) throws -> T? {
        guard let data = try data(for: account) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
