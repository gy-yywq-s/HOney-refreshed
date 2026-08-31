//
//  TestDoubles.swift
//  HOneyTests — mocks and helpers for the pure-logic tests.
//

import Foundation
@testable import HOney

/// Simple async call counter.
actor Counter {
    private(set) var value = 0
    @discardableResult
    func increment() -> Int { value += 1; return value }
}

/// Configurable mock portal auth API. Tracks login invocations.
actor MockPortalAuthAPI: PortalAuthAPI {
    private(set) var loginCount = 0
    var loginDelayNanos: UInt64 = 0
    var loginResult: Result<String, Error> = .success("token-1")
    var identityStudentID = 88
    var identityExpiry = Date().addingTimeInterval(3600)

    func configure(loginResult: Result<String, Error>? = nil,
                   loginDelayNanos: UInt64? = nil,
                   identityExpiry: Date? = nil) {
        if let loginResult { self.loginResult = loginResult }
        if let loginDelayNanos { self.loginDelayNanos = loginDelayNanos }
        if let identityExpiry { self.identityExpiry = identityExpiry }
    }

    func login(_ credentials: PortalCredentials) async throws -> String {
        loginCount += 1
        if loginDelayNanos > 0 { try? await Task.sleep(nanoseconds: loginDelayNanos) }
        return try loginResult.get()
    }

    func identity(token: String) async throws -> (studentID: Int, expiresAt: Date) {
        (identityStudentID, identityExpiry)
    }
}

/// In-memory PortalCredentialVault. Records whether credentials were deleted.
final class InMemoryVault: PortalCredentialVault, @unchecked Sendable {
    var session: PortalSession?
    var credentials: PortalCredentials?
    private(set) var deleteCredentialsCalled = false

    init(session: PortalSession? = nil, credentials: PortalCredentials? = nil) {
        self.session = session
        self.credentials = credentials
    }

    func loadSession() throws -> PortalSession? { session }
    func saveSession(_ session: PortalSession) throws { self.session = session }
    func deleteSession() throws { session = nil }
    func loadAuthorizedCredentialsSilently() throws -> PortalCredentials? { credentials }
    func saveCredentials(_ credentials: PortalCredentials) throws { self.credentials = credentials }
    func deleteCredentials() throws { credentials = nil; deleteCredentialsCalled = true }
}
