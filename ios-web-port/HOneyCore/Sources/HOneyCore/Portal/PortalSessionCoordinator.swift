// The device-side school-portal session (Access only). Guarantees, from the
// connector contract the backend also implements:
//   - at most one login/re-login in flight (single-flight);
//   - safe reads replay once after a successful re-login;
//   - non-idempotent operations (gate open) are NEVER auto-replayed;
//   - offline/5xx/timeout preserve the session and the saved login —
//     they are not proof of a bad password;
//   - credentialsRejected purges session + saved login and asks the student;
//   - a near-expiry token is renewed proactively; a still-valid one is reused
//     when renewal is impossible (offline) until a real 401.
//
// The coordinator never logs the token and never hands it to a View.

import Foundation

public protocol PortalSessionVault: Sendable {
    func loadSession() throws -> PortalSession?
    func saveSession(_ session: PortalSession) throws
    func deleteSession() throws
}

public protocol SchoolCredentialVault: Sendable {
    /// Never triggers an interactive prompt (no biometric binding on this path).
    func loadCredentials() throws -> PortalCredentials?
    func saveCredentials(_ credentials: PortalCredentials) throws
    func deleteCredentials() throws
}

public enum PortalSessionState: Sendable, Equatable {
    case restoring
    case authenticated(expiresAt: Date, studentId: String)
    case temporarilyUnavailable
    case noCredentials
    case userActionRequired(PortalUserActionReason)
    case incompatible
}

public enum ReplayPolicy: Sendable {
    case safeRead
    case nonIdempotent
}

