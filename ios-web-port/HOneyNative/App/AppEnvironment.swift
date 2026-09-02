// The composition root (spec §3.3): Views see this object and the feature
// view models; they never build URLs, refresh tokens, sequence the
// publication flow or touch the Keychain. Everything below the view models
// lives in HOneyCore and is tested on Linux.

import Foundation
import Observation
import SwiftUI
import HOneyCore

struct AppConfig {
    let honeyBaseURL = URL(string: "https://honey.gaelisus.com")!
    let portalBaseURL = URL(string: "https://www.huayaopudong.com")!
    let portalHome = URL(string: "https://www.huayaopudong.com/student/notification")!
    let portalHosts: Set<String> = ["www.huayaopudong.com", "huayaopudong.com"]
    let dashURL = URL(string: "https://honey.gaelisus.com/dash")!
    let buildLabel: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()
}

enum AuthPhase: Equatable {
    case loading
    case signedOut
    case signedIn(Me)
    case unavailable(String)

    var key: Int {
        switch self {
        case .loading: return 0
        case .signedOut: return 1
        case .signedIn: return 2
        case .unavailable: return 3
        }
    }
}

@MainActor
@Observable
final class AppEnvironment {
    let config: AppConfig
    let api: APIClient
    let publication: PublicationAPIClient
    let portalAPI: PortalAPI
    let portalCoordinator: PortalSessionCoordinator
    let portalVault: SecretPortalVault
    let feedStore: FeedStore
    let timetable: TimetableRepository
    let notes: PrivateNoteStore
    let drafts: ComposerDraftStore
    let prefs: Preferences
    let navigator: Navigator
    let portal: PortalController
    private let secrets: SecretStore
    private(set) var keys: SecretOwnershipKeyStore

    private(set) var phase: AuthPhase = .loading
    private(set) var me: Me?
    /// The `Me` last seen for this account, so a failed refresh keeps the shell.
    private var cachedMe: Me?
    /// One honest notice after login when the Keychain refused the school login.
    var loginNotice: String?
    var appearance: AppearanceChoice {
        didSet { prefs.appearance = appearance }
    }
    var language: AppLanguage {
        didSet {
            prefs.language = language
            L10n.language = language
        }
    }

    init(config: AppConfig, secrets: SecretStore, storageDirectory: URL, prefs: Preferences, writeOptions: Data.WritingOptions) {
        self.config = config
        self.secrets = secrets
        self.prefs = prefs
        self.appearance = prefs.appearance
        self.language = prefs.language
        L10n.language = prefs.language
        let sessionStore = SecretSessionStore(store: secrets)
        let api = APIClient(baseURL: config.honeyBaseURL, transport: URLSessionTransport(), sessionStore: sessionStore)
        let portalVault = SecretPortalVault(store: secrets)
        let portalConfig = URLSessionConfiguration.default
        portalConfig.timeoutIntervalForRequest = 20
        portalConfig.timeoutIntervalForResource = 30
        portalConfig.waitsForConnectivity = false
        portalConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        let portalAPI = PortalAPI(baseURL: config.portalBaseURL, transport: URLSessionTransport(configuration: portalConfig))
        let portalCoordinator = PortalSessionCoordinator(api: portalAPI, sessions: portalVault, credentials: portalVault)
        self.api = api
        self.publication = PublicationAPIClient(baseURL: config.honeyBaseURL, transport: URLSessionTransport.identityFree())
        self.portalVault = portalVault
        self.portalAPI = portalAPI
        self.portalCoordinator = portalCoordinator
        self.feedStore = FeedStore()
        self.timetable = TimetableRepository(api: api)
        self.notes = PrivateNoteStore(directory: storageDirectory, writeOptions: writeOptions)
        self.drafts = ComposerDraftStore(directory: storageDirectory, writeOptions: writeOptions)
        self.keys = SecretOwnershipKeyStore(store: secrets, account: "anonymous")
        self.navigator = Navigator()
        self.portal = PortalController(api: api, coordinator: portalCoordinator, vault: portalVault, prefs: prefs, home: config.portalHome)
    }

