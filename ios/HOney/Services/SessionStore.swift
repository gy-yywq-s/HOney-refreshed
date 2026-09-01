//
//  SessionStore.swift
//  HOney — HOney session (access/refresh tokens) persistence in the Keychain.
//  Band 2/4, no SwiftUI.
//

import Foundation

actor SessionStore {
    private let keychain: Keychain
    private let account = "honey.session"
    private var cached: HOneySession?

    init(keychain: Keychain = Keychain(service: "com.gaelisus.honey.session")) {
        self.keychain = keychain
    }

    func current() -> HOneySession? {
        if let cached { return cached }
        cached = try? keychain.codable(HOneySession.self, for: account)
        return cached
    }

    func save(_ session: HOneySession) {
        cached = session
        try? keychain.setCodable(session, for: account)
    }

    func clear() throws {
        cached = nil
        try keychain.remove(account)
    }
}
