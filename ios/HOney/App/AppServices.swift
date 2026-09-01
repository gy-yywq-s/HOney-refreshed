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
    let experienceFeedRepository: ExperienceFeedRepository
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
        let experienceFeedRepository = ExperienceFeedRepository(provider: honeyAPI)
        let experienceTargetRepository = ExperienceTargetRepository(api: honeyAPI)
        let portalAPI = PortalAPI(baseURL: config.portalBaseURL)
        let vault = KeychainCredentialVault()
        let coordinator = PortalSessionCoordinator(api: portalAPI, vault: vault)
        return AppServices(
            config: config,
            sessionStore: sessionStore,
            honeyAPI: honeyAPI,
            timetableRepository: timetableRepository,
            experienceFeedRepository: experienceFeedRepository,
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
    let entities: [EntityRef]
    let names: [String: String]
    let isComplete: Bool

    static let empty = ExperienceTargetMetadata(directory: nil, entities: [], names: [:], isComplete: false)
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
                entities: entities?.entities ?? [],
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

// MARK: - Shared Experiences feed cache

protocol ExperienceFeedProviding: Sendable {
    func experiences(
        entityKey: String?,
        teacherId: String?,
        courseId: String?,
        roomId: String?,
        query: String?,
        sort: ExperienceSort
    ) async throws -> ExperiencesFeedResponse
    func fromMyClasses(before: Int?, limit: Int?) async throws -> ExperiencesFeedResponse
}

extension HOneyAPI: ExperienceFeedProviding {}

enum ExperienceFeedScope: Hashable, Sendable {
    case myClasses
    case school
}

/// Home and Experiences share these feeds so tab switches and view recreation
/// do not cause an avoidable request or a new loading screen. Pull-to-refresh
/// explicitly bypasses freshness; account and school-data changes invalidate it.
actor ExperienceFeedRepository {
    enum Policy: Sendable {
        case cacheFirst
        case reload
    }

    private struct Cached: Sendable {
        let response: ExperiencesFeedResponse
        let loadedAt: Date
    }

    private struct InFlight: Sendable {
        let generation: Int
        let task: Task<ExperiencesFeedResponse, Error>
    }

    private let provider: any ExperienceFeedProviding
    private let freshness: TimeInterval
    private var cache: [ExperienceFeedScope: Cached] = [:]
    private var inFlight: [ExperienceFeedScope: InFlight] = [:]
    private var generation = 0

    init(provider: any ExperienceFeedProviding, freshness: TimeInterval = 5 * 60) {
        self.provider = provider
        self.freshness = freshness
    }

    func load(
        _ scope: ExperienceFeedScope,
        policy: Policy = .cacheFirst,
        now: Date = .now
    ) async throws -> ExperiencesFeedResponse {
        if policy == .cacheFirst,
           let cached = cache[scope],
           now.timeIntervalSince(cached.loadedAt) < freshness {
            return cached.response
        }
        if let existing = inFlight[scope] {
            return try await existing.task.value
        }

        let requestGeneration = generation
        let provider = provider
        let task = Task<ExperiencesFeedResponse, Error> {
            switch scope {
            case .myClasses:
                return try await provider.fromMyClasses(before: nil, limit: 100)
            case .school:
                return try await provider.experiences(
                    entityKey: nil,
                    teacherId: nil,
                    courseId: nil,
                    roomId: nil,
                    query: nil,
                    sort: .newest
                )
            }
        }
        inFlight[scope] = InFlight(generation: requestGeneration, task: task)

        do {
            let response = try await task.value
            guard generation == requestGeneration else { throw CancellationError() }
            cache[scope] = Cached(response: response, loadedAt: now)
            inFlight[scope] = nil
            return response
        } catch {
            if inFlight[scope]?.generation == requestGeneration { inFlight[scope] = nil }
            throw error
        }
    }

    func invalidate() {
        generation += 1
        for request in inFlight.values { request.task.cancel() }
        inFlight.removeAll()
        cache.removeAll()
    }
}
