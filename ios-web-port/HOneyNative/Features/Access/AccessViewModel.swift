// Access (Gary: access要有): apply for an exit permit, see permits, open a
// gate — direct to the school portal with the saved school login; HOney
// never relays. Every failure stays on this screen.
//
// The consumed-permit fix: the permit list is re-read from the portal on
// appear, on foreground, on pull, and after EVERY open attempt (success,
// refusal or unknown outcome), and a permit counts as used when its door
// flag is set or its status says opened — so a gate opened from the
// official site stops showing as openable here.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class AccessViewModel {
    private let env: AppEnvironment
    private var refreshTask: Task<Void, Never>?

    private(set) var permits: [ExitPermit] = []
    private(set) var doors: [PortalDoor] = []
    private(set) var connection: PortalSessionState = .restoring
    private(set) var loading = false
    private(set) var working = false
    private(set) var didLoadPermits = false
    private(set) var didLoadDoors = false
    private(set) var permitsError: String?
    private(set) var doorsError: String?
    var banner: (tone: BannerTone, text: String)?
    var draft = PermitDraft.quick()

    init(env: AppEnvironment) { self.env = env }

    var openable: [ExitPermit] { ExitPermit.openable(permits) }
    var listed: [ExitPermit] { ExitPermit.sortedForList(permits) }
    var needsSchoolLogin: Bool {
        switch connection {
        case .noCredentials, .userActionRequired: return true
        default: return false
        }
    }

    /// Single-flight refresh: appear, foreground, pull and post-action all
    /// share one round trip.
    func refresh(keepBanner: Bool = false) async {
        if let refreshTask { await refreshTask.value; return }
        let task = Task { await self.performRefresh(keepBanner: keepBanner) }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh(keepBanner: Bool) async {
        loading = true
        defer { loading = false }
        if !keepBanner { banner = nil }
        if !env.portalVault.hasCredentials {
            connection = .noCredentials
            permitsError = AccessCopy.describe(PortalError.noCredentials)
            doorsError = nil
            didLoadPermits = false
            didLoadDoors = false
            return
        }
        await env.portalCoordinator.restore()
        connection = await env.portalCoordinator.currentState()
        async let permitsResult = fetchPermits()
        async let doorsResult = fetchDoors()
        let (p, d) = await (permitsResult, doorsResult)
        switch p {
        case .success(let rows):
            permits = rows.map(ExitPermit.init)
            didLoadPermits = true
            permitsError = nil
        case .failure(let error):
            permitsError = AccessCopy.describe(error, fallback: "Permits are temporarily unavailable.")
        }
        switch d {
        case .success(let list):
            doors = list
            didLoadDoors = true
            doorsError = nil
        case .failure(let error):
            didLoadDoors = false
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

    /// Open a gate. Non-idempotent → never auto-replayed. Whatever the
    /// portal answers, the permit list is re-read so a consumed permit
    /// stops offering itself.
    func openGate(route: AccessRoute, door: PortalDoor) async {
        guard !working else { return }
        working = true
        defer { working = false }
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
            case .credentialsRejected, .userActionRequired: connection = .userActionRequired(.unknown)
            case .noCredentials: connection = .noCredentials
            default: break
            }
        }
    }
}
