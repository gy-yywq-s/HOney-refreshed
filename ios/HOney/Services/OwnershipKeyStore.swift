//
//  OwnershipKeyStore.swift
//  HOney — device-only store mapping experienceId → ownership key (Band 2/4).
//
//  The server keeps no author identity; these keys are the only way a user can
//  see, revoke or re-confirm their own submissions. Settings warns they are
//  device-only (losing the device loses the ability to manage past posts).
//

import Foundation

actor OwnershipKeyStore {
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
