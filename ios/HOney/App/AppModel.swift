//
//  AppModel.swift
//  HOney — top-level session controller (Band 1). Gates RootView on auth.
//

import Foundation
import Observation

enum AuthPhase: Equatable {
    case loading
    case startupUnavailable
    case signedOut
    /// Authenticated, but the separate import-consent step (audit §3.2) is
    /// still pending: signing in and copying school data are different decisions.
    case consentPending(HOneyProfile)
    case signedIn(HOneyProfile)
}

enum AccountDeletionResult: Equatable {
    case complete
    case serverFailed
    case localCleanupIncomplete([String])
}

@MainActor
@Observable
final class AppModel {
    let services: AppServices
    var phase: AuthPhase = .loading
    var loginError: String?
    var isAuthenticating = false
    var consentError: String?
    var isSavingConsent = false
    var startupNotice: String?
    var portalCredentialNotice: String?

    init(services: AppServices = .live()) {
        self.services = services
    }

    var profile: HOneyProfile? {
        if case .signedIn(let profile) = phase { return profile }
        return nil
    }

    /// Restore an existing session on launch; kick off the portal connector's
    /// silent restore in the background.
    func bootstrap() async {
        phase = .loading
        Task { await services.portalCoordinator.restore() }

        guard await services.sessionStore.current() != nil else {
            await services.timetableRepository.invalidateAll()
            await services.nextLessonRepository.invalidate()
            await services.historyRepository.invalidate()
            await services.experienceFeedRepository.invalidate()
            await services.experienceTargetRepository.invalidate()
            startupNotice = nil
            portalCredentialNotice = nil
            phase = .signedOut
            return
        }
        do {
            let me = try await services.honeyAPI.me()
            startupNotice = nil
            phase = .signedIn(me.profile)
        } catch HOneyAPIError.notAuthenticated {
            await invalidateAccountCaches()
            phase = .signedOut
        } catch HOneyAPIError.http(let status, _) where status == 401 {
            await invalidateAccountCaches()
            phase = .signedOut
        } catch {
            // A temporary network/server failure is not a sign-out. Keep the
            // session and offer an honest retry instead of asking for a password.
            startupNotice = "HOney could not check your saved session. Your sign-in is still on this iPhone."
            phase = .startupUnavailable
        }
    }

    private func invalidateAccountCaches() async {
        await services.timetableRepository.invalidateAll()
        await services.nextLessonRepository.invalidate()
        await services.historyRepository.invalidate()
        await services.experienceFeedRepository.invalidate()
        await services.experienceTargetRepository.invalidate()
    }

    func login(username: String, password: String) async {
        isAuthenticating = true
        loginError = nil
        startupNotice = nil
        portalCredentialNotice = nil
        await services.timetableRepository.invalidateAll()
        await services.nextLessonRepository.invalidate()
        await services.historyRepository.invalidate()
        await services.experienceFeedRepository.invalidate()
        await services.experienceTargetRepository.invalidate()
        defer { isAuthenticating = false }
        do {
            // Signing in never imports the timetable: the request carries no
            // consent (audit §3.2). Import is a separate, active choice on the
            // next step, with nothing preselected.
            let response = try await services.honeyAPI.login(username: username, password: password)
            // Authorize the portal connector to silently re-login for Access using
            // the same school credentials (device-only Keychain, not biometric).
            do {
                try await services.portalCoordinator.authorizeCredentials(
                    PortalCredentials(username: username, password: password)
                )
            } catch {
                portalCredentialNotice = "Signed in to HOney, but this iPhone could not save the school sign-in for silent Portal and Access reconnection."
            }
            if response.profile.consent.timetable {
                // Already granted on a previous device/session — skip the step.
                phase = .signedIn(response.profile)
            } else {
                phase = .consentPending(response.profile)
            }
        } catch HOneyAPIError.http(let status, _) where status == 401 {
            loginError = "Incorrect school account or password."
        } catch {
            loginError = "Could not sign in. Please check your connection and try again."
        }
    }

    /// The import-consent step's active choice. "Import" grants consent and runs
    /// the initial sync (so Home has data on first render); "Not now" leaves
    /// consent off — it can be turned on any time in Settings.
    func completeImportConsent(importTimetable: Bool) async {
        guard case .consentPending(var profile) = phase else { return }
        isSavingConsent = true
        consentError = nil
        defer { isSavingConsent = false }
        if importTimetable {
            do {
                try await services.honeyAPI.setConsent(timetable: true)
            } catch {
                consentError = "Could not turn on the import. Please check your connection and try again."
                return
            }
            do {
                _ = try await services.honeyAPI.sync()
                await services.timetableRepository.invalidateAll()
                await services.nextLessonRepository.invalidate()
                await services.historyRepository.invalidate()
                await services.experienceFeedRepository.invalidate()
                await services.experienceTargetRepository.invalidate()
                startupNotice = nil
            } catch {
                startupNotice = "Import is on, but the first school-data sync failed. Use Refresh Home to retry."
            }
            profile.consent.timetable = true
        }
        // Refresh the profile like the web step; fall back to the local copy.
        if let me = try? await services.honeyAPI.me() {
            phase = .signedIn(me.profile)
        } else {
            phase = .signedIn(profile)
        }
    }

