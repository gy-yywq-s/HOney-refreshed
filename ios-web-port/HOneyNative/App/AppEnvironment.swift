// The composition root (spec §3.3): Views see this object and the feature
// view models; they never build URLs, refresh tokens, sequence the
// publication flow or touch the Keychain. Everything below the view models
// lives in HOneyCore and is tested on Linux.
//
// Account boundary (review 11d42e3 §3.1): one `AccountScope` is activated
// per signed-in HOney account, and every account-scoped store (notes,
// drafts, control keys, preferences, school login, portal state, caches)
// is switched — awaited — BEFORE the signed-in shell appears. Signing out
// deactivates the scope before the login screen shows, so no store can be
// read under a stale account.

import Foundation
import Observation
import SwiftUI
import HOneyCore

struct AppConfig {
    let honeyBaseURL: URL
    let portalBaseURL: URL
    let portalHome: URL
    let portalHosts: Set<String>
    let dashURL: URL
    let environmentName: String
    let buildLabel: String

    /// Production unless the bundle's Info.plist names another HOney server
    /// (`HOneyBaseURL`, set per build configuration in project.yml).
    static func fromBundle(_ bundle: Bundle = .main) -> AppConfig {
        let info = bundle.infoDictionary ?? [:]
        let honey = (info["HOneyBaseURL"] as? String).flatMap(URL.init(string:)) ?? URL(string: "https://honey.gaelisus.com")!
        let portal = (info["HOneyPortalBaseURL"] as? String).flatMap(URL.init(string:)) ?? URL(string: "https://www.huayaopudong.com")!
        let version = info["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info["CFBundleVersion"] as? String ?? "1"
        let name = info["HOneyEnvironment"] as? String ?? "production"
        return AppConfig(
            honeyBaseURL: honey,
            portalBaseURL: portal,
            portalHome: portal.appendingPathComponent("student/notification"),
            portalHosts: [portal.host ?? "www.huayaopudong.com", "huayaopudong.com"],
            dashURL: honey.appendingPathComponent("dash"),
            environmentName: name,
            buildLabel: "\(version) (\(build))" + (name == "production" ? "" : " · \(name)")
        )
    }
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

/// The signed-in account every account-scoped store is bound to.
struct AccountScope: Equatable {
    let honeyId: String
    let displayName: String
}

/// What account deletion actually managed to clear (review §4.16).
struct DeletionReport: Equatable {
    var serverDeleted = false
    var portalSecretsCleared = true
    var notesCleared: Bool?
    var keysCleared: Bool?

    var failures: [String] {
        var out: [String] = []
        if !portalSecretsCleared { out.append("the school login kept on this iPhone") }
        if notesCleared == false { out.append("private notes") }
        if keysCleared == false { out.append("post control keys") }
        return out
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
    let journal: PublicationJournal
    let prefs: Preferences
    let navigator: Navigator
    let portal: PortalController
    let keys: SecretOwnershipKeyStore

    private(set) var phase: AuthPhase = .loading
    private(set) var me: Me?
    private(set) var scope: AccountScope?
    /// The `Me` last seen for this account, so a failed refresh keeps the shell.
    private var cachedMe: Me?
    /// Bumped on every account change; async work compares before applying.
    private var accountEpoch = 0
    /// One honest notice after login when the Keychain refused the school login.
    var loginNotice: String?
    /// Shown on the login screen after a deletion that could not clear everything.
    var signedOutNotice: String?
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
        let portalCoordinator = PortalSessionCoordinator(api: portalAPI, sessions: portalVault, credentials: portalVault, binding: portalVault)
        self.api = api
        self.publication = PublicationAPIClient(baseURL: config.honeyBaseURL, transport: URLSessionTransport.identityFree())
        self.portalVault = portalVault
        self.portalAPI = portalAPI
        self.portalCoordinator = portalCoordinator
        self.feedStore = FeedStore()
        self.timetable = TimetableRepository(provider: api)
        self.notes = PrivateNoteStore(directory: storageDirectory, writeOptions: writeOptions)
        self.drafts = ComposerDraftStore(directory: storageDirectory, writeOptions: writeOptions)
        self.journal = PublicationJournal(directory: storageDirectory, writeOptions: writeOptions)
        self.keys = SecretOwnershipKeyStore(store: secrets, account: SecretOwnershipKeyStore.signedOutAccount)
        self.navigator = Navigator()
        self.portal = PortalController(api: api, coordinator: portalCoordinator, home: config.portalHome)
    }

    static func live() -> AppEnvironment {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return AppEnvironment(
            config: AppConfig.fromBundle(),
            secrets: KeychainSecretStore(service: "com.gaelisus.honey.native"),
            storageDirectory: support.appendingPathComponent("HOney", isDirectory: true),
            prefs: Preferences(),
            writeOptions: [.completeFileProtection]
        )
    }

    // MARK: Account scope

    /// Bind every account-scoped store to this account — awaited, in order,
    /// before any signed-in UI can read them.
    private func activate(_ me: Me) async {
        let next = AccountScope(honeyId: me.honeyId, displayName: me.displayName)
        if scope != next {
            accountEpoch += 1
            await feedStore.invalidateAll()
            await timetable.invalidateAll()
            navigator.reset()
        }
        scope = next
        self.me = me
        cachedMe = me
        keys.setAccount(me.honeyId)
        drafts.setAccount(me.honeyId)
        prefs.setAccount(me.honeyId)
        await notes.setAccount(me.honeyId)
        await journal.setAccount(me.honeyId)
        portalVault.setAccount(me.honeyId, expectedName: me.displayName)
        await portalCoordinator.accountChanged()
        portal.reset()
        await PortalWebController.shared.resetForAccountChange()
    }

    /// Unbind everything before the login screen appears.
    private func deactivate() async {
        accountEpoch += 1
        scope = nil
        me = nil
        cachedMe = nil
        keys.setAccount(SecretOwnershipKeyStore.signedOutAccount)
        drafts.setAccount(nil)
        prefs.setAccount(nil)
        await notes.setAccount(nil)
        await journal.setAccount(nil)
        portalVault.setAccount(nil, expectedName: nil)
        await portalCoordinator.accountChanged()
        portal.reset()
        await PortalWebController.shared.resetForAccountChange()
        await feedStore.invalidateAll()
        await timetable.invalidateAll()
        navigator.reset()
    }

    // MARK: Session

    func bootstrap() async {
        await api.onSessionLost { [weak self] in
            Task { @MainActor in await self?.sessionLost() }
        }
        await portalCoordinator.setFreshTokenHandler { [weak self] token in
            // A token minted on the device also serves HOney's own sync/entry.
            guard let self else { return false }
            do {
                try await self.api.pushPortalToken(token)
                return true
            } catch {
                await self.portal.noteTokenPushFailure(APIErrorCopy.describe(error))
                return false
            }
        }
        guard await api.hasSession() else {
            await deactivate()
            phase = .signedOut
            return
        }
        if phase == .loading || phase.key == AuthPhase.unavailable("").key { phase = .loading }
        await refreshMe(initial: true)
    }

    func refreshMe(initial: Bool = false) async {
        let epoch = accountEpoch
        do {
            let me = try await api.me()
            guard epoch == accountEpoch || scope == nil else { return }
            await activate(me)
            phase = .signedIn(me)
            await recoverPublications()
        } catch let error as APIError where error.status == 401 {
            await sessionLost()
        } catch {
            if let cachedMe, scope != nil {
                phase = .signedIn(cachedMe)
            } else if initial {
                phase = .unavailable(APIErrorCopy.describe(error))
            }
        }
    }

    /// School login IS the HOney login. Saves the school login to the Keychain
    /// by default (Settings opt-out); success is shown only after storage
    /// actually succeeded, and a Keychain failure becomes one honest notice.
    func login(username: String, password: String) async throws {
        let result = try await api.login(LoginInput(username: username, password: password))
        loginNotice = nil
        let me = Me(
            honeyId: result.honeyId, displayName: result.displayName, isAdmin: result.isAdmin,
            consent: Me.Consent(timetable: result.consent.timetable, grantedAt: nil),
            connection: Me.Connection(connected: true, lastSyncedAt: nil, portalTokenValid: true)
        )
        await activate(me)
        if prefs.stayConnectedWanted {
            do {
                try await portalCoordinator.authorize(PortalCredentials(username: username, password: password))
            } catch {
                loginNotice = "Signed in, but this iPhone could not keep your school login, so automatic reconnect is off for now. You can try again in Settings › School connection."
            }
        }
        phase = .signedIn(me)
        await refreshMe()
        Task { await portal.prewarm() }
    }

    func signOut() async {
        await api.logout()
        // Notes and control keys stay on the device for this account (spec
        // §5.1): only "erase local data" removes them. Everything is unbound.
        await deactivate()
        phase = .signedOut
    }

    /// Deletes the account server-side, then clears what the student asked
    /// for locally and reports exactly what could not be cleared.
    func deleteAccount(eraseLocalData: Bool) async throws -> DeletionReport {
        try await api.deleteAccount()
        var report = DeletionReport(serverDeleted: true)
        do {
            try await portalCoordinator.forgetEverything()
        } catch {
            report.portalSecretsCleared = false
        }
        if eraseLocalData {
            do {
                try await notes.clearAll()
                report.notesCleared = true
            } catch {
                report.notesCleared = false
            }
            var keysOK = true
            for key in (try? keys.list()) ?? [] {
                do { try keys.remove(key: key.key) } catch { keysOK = false }
            }
            try? await journal.clearAll()
            report.keysCleared = keysOK
        }
        await deactivate()
        if !report.failures.isEmpty {
            signedOutNotice = "Your HOney account was deleted, but this iPhone could not clear: \(report.failures.joined(separator: ", ")). Reinstalling the app removes them."
        }
        phase = .signedOut
        return report
    }

    private func sessionLost() async {
        await deactivate()
        phase = .signedOut
    }

    func didBecomeActive() async {
        guard case .signedIn = phase else { return }
        await refreshMe()
        await portal.prewarm()
    }

    /// Control keys journaled at publish time but not yet in the Keychain
    /// (the app died, or the Keychain refused): try again on every launch.
    func recoverPublications() async {
        let pending = (try? await journal.pending()) ?? []
        for record in pending {
            do {
                try keys.add(key: record.ownershipKey, experienceId: record.experienceId)
                guard try keys.list().contains(where: { $0.experienceId == record.experienceId }) else { continue }
                try? await journal.remove(experienceId: record.experienceId)
            } catch {
                // Keep the journal entry; the next launch tries again.
            }
        }
    }

    /// The Reconnect / Save-login sheet's work: the school login is proven
    /// against the school itself by the device coordinator, kept or cleared
    /// per the wish, and the fresh token handed to HOney.
    func reconnectSchool(username: String, password: String, keep: Bool) async throws {
        let credentials = PortalCredentials(username: username, password: password)
        try await portalCoordinator.verify(credentials)
        if keep {
            prefs.stayConnectedWanted = true
            try await portalCoordinator.authorize(credentials)
            _ = try await portalCoordinator.prepareForSensitiveAction()
        } else {
            prefs.stayConnectedWanted = false
            try? await portalCoordinator.forgetEverything()
            // No saved login: HOney itself needs the sign-in once to hold a portal token.
            _ = try await api.login(LoginInput(username: username, password: password))
        }
        await refreshMe()
        await portal.prewarm(force: true)
    }

    /// Settings toggle: off deletes the Keychain school login and records the wish.
    func setStayConnected(_ on: Bool) async {
        prefs.stayConnectedWanted = on
        if !on { try? await portalCoordinator.forgetEverything() }
    }

    var hasSavedSchoolLogin: Bool { portalVault.hasCredentials }

    /// Upstream school sync (explicit action). When HOney's portal token has
    /// ended, the device coordinator renews it directly with the school and
    /// hands it to HOney — the full HOney login is never replayed for this.
    func syncWithSchool() async throws -> (SyncResponse, reconnected: Bool) {
        var result = try await api.sync()
        var reconnected = false
        if result.status == .portalReconnectRequired, portalVault.hasCredentials {
            let token = try await portalCoordinator.freshToken()
            try await api.pushPortalToken(token)
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