public actor PortalSessionCoordinator {
    private let api: PortalAuthAPI
    private let sessions: PortalSessionVault
    private let credentials: SchoolCredentialVault
    private let safetyWindow: TimeInterval
    private let now: @Sendable () -> Date

    private var session: PortalSession?
    private var reauth: Task<PortalSession, Error>?
    private var epoch = 0
    private(set) var loginCalls = 0
    public private(set) var state: PortalSessionState = .restoring
    /// Called with a freshly minted token so HOney's backend can reuse it
    /// (POST /api/portal/token) instead of logging in a second time.
    private var onFreshToken: (@Sendable (String) async -> Void)?

    public init(
        api: PortalAuthAPI,
        sessions: PortalSessionVault,
        credentials: SchoolCredentialVault,
        safetyWindow: TimeInterval = 5 * 60,
        now: @escaping @Sendable () -> Date = { HOneyClock.now() }
    ) {
        self.api = api
        self.sessions = sessions
        self.credentials = credentials
        self.safetyWindow = safetyWindow
        self.now = now
    }

    public func setFreshTokenHandler(_ handler: (@Sendable (String) async -> Void)?) {
        onFreshToken = handler
    }

    public func currentState() -> PortalSessionState { state }

    /// Freshly entered school login (Login screen / Settings): kept on this
    /// device so the connector can silently re-login later.
    public func authorize(_ creds: PortalCredentials) throws {
        epoch += 1
        reauth?.cancel()
        reauth = nil
        try credentials.saveCredentials(creds)
        session = nil
        try? sessions.deleteSession()
        state = .restoring
    }

    /// "Stay connected" turned off: forget the login and the session.
    public func forgetEverything() async {
        epoch += 1
        reauth?.cancel()
        reauth = nil
        let token = session?.token
        session = nil
        try? sessions.deleteSession()
        try? credentials.deleteCredentials()
        state = .noCredentials
        if let token { await api.logout(token: token) }
    }

    /// Restore on startup: saved token → authenticated; else silent login; else noCredentials.
    @discardableResult
    public func restore() async -> PortalSessionState {
        state = .restoring
        let saved = try? sessions.loadSession()
        if let saved, isFresh(saved) {
            session = saved
            state = .authenticated(expiresAt: saved.expiresAt, studentId: saved.studentId)
            return state
        }
        session = saved
        do {
            let renewed = try await reauthenticateSingleFlight()
            state = .authenticated(expiresAt: renewed.expiresAt, studentId: renewed.studentId)
        } catch let error as PortalError {
            state = Self.stateAfterFailure(error, current: state)
        } catch {
            state = .temporarilyUnavailable
        }
        return state
    }

    /// Run an authenticated operation. On sessionExpired: drop the token, do
    /// one single-flight re-login, then replay ONLY if the operation is a safe
    /// read. Non-idempotent operations surface the expiry instead.
    public func withAuthentication<T: Sendable>(
        replay: ReplayPolicy,
        _ operation: @Sendable (String) async throws -> T
    ) async throws -> T {
        let current = try await currentOrRecoveredSession()
        do {
            return try await operation(current.token)
        } catch PortalError.sessionExpired {
            let fresh: PortalSession
            if let live = session, live.token != current.token {
                // A late 401: another caller already repaired the session.
                fresh = live
            } else {
                session = nil
                try? sessions.deleteSession()
                fresh = try await reauthenticateSingleFlight()
            }
            guard replay == .safeRead else { throw PortalError.sessionExpired }
            return try await operation(fresh.token)
        }
    }

    /// Freshen the session before a gate open / permit mutation. The mutation
    /// itself must NOT be wrapped in automatic replay.
    public func prepareForSensitiveAction() async throws -> String {
        try await currentOrRecoveredSession().token
    }

    // MARK: Internals

    private func isFresh(_ s: PortalSession) -> Bool {
        s.expiresAt.timeIntervalSince(now()) > safetyWindow
    }

    private func currentOrRecoveredSession() async throws -> PortalSession {
        if let session, isFresh(session) { return session }
        if session == nil, let saved = try? sessions.loadSession() {
            session = saved
            if isFresh(saved) {
                state = .authenticated(expiresAt: saved.expiresAt, studentId: saved.studentId)
                return saved
            }
        }
        // Inside the safety window (or beyond): renew proactively, but keep a
        // still-clock-valid token when renewal is impossible right now.
        let stillValid = session.map { $0.expiresAt > now() } ?? false
        do {
            return try await reauthenticateSingleFlight()
        } catch let error as PortalError {
            if stillValid, let session {
                switch error {
                case .noCredentials, .networkUnavailable, .serverUnavailable, .timeout:
                    return session
                default: break
                }
            }
            throw error
        }
    }

    private func reauthenticateSingleFlight() async throws -> PortalSession {
        if let reauth { return try await reauth.value }
        let task = Task<PortalSession, Error> { try await self.performReauthentication() }
        reauth = task
        defer { reauth = nil }
        return try await task.value
    }

    private func performReauthentication() async throws -> PortalSession {
        let startEpoch = epoch
        guard let creds = try? credentials.loadCredentials() else {
            state = .noCredentials
            throw PortalError.noCredentials
        }
        do {
            loginCalls += 1
            let token = try await api.login(creds)
            let identity = try await api.identity(token: token)
            let renewed = PortalSession(token: token, expiresAt: identity.tokenExpiresAt, studentId: identity.studentId)
            guard epoch == startEpoch else {
                // The student signed out / forgot the login meanwhile.
                await api.logout(token: token)
                throw PortalError.sessionExpired
            }
            try? sessions.saveSession(renewed)
            session = renewed
            state = .authenticated(expiresAt: renewed.expiresAt, studentId: renewed.studentId)
            if let onFreshToken { await onFreshToken(token) }
            return renewed
        } catch let error as PortalError {
            guard epoch == startEpoch else { throw PortalError.sessionExpired }
            switch error {
            case .credentialsRejected:
                // The stored password is stale: purge so we never hammer the portal.
                try? sessions.deleteSession()
                try? credentials.deleteCredentials()
                session = nil
                state = .userActionRequired(.passwordChanged)
            case .userActionRequired(let reason):
                state = .userActionRequired(reason)
            case .schemaIncompatible:
                state = .incompatible
            default:
                // Network/5xx/timeout: PRESERVE credentials.
                state = .temporarilyUnavailable
            }
            throw error
        }
    }

    static func stateAfterFailure(_ error: PortalError, current: PortalSessionState) -> PortalSessionState {
        switch error {
        case .credentialsRejected: return .userActionRequired(.passwordChanged)
        case .userActionRequired(let reason): return .userActionRequired(reason)
        case .schemaIncompatible: return .incompatible
        case .noCredentials, .sessionExpired: return .noCredentials
        default: return .temporarilyUnavailable
        }
    }
}

/// Keychain-shaped vaults on top of any SecretStore.
public final class SecretPortalVault: PortalSessionVault, SchoolCredentialVault, @unchecked Sendable {
    private let store: SecretStore
    private let sessionKey: String
    private let credentialsKey: String

    public init(store: SecretStore, sessionKey: String = "honey.portal.session", credentialsKey: String = "honey.school.credentials") {
        self.store = store
        self.sessionKey = sessionKey
        self.credentialsKey = credentialsKey
    }

    public func loadSession() throws -> PortalSession? {
        guard let data = try store.read(sessionKey) else { return nil }
        return try? JSONDecoder().decode(PortalSession.self, from: data)
    }

    public func saveSession(_ session: PortalSession) throws {
        try store.write(sessionKey, try JSONEncoder().encode(session))
    }

    public func deleteSession() throws { try store.delete(sessionKey) }

    public func loadCredentials() throws -> PortalCredentials? {
        guard let data = try store.read(credentialsKey) else { return nil }
        let creds = try? JSONDecoder().decode(PortalCredentials.self, from: data)
        return (creds?.username.isEmpty == false && creds?.password.isEmpty == false) ? creds : nil
    }

    public func saveCredentials(_ credentials: PortalCredentials) throws {
        try store.write(credentialsKey, try JSONEncoder().encode(credentials))
    }

    public func deleteCredentials() throws { try store.delete(credentialsKey) }

    public var hasCredentials: Bool { (try? loadCredentials()) != nil }
}