    @discardableResult
    func updateConsent(timetable: Bool) async -> Bool {
        guard var profile else { return false }
        do {
            try await services.honeyAPI.setConsent(timetable: timetable)
            profile.consent.timetable = timetable
            phase = .signedIn(profile)
            if !timetable {
                await services.timetableRepository.invalidateAll()
                await services.nextLessonRepository.invalidate()
                await services.historyRepository.invalidate()
                await services.experienceFeedRepository.invalidate()
                await services.experienceTargetRepository.invalidate()
            }
            return true
        } catch {
            return false
        }
    }

    func retryStartupSyncIfNeeded() async {
        guard startupNotice != nil else { return }
        do {
            _ = try await services.honeyAPI.sync()
            await services.timetableRepository.invalidateAll()
            await services.nextLessonRepository.invalidate()
            await services.historyRepository.invalidate()
            await services.experienceFeedRepository.invalidate()
            await services.experienceTargetRepository.invalidate()
            startupNotice = nil
        } catch {
            startupNotice = "Import is on, but school data still could not sync. Use Refresh Home to try again."
        }
    }

    /// Re-fetch the profile (incl. live school-connection state) from the server.
    @discardableResult
    func refreshProfile() async -> Bool {
        do {
            let me = try await services.honeyAPI.me()
            phase = .signedIn(me.profile)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func disconnectSchool() async -> Bool {
        do {
            try await services.honeyAPI.disconnectSchool()
            await services.timetableRepository.invalidateAll()
            await services.nextLessonRepository.invalidate()
            await services.historyRepository.invalidate()
            await services.experienceFeedRepository.invalidate()
            await services.experienceTargetRepository.invalidate()
            if !(await refreshProfile()), var profile {
                profile.connection = HOneyConnection(
                    connected: false,
                    lastSyncedAt: profile.connection?.lastSyncedAt,
                    portalTokenValid: false
                )
                phase = .signedIn(profile)
            }
            return true
        } catch {
            return false
        }
    }

    func signOut() async {
        await services.honeyAPI.logout()
        await services.timetableRepository.invalidateAll()
        await services.nextLessonRepository.invalidate()
        await services.historyRepository.invalidate()
        await services.experienceFeedRepository.invalidate()
        await services.experienceTargetRepository.invalidate()
        // Ownership keys, private notes and drafts are the user's device-local
        // property, not session state — an ordinary sign-out never deletes them
        // (audit §3.6). Only "delete account + erase everything" does.
        phase = .signedOut
        startupNotice = nil
        portalCredentialNotice = nil
    }

    /// Account deletion is a server operation. Ownership keys are the ONLY
    /// control over past anonymous posts, so the caller must pass the user's
    /// explicit choice: keep the device-local keys (still able to revoke posts
    /// later) or erase everything (keys, private notes and drafts).
    @discardableResult
    func deleteAccount(eraseLocalData: Bool) async -> AccountDeletionResult {
        do {
            try await services.honeyAPI.deleteAccount()
        } catch {
            return .serverFailed
        }

        await services.timetableRepository.invalidateAll()
        await services.nextLessonRepository.invalidate()
        await services.historyRepository.invalidate()
        await services.experienceFeedRepository.invalidate()
        await services.experienceTargetRepository.invalidate()
        var remaining: [String] = []
        do { try await services.sessionStore.clear() }
        catch { remaining.append("HOney session") }
        if eraseLocalData {
            do { try await services.ownershipKeyStore.clear() }
            catch { remaining.append("post-control keys") }
            do { try await services.privateNoteStore.clearAll() }
            catch { remaining.append("private notes") }
            do { try await services.composerDraftStore.clearAll() }
            catch { remaining.append("drafts") }
            do { try await services.publishedKeyRecoveryStore.clearAll() }
            catch { remaining.append("published-key recovery record") }
            do { try await services.portalCoordinator.clearSavedCredentials() }
            catch { remaining.append("saved school sign-in") }
        }
        phase = .signedOut
        startupNotice = nil
        portalCredentialNotice = nil
        if remaining.isEmpty { return .complete }

        loginError = "Your HOney account was deleted, but this iPhone could not erase: "
            + remaining.joined(separator: ", ") + "."
        return .localCleanupIncomplete(remaining)
    }
}
