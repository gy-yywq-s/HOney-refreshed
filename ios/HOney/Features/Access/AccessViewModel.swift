//
//  AccessViewModel.swift
//  HOney — Access (apply-permit + open-gate). Direct-to-school; NO HOney relay.
//  Uses PortalSessionCoordinator. All failures are isolated to this screen.
//

import Foundation
import Observation

@MainActor
@Observable
final class AccessViewModel {
    private let coordinator: PortalSessionCoordinator
    private let api: PortalAPI

    var permits: [PortalPermitRow] = []
    var doors: [PortalDoor] = []
    var connectionState: PortalSessionState = .restoring

    var isLoading = false
    var isWorking = false
    var banner: (kind: BannerKind, message: String)?

    init(services: AppServices) {
        self.coordinator = services.portalCoordinator
        self.api = services.portalAPI
    }

    var approvedPermits: [PortalPermitRow] { permits.filter { $0.isApproved } }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        await coordinator.restore()
        connectionState = await coordinator.currentState()

        do {
            async let permitsResult = coordinator.withAuthentication(replay: .safeRead) { [api] token in
                try await api.permits(token: token)
            }
            async let doorsResult = coordinator.withAuthentication(replay: .safeRead) { [api] token in
                try await api.doorList(token: token)
            }
            permits = try await permitsResult
            doors = try await doorsResult
            banner = nil
        } catch {
            handle(error, context: "load")
        }
        connectionState = await coordinator.currentState()
    }

    func applyPermit(start: Date, end: Date, reason: String) async {
        isWorking = true
        defer { isWorking = false }
        let request = PortalApplyPermitRequest(
            startTime: Self.portalTimestamp(start),
            endTime: Self.portalTimestamp(end),
            note: reason
        )
        do {
            // Mutation: obtain a fresh token but never auto-replay.
            let token = try await coordinator.prepareForSensitiveAction()
            let response = try await api.applyPermit(request, token: token)
            if response.isSuccess {
                banner = (.success, response.displayMessage.isEmpty ? "Permit submitted." : response.displayMessage)
                await refresh()
            } else {
                banner = (.warning, response.displayMessage.isEmpty ? "Permit could not be submitted." : response.displayMessage)
            }
        } catch {
            handle(error, context: "apply")
        }
    }

    /// Open a gate. Non-idempotent → never auto-replayed. A timeout is surfaced
    /// as "outcome unknown" so the user verifies physically instead of retrying.
    func openGate(route: AccessRoute, gate: GateChoice) async {
        isWorking = true
        defer { isWorking = false }

        guard let door = DoorMatcher.match(gate, in: doors) else {
            banner = (.warning, "No matching gate was found. Refresh Access and try again.")
            return
        }
        do {
            let token = try await coordinator.prepareForSensitiveAction()
            let response = try await api.openDoor(recordId: route.recordId, doorKey: door.key, token: token)
            if response.isSuccess {
                banner = (.success, response.displayMessage.isEmpty ? "\(door.displayName) opened." : response.displayMessage)
            } else {
                banner = (.warning, response.displayMessage.isEmpty ? "The gate did not open." : response.displayMessage)
            }
        } catch PortalSessionError.mutationOutcomeUnknown {
            banner = (.warning, "The request timed out. Please check the gate physically before trying again.")
        } catch {
            handle(error, context: "open")
        }
    }

    func dismissBanner() { banner = nil }

    // MARK: - Helpers

    private func handle(_ error: Error, context: String) {
        guard let portalError = error as? PortalSessionError else {
            banner = (.error, "Access is temporarily unavailable.")
            return
        }
        switch portalError {
        case .networkUnavailable:
            banner = (.warning, "You appear to be offline.")
        case .serverUnavailable:
            banner = (.warning, "The school portal is temporarily unavailable.")
        case .unauthorized:
            banner = (.warning, "Your portal session expired. Please try again.")
        case .credentialsRejected:
            banner = (.error, "Your school password may have changed. Reconnect in Settings.")
        case .interactiveChallenge:
            banner = (.error, "The portal needs a manual sign-in. Open the School Portal to continue.")
        case .keychainUnavailable:
            banner = (.error, "Access needs your school sign-in. Reconnect in Settings.")
        case .incompatibleResponse:
            banner = (.error, "The school portal changed and Access needs an update.")
        case .mutationOutcomeUnknown:
            banner = (.warning, "The request timed out. Verify the gate physically before retrying.")
        }
    }

    static let portalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func portalTimestamp(_ date: Date) -> String { portalFormatter.string(from: date) }
}
