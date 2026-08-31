//
//  AppModel.swift
//  HOney — top-level session controller (Band 1). Gates RootView on auth.
//

import Foundation
import Observation

enum AuthPhase: Equatable {
    case loading
    case signedOut
    case signedIn(HoneyProfile)
}

@MainActor
@Observable
final class AppModel {
    let services: AppServices
    var phase: AuthPhase = .loading
    var loginError: String?
    var isAuthenticating = false

    init(services: AppServices = .live()) {
        self.services = services
    }

    var profile: HoneyProfile? {
        if case .signedIn(let profile) = phase { return profile }
        return nil
    }

    /// Restore an existing session on launch; kick off the portal connector's
    /// silent restore in the background.
    func bootstrap() async {
        Task { await services.portalCoordinator.restore() }

        guard await services.sessionStore.current() != nil else {
            phase = .signedOut
            return
        }
        do {
            let me = try await services.honeyAPI.me()
            phase = .signedIn(me.profile)
        } catch {
            // Token unusable and refresh failed → signed out.
            phase = .signedOut
        }
    }

    func login(username: String, password: String, consentTimetable: Bool) async {
        isAuthenticating = true
        loginError = nil
        defer { isAuthenticating = false }
        do {
            let response = try await services.honeyAPI.login(
                username: username,
                password: password,
                consentTimetable: consentTimetable
            )
            // Authorize the portal connector to silently re-login for Access using
            // the same school credentials (device-only Keychain, not biometric).
            try? await services.portalCoordinator.authorizeCredentials(
                PortalCredentials(username: username, password: password)
            )
            phase = .signedIn(response.profile)
        } catch HoneyAPIError.http(let status, _) where status == 401 {
            loginError = "Incorrect school account or password."
        } catch {
            loginError = "Could not sign in. Please check your connection and try again."
        }
    }

    func updateConsent(timetable: Bool) async {
        guard var profile else { return }
        do {
            try await services.honeyAPI.setConsent(timetable: timetable)
            profile.consent.timetable = timetable
            phase = .signedIn(profile)
        } catch {
            // Leave the previous value; the toggle re-syncs on next appearance.
        }
    }

    func signOut() async {
        await services.honeyAPI.logout()
        await services.ownershipKeyStore.clear()
        phase = .signedOut
    }

    /// Account deletion is a server operation; here we clear local state and drop
    /// to signed-out. (The backend delete endpoint is invoked server-side.)
    func deleteAccount() async {
        await services.honeyAPI.logout()
        await services.sessionStore.clear()
        await services.ownershipKeyStore.clear()
        phase = .signedOut
    }
}
