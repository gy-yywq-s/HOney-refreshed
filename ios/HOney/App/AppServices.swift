//
//  AppServices.swift
//  HOney — dependency container wiring the service band together.
//

import Foundation

struct AppServices: Sendable {
    let config: AppConfig
    let sessionStore: SessionStore
    let honeyAPI: HOneyAPI
    let nextLessonRepository: NextLessonRepository
    let historyRepository: HistoryRepository
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
        let nextLessonRepository = NextLessonRepository(provider: honeyAPI)
        let historyRepository = HistoryRepository(provider: honeyAPI)
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
            nextLessonRepository: nextLessonRepository,
            historyRepository: historyRepository,
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

// MARK: - Home and History caches

protocol NextLessonProviding: Sendable {
    func nextLesson() async throws -> NextLessonResponse
}

protocol HistoryProviding: Sendable {
    func history(
        query: String?,
        teacherId: String?,
        courseId: String?,
        order: String?
    ) async throws -> HistoryResponse
}

extension HOneyAPI: NextLessonProviding, HistoryProviding {}

actor NextLessonRepository {
    enum Policy: Equatable, Sendable {
        case cacheFirst
        case reload
    }

    private struct Cached: Sendable {
        let response: NextLessonResponse
        let loadedAt: Date
    }

    private struct InFlight: Sendable {
        let generation: Int
        let task: Task<NextLessonResponse, Error>
    }

    private let provider: any NextLessonProviding
    private let freshness: TimeInterval
    private var cached: Cached?
    private var inFlight: InFlight?
    private var generation = 0

    init(provider: any NextLessonProviding, freshness: TimeInterval = 60) {
        self.provider = provider
        self.freshness = freshness
    }

    func load(_ policy: Policy = .cacheFirst, now: Date = .now) async throws -> NextLessonResponse {
        if policy == .cacheFirst,
           let cached,
           now.timeIntervalSince(cached.loadedAt) < freshness {
            return cached.response
        }
        if let inFlight { return try await inFlight.task.value }

        let requestGeneration = generation
        let provider = provider
        let task = Task { try await provider.nextLesson() }
        inFlight = InFlight(generation: requestGeneration, task: task)
        do {
            let response = try await task.value
            guard generation == requestGeneration else { throw CancellationError() }
            cached = Cached(response: response, loadedAt: now)
            inFlight = nil
            return response
        } catch {
            if inFlight?.generation == requestGeneration { inFlight = nil }
            throw error
        }
    }

    func invalidate() {
        generation += 1
        inFlight?.task.cancel()
        inFlight = nil
        cached = nil
    }
}

struct HistoryCacheKey: Hashable, Sendable {
    let query: String?
    let teacherId: String?
    let courseId: String?
    let order: String?

    init(query: String?, teacherId: String?, courseId: String?, order: String?) {
        let cleaned = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.query = cleaned?.isEmpty == false ? cleaned : nil
        self.teacherId = teacherId
        self.courseId = courseId
        self.order = order
    }
}

actor HistoryRepository {
    enum Policy: Equatable, Sendable {
        case cacheFirst
        case reload
    }

    private struct Cached: Sendable {
        let response: HistoryResponse
        let loadedAt: Date
    }

    private struct InFlight: Sendable {
        let generation: Int
        let task: Task<HistoryResponse, Error>
    }

    private let provider: any HistoryProviding
    private let freshness: TimeInterval
    private var cache: [HistoryCacheKey: Cached] = [:]
    private var inFlight: [HistoryCacheKey: InFlight] = [:]
    private var generation = 0

    init(provider: any HistoryProviding, freshness: TimeInterval = 10 * 60) {
        self.provider = provider
        self.freshness = freshness
    }

    func load(
        key: HistoryCacheKey,
        policy: Policy = .cacheFirst,
        now: Date = .now
    ) async throws -> HistoryResponse {
        if policy == .cacheFirst,
           let cached = cache[key],
           now.timeIntervalSince(cached.loadedAt) < freshness {
            return cached.response
        }
        if let request = inFlight[key] { return try await request.task.value }

        let requestGeneration = generation
        let provider = provider
        let task = Task {
            try await provider.history(
                query: key.query,
                teacherId: key.teacherId,
                courseId: key.courseId,
                order: key.order
            )
        }
        inFlight[key] = InFlight(generation: requestGeneration, task: task)
        do {
            let response = try await task.value
            guard generation == requestGeneration else { throw CancellationError() }
            cache[key] = Cached(response: response, loadedAt: now)
            inFlight[key] = nil
            return response
        } catch {
            if inFlight[key]?.generation == requestGeneration { inFlight[key] = nil }
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

struct ExperienceTargetMetadata: Sendable {
    let directory: DirectoryResponse?
    let entities: [EntityRef]
    let names: [String: String]
    let directoryRequestSucceeded: Bool
    let entitiesRequestSucceeded: Bool
    let isComplete: Bool

    static let empty = ExperienceTargetMetadata(
        directory: nil,
        entities: [],
        names: [:],
        directoryRequestSucceeded: false,
        entitiesRequestSucceeded: false,
        isComplete: false
    )
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
            async let directoryAttempt: (DirectoryResponse?, Bool) = {
                do { return (try await api.directory(), true) }
                catch { return (nil, false) }
            }()
            async let entitiesAttempt: (EntitiesResponse?, Bool) = {
                do { return (try await api.entities(type: nil, query: nil), true) }
                catch { return (nil, false) }
            }()
            let (directory, entities) = await (directoryAttempt, entitiesAttempt)
            return ExperienceTargetMetadata(
                directory: directory.0,
                entities: entities.0?.entities ?? [],
                names: ExperienceTargetNaming.names(directory: directory.0, entities: entities.0),
                directoryRequestSucceeded: directory.1,
                entitiesRequestSucceeded: entities.1,
                isComplete: directory.1 && entities.1
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
    case entity(String)
    case teacher(String)
    case course(String)
    case room(String)
}

/// Home and Experiences share these feeds so tab switches and view recreation
/// do not cause an avoidable request or a new loading screen. An explicit local
/// refresh bypasses freshness; account and school-data changes invalidate it.
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
            case .entity(let entityKey):
                return try await provider.experiences(
                    entityKey: entityKey,
                    teacherId: nil,
                    courseId: nil,
                    roomId: nil,
                    query: nil,
                    sort: .newest
                )
            case .teacher(let teacherId):
                return try await provider.experiences(
                    entityKey: nil,
                    teacherId: teacherId,
                    courseId: nil,
                    roomId: nil,
                    query: nil,
                    sort: .newest
                )
            case .course(let courseId):
                return try await provider.experiences(
                    entityKey: nil,
                    teacherId: nil,
                    courseId: courseId,
                    roomId: nil,
                    query: nil,
                    sort: .newest
                )
            case .room(let roomId):
                return try await provider.experiences(
                    entityKey: nil,
                    teacherId: nil,
                    courseId: nil,
                    roomId: roomId,
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
