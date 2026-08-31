//
//  KeychainCredentialVault.swift
//  HOney — Keychain-backed PortalCredentialVault (Band 2/4, no SwiftUI).
//
//  Credentials + session use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly and
//  are NOT biometric-bound: silent background recovery must never prompt Face ID.
//  (Face ID may still gate a settings screen that reveals/edits credentials — that
//  is a separate, UI-level concern, not this storage path.)
//

import Foundation

final class KeychainCredentialVault: PortalCredentialVault, @unchecked Sendable {
    private let keychain: Keychain
    private let credentialsAccount = "portal.credentials"
    private let sessionAccount = "portal.session"

    init(keychain: Keychain = Keychain(service: "com.gaelisus.honey.portal")) {
        self.keychain = keychain
    }

    func loadSession() throws -> PortalSession? {
        try keychain.codable(PortalSession.self, for: sessionAccount)
    }

    func saveSession(_ session: PortalSession) throws {
        try keychain.setCodable(session, for: sessionAccount)
    }

    func deleteSession() throws {
        try keychain.remove(sessionAccount)
    }

    func loadAuthorizedCredentialsSilently() throws -> PortalCredentials? {
        try keychain.codable(PortalCredentials.self, for: credentialsAccount)
    }

    func saveCredentials(_ credentials: PortalCredentials) throws {
        try keychain.setCodable(credentials, for: credentialsAccount)
    }

    func deleteCredentials() throws {
        try keychain.remove(credentialsAccount)
    }
}
