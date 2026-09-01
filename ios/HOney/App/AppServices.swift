//
//  AppServices.swift
//  HOney — dependency container wiring the service band together.
//

import Foundation

struct AppServices: Sendable {
    let config: AppConfig
    let sessionStore: SessionStore
    let honeyAPI: HOneyAPI
    let timetableRepository: TimetableRepository
    let portalAPI: PortalAPI
    let credentialVault: KeychainCredentialVault
    let portalCoordinator: PortalSessionCoordinator
    let ownershipKeyStore: any OwnershipKeyStoring
    let composerDraftStore: ComposerDraftStore
    let privateNoteStore: PrivateNoteStore

    static func live(config: AppConfig = .default) -> AppServices {
        let sessionStore = SessionStore()
        let honeyAPI = HOneyAPI(baseURL: config.honeyBaseURL, store: sessionStore)
        let timetableRepository = TimetableRepository(provider: honeyAPI)
        let portalAPI = PortalAPI(baseURL: config.portalBaseURL)
        let vault = KeychainCredentialVault()
        let coordinator = PortalSessionCoordinator(api: portalAPI, vault: vault)
        return AppServices(
            config: config,
            sessionStore: sessionStore,
            honeyAPI: honeyAPI,
            timetableRepository: timetableRepository,
            portalAPI: portalAPI,
            credentialVault: vault,
            portalCoordinator: coordinator,
            ownershipKeyStore: OwnershipKeyStore(),
            composerDraftStore: ComposerDraftStore(),
            privateNoteStore: PrivateNoteStore()
        )
    }
}
