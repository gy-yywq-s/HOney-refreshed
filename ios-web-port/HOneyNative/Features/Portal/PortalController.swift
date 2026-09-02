// The official School Portal inside HOney (spec §23). The signed-in entry
// URL is prepared BEFORE the tap through /api/portal/entry and held in
// memory until its safety margin; the token-bearing URL is never logged,
// never shared, never remembered as a "last page".
//
// Recovery has ONE source of truth (review 11d42e3 §3.2): when HOney reports
// that its portal token ended, the device-side PortalSessionCoordinator
// renews it directly with the school (checking the account binding) and
// hands the fresh token to HOney; the full HOney login is never replayed
// for routine expiry. Account changes reset everything here (§3.1.5).

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class PortalController {
    private let api: APIClient
    private let coordinator: PortalSessionCoordinator
    let home: URL
    private static let margin: TimeInterval = 5 * 60

    private var entry: (url: URL, expiresAt: Date)?
    private var inflight: Task<Void, Never>?
    private var generation = 0
    /// Set when the portal needs the student (password changed, challenge, mismatch).
    private(set) var needsSchoolAction = false
    /// The last attempt to prepare an entry failed for this reason (shown in
    /// the portal surface and School connection); nil when fine.
    private(set) var lastError: String?

    init(api: APIClient, coordinator: PortalSessionCoordinator, home: URL) {
        self.api = api
        self.coordinator = coordinator
        self.home = home
    }

    /// A valid signed-in URL, or nil (the plain portal home is the fallback).
    var signedInEntry: URL? {
        guard let entry, entry.expiresAt.timeIntervalSinceNow > Self.margin else { return nil }
        return entry.url
    }

    /// Forget everything for the previous account; in-flight work is ignored.
    func reset() {
        generation += 1
        inflight?.cancel()
        inflight = nil
        entry = nil
        needsSchoolAction = false
        lastError = nil
    }

    func noteTokenPushFailure(_ message: String) {
        lastError = "HOney could not take the renewed school session: \(message)"
    }

    /// Ask HOney for the entry; when the portal session ended and this
    /// iPhone keeps the school login, renew through the device coordinator
    /// and ask once more.
    func prewarm(force: Bool = false) async {
        if !force, signedInEntry != nil { return }
        if let inflight { await inflight.value; return }
        let gen = generation
        let task = Task { await self.fetchEntry(generation: gen) }
        inflight = task
        await task.value
        if inflight == task { inflight = nil }
    }

    private func fetchEntry(generation gen: Int) async {
        do {
            var response = try await api.portalEntry()
            if case .reconnectRequired = response {
                do {
                    let token = try await coordinator.freshToken()
                    try await api.pushPortalToken(token)
                    response = try await api.portalEntry()
                } catch let error as PortalError {
                    guard gen == generation else { return }
                    switch error {
                    case .credentialsRejected, .userActionRequired, .identityMismatch:
                        needsSchoolAction = true
                        lastError = AccessCopy.describe(error)
                    case .noCredentials:
                        lastError = nil // no saved login: the plain portal page is the honest fallback
                    default:
                        lastError = AccessCopy.describe(error)
                    }
                    return
                }
            }
            guard gen == generation else { return }
            if case .ok(let url, let expiresAt) = response, let parsed = URL(string: url) {
                entry = (parsed, Date(epochMillis: expiresAt))
                needsSchoolAction = false
                lastError = nil
            }
        } catch {
            guard gen == generation else { return }
            lastError = APIErrorCopy.describe(error)
        }
    }

    /// The entry is spent (the page landed on login): forget it and renew.
    func invalidateEntry() {
        entry = nil
    }

    /// The portal answered the entry with its login page: HOney's token is
    /// dead whatever its clock says (the student signed in on the official
    /// site and the school invalidated it). Renew with the saved school
    /// login on this device, hand the new token to HOney, fetch the entry
    /// again. Returns the signed-in URL or nil when this device cannot renew.
    func recoverAfterLoginPage() async -> URL? {
        entry = nil
        let gen = generation
        do {
            let token = try await coordinator.renew()
            try await api.pushPortalToken(token)
            let response = try await api.portalEntry()
            guard gen == generation else { return nil }
            if case .ok(let url, let expiresAt) = response, let parsed = URL(string: url) {
                entry = (parsed, Date(epochMillis: expiresAt))
                needsSchoolAction = false
                lastError = nil
                return parsed
            }
            return nil
        } catch let error as PortalError {
            guard gen == generation else { return nil }
            switch error {
            case .credentialsRejected, .userActionRequired, .identityMismatch:
                needsSchoolAction = true
                lastError = AccessCopy.describe(error)
            case .noCredentials:
                lastError = "The portal session ended and this iPhone has no school login to renew it. Enter it once in Settings › School connection."
            default:
                lastError = AccessCopy.describe(error)
            }
            return nil
        } catch {
            guard gen == generation else { return nil }
            lastError = APIErrorCopy.describe(error)
            return nil
        }
    }
}
