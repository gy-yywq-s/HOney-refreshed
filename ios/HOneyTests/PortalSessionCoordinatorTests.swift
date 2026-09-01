//
//  PortalSessionCoordinatorTests.swift
//  HOneyTests — single-flight re-login, replay policy, expiry, credential safety.
//

import XCTest
@testable import HOney

private actor CredentialEchoPortalAPI: PortalAuthAPI {
    private(set) var usernames: [String] = []

    func login(_ credentials: PortalCredentials) async throws -> String {
        usernames.append(credentials.username)
        if credentials.username == "old" {
            try? await Task.sleep(for: .milliseconds(120))
        } else {
            try await Task.sleep(for: .milliseconds(10))
        }
        return "token-" + credentials.username
    }

    func identity(token: String) async throws -> (studentID: Int, expiresAt: Date) {
        (88, Date().addingTimeInterval(3600))
    }
}

final class PortalSessionCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        api: MockPortalAuthAPI,
        vault: InMemoryVault,
        safetyWindow: TimeInterval = 300
    ) -> PortalSessionCoordinator {
        PortalSessionCoordinator(api: api, vault: vault, safetyWindow: safetyWindow)
    }

    func testSingleFlightReloginSharesOneLogin() async throws {
        let api = MockPortalAuthAPI()
        await api.configure(loginDelayNanos: 80_000_000) // 80ms so callers overlap
        let vault = InMemoryVault(credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)

        // Fire several concurrent authenticated reads before any session exists.
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    (try? await coordinator.withAuthentication(replay: .safeRead) { token in token }) ?? ""
                }
            }
            for await _ in group {}
        }

        let count = await api.loginCount
        XCTAssertEqual(count, 1, "Concurrent callers must share a single login task")
    }

    func testSafeReadReplaysAfterUnauthorized() async throws {
        let api = MockPortalAuthAPI()
        let vault = InMemoryVault(credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)
        let calls = Counter()

        let result: String = try await coordinator.withAuthentication(replay: .safeRead) { token in
            let n = await calls.increment()
            if n == 1 { throw PortalSessionError.unauthorized }
            return "ok:\(token)"
        }

        XCTAssertTrue(result.hasPrefix("ok:"))
        let n = await calls.value
        XCTAssertEqual(n, 2, "safeRead must retry the operation once after re-login")
    }

    func testNonIdempotentNeverReplayed() async throws {
        let api = MockPortalAuthAPI()
        let vault = InMemoryVault(credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)
        let calls = Counter()

        do {
            _ = try await coordinator.withAuthentication(replay: .nonIdempotent) { _ in
                _ = await calls.increment()
                throw PortalSessionError.unauthorized
            }
            XCTFail("Expected unauthorized to propagate")
        } catch {
            XCTAssertEqual(error as? PortalSessionError, .unauthorized)
        }

        let n = await calls.value
        XCTAssertEqual(n, 1, "Non-idempotent operations must not be auto-replayed")
    }

    func testValidTokenIsReusedWithoutRelogin() async throws {
        let api = MockPortalAuthAPI()
        let session = PortalSession(token: "valid", expiresAt: Date().addingTimeInterval(3600), studentID: 88)
        let vault = InMemoryVault(session: session, credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)

        await coordinator.restore()

        let count = await api.loginCount
        XCTAssertEqual(count, 0, "A clock-valid token outside the safety window is reused")
        let state = await coordinator.currentState()
        XCTAssertEqual(state, .authenticated(session))
    }

    func testNearExpiryTriggersProactiveRelogin() async throws {
        let api = MockPortalAuthAPI()
        let session = PortalSession(token: "old", expiresAt: Date().addingTimeInterval(60), studentID: 88)
        let vault = InMemoryVault(session: session, credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault, safetyWindow: 300)

        await coordinator.restore()

        let count = await api.loginCount
        XCTAssertEqual(count, 1, "A token inside the safety window is refreshed")
    }

    func testAvailabilityFailurePreservesCredentials() async throws {
        let api = MockPortalAuthAPI()
        await api.configure(loginResult: .failure(PortalSessionError.serverUnavailable(503)))
        let vault = InMemoryVault(credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)

        await coordinator.restore()

        XCTAssertFalse(vault.deleteCredentialsCalled, "5xx must not delete credentials")
        XCTAssertNotNil(vault.credentials)
        let state = await coordinator.currentState()
        XCTAssertEqual(state, .temporarilyUnavailable)
    }

    func testCredentialsRejectedPurgesAndRequiresUser() async throws {
        let api = MockPortalAuthAPI()
        await api.configure(loginResult: .failure(PortalSessionError.credentialsRejected))
        let vault = InMemoryVault(credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)

        await coordinator.restore()

        XCTAssertTrue(vault.deleteCredentialsCalled, "Rejected credentials must be purged")
        XCTAssertNil(vault.credentials)
        let state = await coordinator.currentState()
        XCTAssertEqual(state, .userActionRequired)
    }

    func testExplicitCredentialClearRemovesSessionAndCredentials() async throws {
        let api = MockPortalAuthAPI()
        let session = PortalSession(token: "valid", expiresAt: Date().addingTimeInterval(3600), studentID: 88)
        let vault = InMemoryVault(session: session, credentials: .init(username: "u", password: "p"))
        let coordinator = makeCoordinator(api: api, vault: vault)

        try await coordinator.clearSavedCredentials()

        XCTAssertNil(vault.session)
        XCTAssertNil(vault.credentials)
        XCTAssertTrue(vault.deleteCredentialsCalled)
        let state = await coordinator.currentState()
        XCTAssertEqual(state, .noCredentials)
    }

    func testReplacingCredentialsInvalidatesAValidOldSessionBeforeVerification() async throws {
        let api = MockPortalAuthAPI()
        let oldSession = PortalSession(token: "old-valid", expiresAt: Date().addingTimeInterval(3600), studentID: 88)
        let vault = InMemoryVault(session: oldSession, credentials: .init(username: "old", password: "old"))
        let coordinator = makeCoordinator(api: api, vault: vault)
        await coordinator.restore()
        let initialLoginCount = await api.loginCount
        XCTAssertEqual(initialLoginCount, 0)

        try await coordinator.authorizeCredentials(.init(username: "new", password: "new"))
        await coordinator.restore()

        XCTAssertEqual(vault.credentials, .init(username: "new", password: "new"))
        let replacementLoginCount = await api.loginCount
        XCTAssertEqual(replacementLoginCount, 1, "The replacement credentials must be checked instead of reusing the old session")
    }

    func testLateOldLoginCannotOverwriteTheReplacementSession() async throws {
        let api = CredentialEchoPortalAPI()
        let vault = InMemoryVault(credentials: .init(username: "old", password: "old"))
        let coordinator = PortalSessionCoordinator(api: api, vault: vault, safetyWindow: 300)

        let oldAttempt = Task { try? await coordinator.freshTokenForWebBridge() }
        try await Task.sleep(for: .milliseconds(20))
        try await coordinator.authorizeCredentials(.init(username: "new", password: "new"))
        await coordinator.restore()
        _ = await oldAttempt.value

        XCTAssertEqual(vault.session?.token, "token-new")
        let state = await coordinator.currentState()
        guard case .authenticated(let session) = state else {
            return XCTFail("Expected the replacement session to remain authenticated")
        }
        XCTAssertEqual(session.token, "token-new")
    }
}
