//
//  SessionStore.swift
//  HOney — Honey session (access/refresh tokens) persistence in the Keychain.
//  Band 2/4, no SwiftUI.
//

import Foundation

actor SessionStore {
    private let keychain: Keychain
    private let account = "honey.session"
    private var cached: HoneySession?

    init(keychain: Keychain = Keychain(service: "com.gaelisus.honey.session")) {
        self.keychain = keychain
    }

    func current() -> HoneySession? {
        if let cached { return cached }
        cached = try? keychain.codable(HoneySession.self, for: account)
        return cached
    }

    func save(_ session: HoneySession) {
        cached = session
        try? keychain.setCodable(session, for: account)
    }

    func clear() {
        cached = nil
        try? keychain.remove(account)
    }
}
