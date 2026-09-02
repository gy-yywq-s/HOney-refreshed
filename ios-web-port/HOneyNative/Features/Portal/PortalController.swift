// The official School Portal inside HOney (spec §23). The signed-in entry
// URL is prepared BEFORE the tap through /api/portal/entry (renewed
// silently with the saved school login when the portal session ended) and
// held in memory until its safety margin; the token-bearing URL is never
// logged, never shared, never remembered as a "last page".

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class PortalController {
    private let api: APIClient
    private let coordinator: PortalSessionCoordinator
    private let vault: SecretPortalVault
    private let prefs: Preferences
    let home: URL
    private static let margin: TimeInterval = 5 * 60

    private var entry: (url: URL, expiresAt: Date)?
    private var inflight: Task<Void, Never>?
    /// Set when the portal needs the student (password changed, challenge).
    private(set) var needsSchoolAction = false

    init(api: APIClient, coordinator: PortalSessionCoordinator, vault: SecretPortalVault, prefs: Preferences, home: URL) {
        self.api = api
        self.coordinator = coordinator
        self.vault = vault
        self.prefs = prefs
        self.home = home
    }

    /// A valid signed-in URL, or nil (the plain portal home is the fallback).
    var signedInEntry: URL? {
        guard let entry, entry.expiresAt.timeIntervalSinceNow > Self.margin else { return nil }
        return entry.url
    }

    /// Ask HOney for the entry; when the portal session ended and this
    /// iPhone keeps the school login, sign in again silently and ask once more.
    func prewarm(force: Bool = false) async {
        if !force, signedInEntry != nil { return }
        if let inflight { await inflight.value; return }
        let task = Task { await self.fetchEntry() }
        inflight = task
        await task.value
        inflight = nil
    }

    private func fetchEntry() async {
        do {
            var response = try await api.portalEntry()
            if case .reconnectRequired = response, let creds = try? vault.loadCredentials() {
                do {
                    _ = try await api.login(LoginInput(username: creds.username, password: creds.password))
                    response = try await api.portalEntry()
                } catch let error as APIError where error.code == "school_credentials_rejected" || error.code == "portal_interactive_challenge" {
                    needsSchoolAction = true
                    return
                }
            }
            if case .ok(let url, let expiresAt) = response, let parsed = URL(string: url) {
                entry = (parsed, Date(epochMillis: expiresAt))
                needsSchoolAction = false
            }
        } catch {
            // The plain portal address stays the fallback.
        }
    }

    /// The entry is spent (the page landed on login): forget it and renew.
    func invalidateEntry() {
        entry = nil
    }
}
