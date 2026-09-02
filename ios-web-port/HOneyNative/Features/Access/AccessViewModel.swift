// Access (Gary: access要有): apply for an exit permit, see permits, open a
// gate — direct to the school portal with the saved school login; HOney
// never relays. Every failure stays on this screen.
//
// Freshness authority (review 11d42e3 §3.5): the permit list is re-read
// on appear, on foreground, on pull and after EVERY open attempt; a
// permit may open a gate only when the latest read succeeded and no open
// attempt is unconfirmed. A permit counts as used when its door flag is
// set or its status says opened, so a gate opened on the official site
// stops showing as openable here. One mutation at a time, never replayed.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class AccessViewModel {
    private let env: AppEnvironment
    private var refreshTask: Task<Void, Never>?
    private var generation = 0

    private(set) var authority = AccessAuthority()
    private(set) var connection: PortalSessionState = .restoring
    private(set) var loading = false
    private(set) var working = false
    private(set) var permitsError: String?
    private(set) var doorsError: String?
    var banner: (tone: BannerTone, text: String)?
    var draft = PermitDraft.quick()

    init(env: AppEnvironment) { self.env = env }

    var permits: [ExitPermit] { authority.permits }
    var doors: [PortalDoor] { authority.doors }
    var openable: [ExitPermit] { authority.openable() }
    var listed: [ExitPermit] { ExitPermit.sortedForList(authority.permits) }
    var permitsUsable: Bool { authority.permitsUsable }
    var staleMessage: String? { authority.staleMessage }
    var commuterRouteAvailable: Bool { authority.commuterRouteAvailable }
    var needsSchoolLogin: Bool {
        switch connection {
        case .noCredentials, .userActionRequired: return true
        default: return false
        }
    }

    /// The HOney account changed under this screen: nothing cached may show.
    func reset() {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        authority.reset()
        banner = nil
        permitsError = nil
        doorsError = nil
        draft = PermitDraft.quick()
    }

    /// Single-flight refresh: appear, foreground, pull and post-action all
    /// share one round trip.
    func refresh(keepBanner: Bool = false) async {
        if let refreshTask { await refreshTask.value; return }
        let gen = generation
        let task = Task { await self.performRefresh(keepBanner: keepBanner, generation: gen) }
        refreshTask = task
        await task.value
        if refreshTask == task { refreshTask = nil }
    }

    private func performRefresh(keepBanner: Bool, generation gen: Int) async {
        loading = true
        defer { loading = false }
        if !keepBanner { banner = nil }
        if !env.portalVault.hasCredentials {
            connection = .noCredentials
            permitsError = AccessCopy.describe(PortalError.noCredentials)
            authority.permitsFailed(permitsError ?? "")
            authority.doorsFailed()
            return
        }
        await env.portalCoordinator.restore()
        guard gen == generation else { return }
        connection = await env.portalCoordinator.currentState()
        async let permitsResult = fetchPermits()
        async let doorsResult = fetchDoors()
        let (p, d) = await (permitsResult, doorsResult)
        guard gen == generation else { return }
        switch p {
        case .success(let rows):
            authority.permitsLoaded(rows)
            permitsError = nil
        case .failure(let error):
            let message = AccessCopy.describe(error, fallback: "Permits are temporarily unavailable.")
            permitsError = message
            authority.permitsFailed(message)
        }
        switch d {
        case .success(let list):
            authority.doorsLoaded(list)
            doorsError = nil
        case .failure(let error):
            authority.doorsFailed()
            doorsError = AccessCopy.describe(error, fallback: "Gate names are temporarily unavailable.")
        }
        connection = await env.portalCoordinator.currentState()
    }

    private func fetchPermits() async -> Result<[ExitPermitWire], Error> {
        let api = env.portalAPI
        do {
            return .success(try await env.portalCoordinator.withAuthentication(replay: .safeRead) { token in
                try await api.permits(token: token)
            })
        } catch { return .failure(error) }
    }

    private func fetchDoors() async -> Result<[PortalDoor], Error> {
        let api = env.portalAPI
        do {
            return .success(try await env.portalCoordinator.withAuthentication(replay: .safeRead) { token in
                try await api.doors(token: token)
            })
        } catch { return .failure(error) }
    }

    func applyPermit() async {
        guard !working else { return }
        working = true
        defer { working = false }
        do {
            let token = try await env.portalCoordinator.prepareForSensitiveAction()
            let result = try await env.portalAPI.addPermit(token: token, draft.request)
            banner = (.success, result.message.isEmpty ? "Permit submitted." : result.message)
            await refresh(keepBanner: true)
            if permitsError != nil { banner = (.warning, "Permit submitted, but the permit list could not refresh.") }
        } catch {
            handle(error)
        }
    }

    /// Open a gate. Non-idempotent → never auto-replayed. The permit
    /// authority is withdrawn before the request and restored only by a
    /// successful re-read, whatever the portal answers.
    func openGate(route: AccessRoute, door: PortalDoor) async {
        guard !working else { return }
        switch route {
        case .commuter:
            guard authority.commuterRouteAvailable else { banner = (.warning, "Gate names are unavailable. Refresh Access and try again."); return }
        case .permit(let recordId):
            guard let permit = authority.permits.first(where: { $0.recordId == recordId }), authority.mayUse(permit) else {
                banner = (.warning, staleMessage ?? "This permit cannot be used until the list is refreshed.")
                return
            }
        }
        working = true
        defer { working = false }
        if case .permit = route { authority.openAttempted() }
        do {
            let token = try await env.portalCoordinator.prepareForSensitiveAction()
            let result = try await env.portalAPI.openDoor(token: token, recordId: route.recordId, doorKey: door.key)
            banner = (.success, result.message.isEmpty ? "\(door.displayName) opened." : result.message)
        } catch PortalError.timeout(outcomeUnknown: true) {
            banner = (.warning, AccessCopy.describe(PortalError.timeout(outcomeUnknown: true)))
        } catch PortalError.operationRejected(let endpoint, let status, let message) {
            banner = (.warning, AccessCopy.describe(PortalError.operationRejected(endpoint: endpoint, status: status, message: message)))
        } catch {
            handle(error)
        }
        await refresh(keepBanner: true)
    }

    /// Withdraw a pending permit request (explicit, confirmed, never retried).
    func deletePermit(_ permit: ExitPermit) async {
        guard !working else { return }
        working = true
        defer { working = false }
        do {
            let token = try await env.portalCoordinator.prepareForSensitiveAction()
            _ = try await env.portalAPI.deletePermit(token: token, recordId: permit.recordId)
            banner = (.success, "Permit request withdrawn.")
        } catch {
            handle(error)
        }
        await refresh(keepBanner: true)
    }

    private func handle(_ error: Error) {
        banner = (.warning, AccessCopy.describe(error))
        if let portalError = error as? PortalError {
            switch portalError {
            case .credentialsRejected, .userActionRequired, .identityMismatch: connection = .userActionRequired(.unknown)
            case .noCredentials: connection = .noCredentials
            default: break
            }
        }
    }
}
