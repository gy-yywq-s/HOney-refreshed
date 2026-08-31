//
//  OwnershipKeyStore.swift
//  HOney — device-only storage of per-experience ownership keys (Band 2/4).
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

    func keys() -> [String] {
        (try? keychain.codable([String].self, for: account)) ?? []
    }

    func add(_ key: String) {
        var all = keys()
        guard !all.contains(key) else { return }
        all.append(key)
        try? keychain.setCodable(all, for: account)
    }

    func remove(_ key: String) {
        let all = keys().filter { $0 != key }
        try? keychain.setCodable(all, for: account)
    }

    func clear() {
        try? keychain.remove(account)
    }
}
