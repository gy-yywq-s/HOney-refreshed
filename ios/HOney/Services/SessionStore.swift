//
//  SessionStore.swift
//  HOney — HOney session (access/refresh tokens) persistence in the Keychain.
//  Band 2/4, no SwiftUI.
//

import Foundation

actor SessionStore {
    private let keychain: Keychain
    private let persistenceEnabled: Bool
    private let account = "honey.session"
    private var cached: HOneySession?

    init(
        keychain: Keychain = Keychain(service: "com.gaelisus.honey.session"),
        persistenceEnabled: Bool = true
    ) {
        self.keychain = keychain
        self.persistenceEnabled = persistenceEnabled
    }

    func current() -> HOneySession? {
        if let cached { return cached }
        guard persistenceEnabled else { return nil }
        cached = try? keychain.codable(HOneySession.self, for: account)
        return cached
    }

    func save(_ session: HOneySession) throws {
        if persistenceEnabled { try keychain.setCodable(session, for: account) }
        cached = session
    }

    func clear() throws {
        cached = nil
        if persistenceEnabled { try keychain.remove(account) }
    }
}
