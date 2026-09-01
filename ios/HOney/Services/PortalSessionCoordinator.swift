//
//  PortalSessionCoordinator.swift
//  HOney — the direct-to-school portal session actor (Band 2/4, no SwiftUI).
//
//  Re-implemented from the portal-connector BLUEPRINT contract. Guarantees:
//    - single-flight re-login (concurrent callers share one login task);
//    - safe-read replay only (safeRead operations retried once after re-login);
//    - non-idempotent operations (openDoor) are NEVER auto-replayed;
//    - availability failures (offline/timeout/5xx/transient parse) preserve the
//      session and credentials — they are not proof of a bad password;
//    - credentialsRejected purges session + credentials and requires user action;
//    - a near-expiry token is refreshed proactively (safety window), while a
//      still-clock-valid token is reused.
//

import Foundation

struct PortalSession: Codable, Sendable, Equatable {
    let token: String
    let expiresAt: Date
    let studentID: Int
}

struct PortalCredentials: Codable, Sendable, Equatable {
    let username: String
    let password: String
}

enum ReplayPolicy: Sendable {
    case safeRead
    case nonIdempotent
}

enum PortalSessionState: Sendable, Equatable {
    case restoring
    case authenticated(PortalSession)
    case temporarilyUnavailable
    case noCredentials
    case userActionRequired
    case incompatible
}

enum PortalSessionError: Error, Sendable, Equatable {
    case networkUnavailable
    case serverUnavailable(Int)
    case unauthorized
    case credentialsRejected
    case interactiveChallenge
    case keychainUnavailable
    case incompatibleResponse
    case mutationOutcomeUnknown
}

protocol PortalAuthAPI: Sendable {
    func login(_ credentials: PortalCredentials) async throws -> String
    func identity(token: String) async throws -> (studentID: Int, expiresAt: Date)
}

protocol PortalCredentialVault: Sendable {
    func loadSession() throws -> PortalSession?
    func saveSession(_ session: PortalSession) throws
    func deleteSession() throws
    func loadAuthorizedCredentialsSilently() throws -> PortalCredentials?
    func saveCredentials(_ credentials: PortalCredentials) throws
    func deleteCredentials() throws
}

actor PortalSessionCoordinator {
    private let api: any PortalAuthAPI
    private let vault: any PortalCredentialVault
    private let safetyWindow: TimeInterval

    private var session: PortalSession?
    private var loginTask: Task<PortalSession, Error>?
    private(set) var state: PortalSessionState = .restoring

    init(api: any PortalAuthAPI, vault: any PortalCredentialVault, safetyWindow: TimeInterval = 5 * 60) {
        self.api = api
        self.vault = vault
        self.safetyWindow = safetyWindow
    }

    /// Store freshly-entered credentials (from the HOney login screen) so the
    /// connector can silently re-login later.
    func authorizeCredentials(_ credentials: PortalCredentials) throws {
        try vault.saveCredentials(credentials)
        if state == .noCredentials || state == .userActionRequired {
            state = .restoring
        }
    }

    func restore() async {
        do {
            session = try vault.loadSession()
            if (try? vault.loadAuthorizedCredentialsSilently()) == nil, session == nil {
                state = .noCredentials
                return
            }
            _ = try await ensureFreshSession()
        } catch PortalSessionError.networkUnavailable {
            state = .temporarilyUnavailable
        } catch PortalSessionError.serverUnavailable {
            state = .temporarilyUnavailable
        } catch PortalSessionError.credentialsRejected {
            state = .userActionRequired
        } catch PortalSessionError.interactiveChallenge {
            state = .userActionRequired
        } catch PortalSessionError.keychainUnavailable {
            state = .noCredentials
        } catch PortalSessionError.incompatibleResponse {
            state = .incompatible
        } catch {
            // Retry after protected data becomes available; never erase secrets.
            state = .temporarilyUnavailable
        }
    }

    func withAuthentication<T: Sendable>(
        replay policy: ReplayPolicy,
        operation: @Sendable (String) async throws -> T
    ) async throws -> T {
        let current = try await ensureFreshSession()
        do {
            return try await operation(current.token)
        } catch PortalSessionError.unauthorized {
            try? vault.deleteSession()
            session = nil
            let renewed = try await reauthenticateSingleFlight()
            guard policy == .safeRead else {
                // Non-idempotent operations must never be auto-replayed.
                throw PortalSessionError.unauthorized
            }
            return try await operation(renewed.token)
        }
    }

    /// Call before gate-open / permit mutations. The mutation itself must NOT be
    /// wrapped in automatic replay.
    func prepareForSensitiveAction() async throws -> String {
        try await ensureFreshSession().token
    }

    func currentState() -> PortalSessionState { state }

    private func ensureFreshSession(now: Date = .now) async throws -> PortalSession {
        if let session, session.expiresAt.timeIntervalSince(now) > safetyWindow {
            state = .authenticated(session)
            return session
        }
        return try await reauthenticateSingleFlight()
    }

    private func reauthenticateSingleFlight() async throws -> PortalSession {
        if let loginTask {
            return try await loginTask.value
        }

        let api = self.api
        let vault = self.vault
        let task = Task<PortalSession, Error> {
            guard let credentials = try vault.loadAuthorizedCredentialsSilently() else {
                throw PortalSessionError.keychainUnavailable
            }
            let token = try await api.login(credentials)
            let identity = try await api.identity(token: token)
            let session = PortalSession(token: token, expiresAt: identity.expiresAt, studentID: identity.studentID)
            try vault.saveSession(session)
            return session
        }

        loginTask = task
        defer { loginTask = nil }

        do {
            let renewed = try await task.value
            session = renewed
            state = .authenticated(renewed)
            return renewed
        } catch PortalSessionError.credentialsRejected {
            try? vault.deleteSession()
            try? vault.deleteCredentials()
            session = nil
            state = .userActionRequired
            throw PortalSessionError.credentialsRejected
        } catch PortalSessionError.interactiveChallenge {
            state = .userActionRequired
            throw PortalSessionError.interactiveChallenge
        } catch PortalSessionError.keychainUnavailable {
            state = .noCredentials
            throw PortalSessionError.keychainUnavailable
        } catch PortalSessionError.incompatibleResponse {
            state = .incompatible
            throw PortalSessionError.incompatibleResponse
        } catch {
            // Preserve credentials across offline, timeout, 5xx and transient
            // parsing failures. These do not prove the password is bad.
            state = .temporarilyUnavailable
            throw error
        }
    }
}