    static func live() -> AppEnvironment {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let env = AppEnvironment(
            config: AppConfig(),
            secrets: KeychainSecretStore(service: "com.gaelisus.honey.native"),
            storageDirectory: support.appendingPathComponent("HOney", isDirectory: true),
            prefs: Preferences(),
            writeOptions: [.completeFileProtection]
        )
        return env
    }

    // MARK: Session

    func bootstrap() async {
        await api.onSessionLost { [weak self] in
            Task { @MainActor in self?.sessionLost() }
        }
        await portalCoordinator.setFreshTokenHandler { [weak self] token in
            // A token minted on the device also serves HOney's own sync/entry.
            try? await self?.api.pushPortalToken(token)
        }
        guard await api.hasSession() else {
            phase = .signedOut
            return
        }
        if phase == .loading || phase.key == AuthPhase.unavailable("").key { phase = .loading }
        await refreshMe(initial: true)
    }

    func refreshMe(initial: Bool = false) async {
        do {
            let me = try await api.me()
            apply(me)
            phase = .signedIn(me)
        } catch let error as APIError where error.status == 401 {
            sessionLost()
        } catch {
            if let cachedMe {
                phase = .signedIn(cachedMe)
            } else if initial {
                phase = .unavailable(APIErrorCopy.describe(error))
            }
        }
    }

    private func apply(_ me: Me) {
        self.me = me
        cachedMe = me
        keys.setAccount(me.honeyId)
        Task { await notes.setAccount(me.honeyId) }
    }

    /// School login IS the HOney login. Saves the school login to the Keychain
    /// by default (Settings opt-out); success is shown only after storage
    /// actually succeeded, and a Keychain failure becomes one honest notice.
    func login(username: String, password: String) async throws {
        let result = try await api.login(LoginInput(username: username, password: password))
        loginNotice = nil
        if prefs.stayConnectedWanted {
            do {
                try await portalCoordinator.authorize(PortalCredentials(username: username, password: password))
            } catch {
                loginNotice = "Signed in, but this iPhone could not keep your school login, so automatic reconnect is off for now. You can try again in Settings › School connection."
            }
        }
        let me = Me(
            honeyId: result.honeyId, displayName: result.displayName, isAdmin: result.isAdmin,
            consent: Me.Consent(timetable: result.consent.timetable, grantedAt: nil),
            connection: Me.Connection(connected: true, lastSyncedAt: nil, portalTokenValid: true)
        )
        apply(me)
        phase = .signedIn(me)
        await refreshMe()
        Task { await portal.prewarm() }
    }

    func signOut() async {
        await api.logout()
        await timetable.invalidateAll()
        await feedStore.invalidateAll()
        // Notes and control keys stay (spec §5.1): only "erase local data" removes them.
        me = nil
        cachedMe = nil
        navigator.reset()
        phase = .signedOut
    }

    func deleteAccount(eraseLocalData: Bool) async throws {
        try await api.deleteAccount()
        await portalCoordinator.forgetEverything()
        if eraseLocalData {
            try? await notes.clearAll()
            for key in (try? keys.list()) ?? [] { try? keys.remove(key: key.key) }
        }
        await timetable.invalidateAll()
        await feedStore.invalidateAll()
        me = nil
        cachedMe = nil
        navigator.reset()
        phase = .signedOut
    }

    private func sessionLost() {
        me = nil
        cachedMe = nil
        navigator.reset()
        phase = .signedOut
    }

    func didBecomeActive() async {
        guard case .signedIn = phase else { return }
        await refreshMe()
        await portal.prewarm()
    }

    /// The Reconnect / Save-login sheet's work: HOney login with the school
    /// account, then the saved login is kept or cleared per the wish.
    func reconnectSchool(username: String, password: String, keep: Bool) async throws {
        _ = try await api.login(LoginInput(username: username, password: password))
        if keep {
            prefs.stayConnectedWanted = true
            try await portalCoordinator.authorize(PortalCredentials(username: username, password: password))
        } else {
            await portalCoordinator.forgetEverything()
        }
        await refreshMe()
        await portal.prewarm()
    }

