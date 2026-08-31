//
//  PortalSessionCoordinatorTests.swift
//  HOneyTests — single-flight re-login, replay policy, expiry, credential safety.
//

import XCTest
@testable import HOney

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
}
