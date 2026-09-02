// The device-side school-portal session (Access, Portal entry, sync
// recovery — ONE reauthentication source of truth, review 11d42e3 §3.2).
// Guarantees, from the connector contract the backend also implements:
//   - at most one login/re-login in flight (single-flight);
//   - safe reads replay once after a successful re-login;
//   - non-idempotent operations (gate open) are NEVER auto-replayed;
//   - offline/5xx/timeout preserve the session and the saved login —
//     they are not proof of a bad password;
//   - credentialsRejected purges session + saved login and asks the student;
//   - a near-expiry token is renewed proactively; a still-valid one is reused
//     when renewal is impossible (offline) until a real 401;
//   - the school identity behind every token is checked against the HOney
//     account it is bound to (§3.1.5): a mismatch never becomes a session.
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

/// The link between the HOney account and the school identity a portal
/// token must belong to.
public protocol PortalIdentityBinding: Sendable {
    /// Throws `PortalError.identityMismatch` when the identity is not the
    /// one this account is bound to; remembers the first identity seen.
    func verify(_ identity: PortalIdentity) throws
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
    private let binding: PortalIdentityBinding?
    private let safetyWindow: TimeInterval
    private let now: @Sendable () -> Date

    private var session: PortalSession?
    private var reauth: Task<PortalSession, Error>?
    private var epoch = 0
    private(set) var loginCalls = 0
    public private(set) var state: PortalSessionState = .restoring
    /// Called with a freshly minted token so HOney's backend can reuse it
    /// (POST /api/portal/token). Returns whether the hand-off succeeded.
    private var onFreshToken: (@Sendable (String) async -> Bool)?
    /// The last hand-off failed: the caller may retry `pushPendingToken`.
    public private(set) var tokenPushPending = false

    public init(
        api: PortalAuthAPI,
        sessions: PortalSessionVault,
        credentials: SchoolCredentialVault,
        binding: PortalIdentityBinding? = nil,
        safetyWindow: TimeInterval = 5 * 60,
        now: @escaping @Sendable () -> Date = { HOneyClock.now() }
    ) {
        self.api = api
        self.sessions = sessions
        self.credentials = credentials
        self.binding = binding
        self.safetyWindow = safetyWindow
        self.now = now
    }

    public func setFreshTokenHandler(_ handler: (@Sendable (String) async -> Bool)?) {
        onFreshToken = handler
    }

    public func currentState() -> PortalSessionState { state }

    /// The HOney account changed (sign-in, switch, sign-out): forget the
    /// in-memory session and any in-flight login; the vaults are already
    /// bound to the new account by the caller.
    public func accountChanged() {
        epoch += 1
        reauth?.cancel()
        reauth = nil
        session = nil
        tokenPushPending = false
        state = .restoring
    }

    /// Prove a school login against the school and the account binding
    /// without keeping anything (Reconnect / Save-login sheets).
    public func verify(_ creds: PortalCredentials) async throws {
        let token = try await api.login(creds)
        let identity = try await api.identity(token: token)
        do {
            try binding?.verify(identity)
        } catch {
            await api.logout(token: token)
            throw error
        }
    }

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

