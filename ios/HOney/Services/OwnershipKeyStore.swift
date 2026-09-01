//
//  OwnershipKeyStore.swift
//  HOney — device-only store mapping experienceId → ownership key (Band 2/4).
//
//  The server keeps no author identity; these keys are the only way a user can
//  see or revoke their own submissions. Settings warns they are device-only
//  (losing the device loses the ability to manage past posts). They are the
//  user's property, not session state: sign-out never clears them.
//

import Foundation

/// Abstraction over the device ownership-key store so app-level logic (and its
/// tests) never depends on the Keychain directly. Keys survive ordinary
/// sign-out (audit §3.6); only account deletion with the explicit
/// "erase everything" choice clears them.
protocol OwnershipKeyStoring: Sendable {
    /// experienceId → ownershipKey
    func map() async -> [String: String]
    /// All ownership keys, e.g. to fetch `/api/experiences/mine`.
    func keys() async -> [String]
    func ownershipKey(for experienceId: String) async -> String?
    func add(experienceId: String, ownershipKey: String) async
    func remove(experienceId: String) async
    func clear() async
}

actor OwnershipKeyStore: OwnershipKeyStoring {
    private let keychain: Keychain
    private let account = "honey.experience.ownershipKeys"

    init(keychain: Keychain = Keychain(service: "com.gaelisus.honey.ownership")) {
        self.keychain = keychain
    }

    /// experienceId → ownershipKey
    func map() -> [String: String] {
        (try? keychain.codable([String: String].self, for: account)) ?? [:]
    }

    /// All ownership keys, e.g. to fetch `/api/experiences/mine`.
    func keys() -> [String] {
        Array(map().values)
    }

    func ownershipKey(for experienceId: String) -> String? {
        map()[experienceId]
    }

    func add(experienceId: String, ownershipKey: String) {
        var all = map()
        all[experienceId] = ownershipKey
        try? keychain.setCodable(all, for: account)
    }

    func remove(experienceId: String) {
        var all = map()
        all.removeValue(forKey: experienceId)
        try? keychain.setCodable(all, for: account)
    }

    func clear() {
        try? keychain.remove(account)
    }
}
