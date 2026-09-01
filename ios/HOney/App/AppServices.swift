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
    let experienceTargetRepository: ExperienceTargetRepository
    let portalAPI: PortalAPI
    let credentialVault: KeychainCredentialVault
    let portalCoordinator: PortalSessionCoordinator
    let ownershipKeyStore: any OwnershipKeyStoring
    let composerDraftStore: ComposerDraftStore
    let privateNoteStore: PrivateNoteStore
    let publishedKeyRecoveryStore: PublishedKeyRecoveryStore

    static func live(config: AppConfig = .default) -> AppServices {
        let sessionStore = SessionStore()
        let honeyAPI = HOneyAPI(baseURL: config.honeyBaseURL, store: sessionStore)
        let timetableRepository = TimetableRepository(provider: honeyAPI)
        let experienceTargetRepository = ExperienceTargetRepository(api: honeyAPI)
        let portalAPI = PortalAPI(baseURL: config.portalBaseURL)
        let vault = KeychainCredentialVault()
        let coordinator = PortalSessionCoordinator(api: portalAPI, vault: vault)
        return AppServices(
            config: config,
            sessionStore: sessionStore,
            honeyAPI: honeyAPI,
            timetableRepository: timetableRepository,
            experienceTargetRepository: experienceTargetRepository,
            portalAPI: portalAPI,
            credentialVault: vault,
            portalCoordinator: coordinator,
            ownershipKeyStore: OwnershipKeyStore(),
            composerDraftStore: ComposerDraftStore(),
            privateNoteStore: PrivateNoteStore(),
            publishedKeyRecoveryStore: PublishedKeyRecoveryStore()
        )
    }
}

struct ExperienceTargetMetadata: Sendable {
    let directory: DirectoryResponse?
    let names: [String: String]
    let isComplete: Bool

    static let empty = ExperienceTargetMetadata(directory: nil, names: [:], isComplete: false)
}

/// App-scoped, account-invalidated metadata used to name Experience targets.
/// Home, Experiences and My Posts share the same request and short-lived cache.
actor ExperienceTargetRepository {
    private struct Cached: Sendable {
        let value: ExperienceTargetMetadata
        let loadedAt: Date
    }

    private struct InFlight: Sendable {
        let scope: Int
        let task: Task<ExperienceTargetMetadata, Never>
    }

    private let api: HOneyAPI
    private let freshness: TimeInterval
    private let partialFreshness: TimeInterval
    private var cached: Cached?
    private var inFlight: InFlight?
    private var scope = 0

    init(api: HOneyAPI, freshness: TimeInterval = 15 * 60, partialFreshness: TimeInterval = 30) {
        self.api = api
        self.freshness = freshness
        self.partialFreshness = partialFreshness
    }

    func load(now: Date = .now) async -> ExperienceTargetMetadata {
        if let cached {
            let lifetime = cached.value.isComplete ? freshness : partialFreshness
            if now.timeIntervalSince(cached.loadedAt) < lifetime { return cached.value }
        }
        if let inFlight {
            let value = await inFlight.task.value
            return scope == inFlight.scope ? value : .empty
        }

        let api = api
        let requestScope = scope
        let task = Task {
            async let directoryAttempt: DirectoryResponse? = try? await api.directory()
            async let entitiesAttempt: EntitiesResponse? = try? await api.entities(type: nil, query: nil)
            let (directory, entities) = await (directoryAttempt, entitiesAttempt)
            return ExperienceTargetMetadata(
                directory: directory,
                names: ExperienceTargetNaming.names(directory: directory, entities: entities),
                isComplete: directory != nil && entities != nil
            )
        }
        inFlight = InFlight(scope: requestScope, task: task)
        let value = await task.value
        guard scope == requestScope else { return .empty }
        cached = Cached(value: value, loadedAt: now)
        inFlight = nil
        return value
    }

    func invalidate() {
        scope += 1
        inFlight?.task.cancel()
        inFlight = nil
        cached = nil
    }
}