    /// "Stay connected" turned off / account deleted: forget the login and
    /// the session. Throws when the Keychain refused to delete.
    public func forgetEverything() async throws {
        epoch += 1
        reauth?.cancel()
        reauth = nil
        let token = session?.token
        session = nil
        state = .noCredentials
        var firstError: Error?
        do { try sessions.deleteSession() } catch { firstError = error }
        do { try credentials.deleteCredentials() } catch { firstError = firstError ?? error }
        if let token { await api.logout(token: token) }
        if let firstError { throw firstError }
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

    /// A currently valid token for HOney's own use (Portal entry, sync
    /// recovery): the same single-flight path, never a second login.
    public func freshToken() async throws -> String {
        try await currentOrRecoveredSession().token
    }

    /// The portal itself rejected the token HOney holds (the student signed
    /// in elsewhere and the school invalidated it) although its clock says
    /// valid: drop what is cached and log in again with the saved login.
    public func renew() async throws -> String {
        session = nil
        try? sessions.deleteSession()
        return try await reauthenticateSingleFlight().token
    }

    /// Retry handing the current token to HOney after a failed push.
    public func pushPendingToken() async -> Bool {
        guard tokenPushPending, let session, let onFreshToken else { return !tokenPushPending }
        let ok = await onFreshToken(session.token)
        tokenPushPending = !ok
        return ok
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
            guard epoch == startEpoch else {
                // The student signed out / forgot the login meanwhile.
                await api.logout(token: token)
                throw PortalError.sessionExpired
            }
            do {
                try binding?.verify(identity)
            } catch {
                // The saved login belongs to someone else: never a session here.
                await api.logout(token: token)
                try? sessions.deleteSession()
                try? credentials.deleteCredentials()
                session = nil
                state = .userActionRequired(.unknown)
                throw PortalError.identityMismatch
            }
            let renewed = PortalSession(token: token, expiresAt: identity.tokenExpiresAt, studentId: identity.studentId)
            try? sessions.saveSession(renewed)
            session = renewed
            state = .authenticated(expiresAt: renewed.expiresAt, studentId: renewed.studentId)
            if let onFreshToken {
                tokenPushPending = !(await onFreshToken(token))
            }
            return renewed
        } catch let error as PortalError {
            guard epoch == startEpoch else { throw PortalError.sessionExpired }
            switch error {
            case .identityMismatch:
                break // state already set
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
        case .identityMismatch, .userActionRequired(.unknown): return .userActionRequired(.unknown)
        case .userActionRequired(let reason): return .userActionRequired(reason)
        case .schemaIncompatible: return .incompatible
        case .noCredentials, .sessionExpired: return .noCredentials
        default: return .temporarilyUnavailable
        }
    }
}

/// Keychain-shaped vaults on top of any SecretStore, namespaced by the HOney
/// account they belong to, with the school-identity binding for that
/// account: the display name HOney knows plus the first portal student id
/// seen. Without an account nothing loads and nothing saves.
public final class SecretPortalVault: PortalSessionVault, SchoolCredentialVault, PortalIdentityBinding, @unchecked Sendable {
    private let store: SecretStore
    private let lock = NSLock()
    private var account: String?
    private var expectedName: String?

    public init(store: SecretStore) {
        self.store = store
    }

    public func setAccount(_ honeyId: String?, expectedName: String?) {
        lock.lock()
        account = honeyId
        self.expectedName = expectedName
        lock.unlock()
        if honeyId != nil { migrateLegacyEntries() }
    }

    /// Builds before the review kept the school login and the portal session
    /// under un-namespaced keys. The first account that binds after the update
    /// takes them over, so "Stay connected" stays true to what the student
    /// chose (2026-09-02: the Keychain still held the login, Access said it
    /// did not).
    private func migrateLegacyEntries() {
        for base in ["honey.school.credentials", "honey.portal.session", "honey.portal.studentId"] {
            guard let scoped = try? key(base) else { return }
            guard (try? store.read(scoped)) == nil, let legacy = try? store.read(base) else { continue }
            if (try? store.write(scoped, legacy)) != nil { try? store.delete(base) }
        }
    }

    private func key(_ base: String) throws -> String {
        lock.lock(); defer { lock.unlock() }
        guard let account else { throw PortalError.noCredentials }
        return "\(base).\(AccountFiles.safeName(account))"
    }

    public func loadSession() throws -> PortalSession? {
        guard let data = try store.read(try key("honey.portal.session")) else { return nil }
        return try? JSONDecoder().decode(PortalSession.self, from: data)
    }

    public func saveSession(_ session: PortalSession) throws {
        try store.write(try key("honey.portal.session"), try JSONEncoder().encode(session))
    }

    public func deleteSession() throws {
        guard let k = try? key("honey.portal.session") else { return }
        try store.delete(k)
    }

    public func loadCredentials() throws -> PortalCredentials? {
        guard let data = try store.read(try key("honey.school.credentials")) else { return nil }
        let creds = try? JSONDecoder().decode(PortalCredentials.self, from: data)
        return (creds?.username.isEmpty == false && creds?.password.isEmpty == false) ? creds : nil
    }

    public func saveCredentials(_ credentials: PortalCredentials) throws {
        try store.write(try key("honey.school.credentials"), try JSONEncoder().encode(credentials))
    }

    public func deleteCredentials() throws {
        guard let k = try? key("honey.school.credentials") else { return }
        try store.delete(k)
    }

    public var hasCredentials: Bool { (try? loadCredentials()) != nil }

    /// The binding: once a student id has been seen for this HOney account
    /// it must not change — a saved login that answers as someone else is
    /// never used. The portal's display name is NOT compared: names are
    /// formatted differently on either side and a false mismatch threw the
    /// student's login away (Gary 2026-09-02: Stay connected was on, Access
    /// still asked for the login). `expectedName` is kept for diagnostics.
    public func verify(_ identity: PortalIdentity) throws {
        let k = try key("honey.portal.studentId")
        if let data = try store.read(k), let seen = String(data: data, encoding: .utf8), !seen.isEmpty {
            if seen != identity.studentId { throw PortalError.identityMismatch }
        } else {
            try store.write(k, Data(identity.studentId.utf8))
        }
    }
}