    /// Settings toggle: off deletes the Keychain school login and records the wish.
    func setStayConnected(_ on: Bool) async {
        prefs.stayConnectedWanted = on
        if !on { await portalCoordinator.forgetEverything() }
    }

    var hasSavedSchoolLogin: Bool { portalVault.hasCredentials }

    /// Upstream school sync (explicit action): silently re-logs in with the
    /// saved school login when the portal session ended.
    func syncWithSchool() async throws -> (SyncResponse, reconnected: Bool) {
        var result = try await api.sync()
        var reconnected = false
        if result.status == .portalReconnectRequired, let creds = try? portalVault.loadCredentials() {
            _ = try await api.login(LoginInput(username: creds.username, password: creds.password))
            result = try await api.sync()
            reconnected = true
        }
        if result.status == .ok {
            await timetable.invalidateAll()
            await refreshMe()
        }
        return (result, reconnected)
    }
}

/// App-wide read cache for school data (spec §3.4 TimetableRepository):
/// day/week/history/directory/entities, coalesced in-flight requests,
/// invalidated after a school sync. Cached content paints before refresh.
actor TimetableRepository {
    private let api: APIClient
    private var days: [String: TimetableResponse] = [:]
    private var weeks: [String: TimetableRangeResponse] = [:]
    private var nextLesson: NextLessonResponse?
    private var directory: DirectoryResponse?
    private var entities: EntitiesResponse?
    private var histories: [String: HistoryResponse] = [:]
    private var inflight: [String: Task<any Sendable, Error>] = [:]

    init(api: APIClient) { self.api = api }

    func cachedDay(_ date: String) -> TimetableResponse? { days[date] }
    func cachedWeek(_ monday: String) -> TimetableRangeResponse? { weeks[monday] }
    func cachedNextLesson() -> NextLessonResponse? { nextLesson }
    func cachedDirectory() -> DirectoryResponse? { directory }
    func cachedEntities() -> EntitiesResponse? { entities }

    func day(_ date: String, reload: Bool = false) async throws -> TimetableResponse {
        if !reload, let cached = days[date] { return cached }
        let value = try await coalesce("day:\(date)") { try await self.api.timetable(date: date) }
        days[date] = value
        return value
    }

    func week(monday: String, reload: Bool = false) async throws -> TimetableRangeResponse {
        if !reload, let cached = weeks[monday] { return cached }
        let value = try await coalesce("week:\(monday)") {
            try await self.api.timetableRange(from: monday, to: Formatters.shiftIsoDate(monday, days: 6))
        }
        weeks[monday] = value
        return value
    }

    func next(reload: Bool = false) async throws -> NextLessonResponse {
        if !reload, let cached = nextLesson { return cached }
        let value = try await coalesce("next") { try await self.api.nextLesson() }
        nextLesson = value
        return value
    }

    func directory(reload: Bool = false) async throws -> DirectoryResponse {
        if !reload, let cached = directory { return cached }
        let value = try await coalesce("directory") { try await self.api.directory() }
        directory = value
        return value
    }

    func entities(reload: Bool = false) async throws -> EntitiesResponse {
        if !reload, let cached = entities { return cached }
        let value = try await coalesce("entities") { try await self.api.entities() }
        entities = value
        return value
    }

    func history(_ params: HistoryParams, reload: Bool = false) async throws -> HistoryResponse {
        let key = "history:\(params.q ?? "")|\(params.teacherId ?? "")|\(params.courseId ?? "")|\(params.limit ?? 0)"
        if !reload, let cached = histories[key] { return cached }
        let value = try await coalesce(key) { try await self.api.history(params) }
        histories[key] = value
        return value
    }

    func invalidateAll() {
        days.removeAll()
        weeks.removeAll()
        nextLesson = nil
        directory = nil
        histories.removeAll()
        // entities are a community registry, not school data — kept.
        inflight.removeAll()
    }

    func invalidateEntities() { entities = nil }

    private func coalesce<T: Sendable>(_ key: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        if let task = inflight[key] { return try await task.value as! T }
        let task = Task<any Sendable, Error> { try await work() as any Sendable }
        inflight[key] = task
        defer { inflight[key] = nil }
        return try await task.value as! T
    }
}
