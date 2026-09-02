// App-wide read cache for school data (spec §3.4): day / week / next lesson
// / directory / entities / history, coalesced in-flight requests, cached
// content painting before refresh. Every request captures the generation it
// started in; invalidation (school sync, account change, sign-out) bumps
// the generation and cancels in-flight work, so a late response can never
// write into the cache of a newer generation or another account
// (review 11d42e3 §3.1.4).

import Foundation

public protocol TimetableProviding: Sendable {
    func timetable(date: String) async throws -> TimetableResponse
    func timetableRange(from: String, to: String) async throws -> TimetableRangeResponse
    func nextLesson() async throws -> NextLessonResponse
    func directory() async throws -> DirectoryResponse
    func entities(type: EntityType?, q: String?) async throws -> EntitiesResponse
    func history(_ params: HistoryParams) async throws -> HistoryResponse
}

extension APIClient: TimetableProviding {}

public actor TimetableRepository {
    private let provider: TimetableProviding
    private var days: [String: TimetableResponse] = [:]
    private var weeks: [String: TimetableRangeResponse] = [:]
    private var nextLesson: NextLessonResponse?
    private var directoryCache: DirectoryResponse?
    private var entitiesCache: EntitiesResponse?
    private var histories: [String: HistoryResponse] = [:]
    private var inflight: [String: (generation: Int, task: Task<any Sendable, Error>)] = [:]
    public private(set) var generation = 0

    public init(provider: TimetableProviding) {
        self.provider = provider
    }

    public func cachedDay(_ date: String) -> TimetableResponse? { days[date] }
    public func cachedWeek(_ monday: String) -> TimetableRangeResponse? { weeks[monday] }
    public func cachedNextLesson() -> NextLessonResponse? { nextLesson }
    public func cachedDirectory() -> DirectoryResponse? { directoryCache }
    public func cachedEntities() -> EntitiesResponse? { entitiesCache }

    public func day(_ date: String, reload: Bool = false) async throws -> TimetableResponse {
        if !reload, let cached = days[date] { return cached }
        let provider = self.provider
        let value: TimetableResponse = try await coalesce("day:\(date)") { try await provider.timetable(date: date) }
        days[date] = value
        return value
    }

    public func week(monday: String, reload: Bool = false) async throws -> TimetableRangeResponse {
        if !reload, let cached = weeks[monday] { return cached }
        let provider = self.provider
        let value: TimetableRangeResponse = try await coalesce("week:\(monday)") {
            try await provider.timetableRange(from: monday, to: Formatters.shiftIsoDate(monday, days: 6))
        }
        weeks[monday] = value
        return value
    }

    public func next(reload: Bool = false) async throws -> NextLessonResponse {
        if !reload, let cached = nextLesson { return cached }
        let provider = self.provider
        let value: NextLessonResponse = try await coalesce("next") { try await provider.nextLesson() }
        nextLesson = value
        return value
    }

    public func directory(reload: Bool = false) async throws -> DirectoryResponse {
        if !reload, let cached = directoryCache { return cached }
        let provider = self.provider
        let value: DirectoryResponse = try await coalesce("directory") { try await provider.directory() }
        directoryCache = value
        return value
    }

    public func entities(reload: Bool = false) async throws -> EntitiesResponse {
        if !reload, let cached = entitiesCache { return cached }
        let provider = self.provider
        let value: EntitiesResponse = try await coalesce("entities") { try await provider.entities(type: nil, q: nil) }
        entitiesCache = value
        return value
    }

    public func history(_ params: HistoryParams, reload: Bool = false) async throws -> HistoryResponse {
        let key = "history:\(params.q ?? "")|\(params.teacherId ?? "")|\(params.courseId ?? "")|\(params.before ?? "")|\(params.limit ?? 0)|\(params.order?.rawValue ?? "")"
        if !reload, let cached = histories[key] { return cached }
        let provider = self.provider
        let value: HistoryResponse = try await coalesce(key) { try await provider.history(params) }
        histories[key] = value
        return value
    }

    /// After a school sync, an account change or sign-out: drop everything,
    /// cancel what is in flight, and move to a generation no late response
    /// can write into.
    public func invalidateAll() {
        generation += 1
        for (_, entry) in inflight { entry.task.cancel() }
        inflight.removeAll()
        days.removeAll()
        weeks.removeAll()
        nextLesson = nil
        directoryCache = nil
        histories.removeAll()
        entitiesCache = nil
    }

    /// The community registry changed (a publish): only entities refetch.
    public func invalidateEntities() {
        entitiesCache = nil
    }

    /// Runs `work` once per key per generation; concurrent callers share the
    /// task. Throws CancellationError when the generation moved on before
    /// the response arrived, so callers never see another generation's data.
    private func coalesce<T: Sendable>(_ key: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let startGeneration = generation
        if let existing = inflight[key], existing.generation == startGeneration {
            let value = try await existing.task.value
            guard generation == startGeneration else { throw CancellationError() }
            return value as! T
        }
        let task = Task<any Sendable, Error> {
            try Task.checkCancellation()
            let value = try await work()
            try Task.checkCancellation()
            return value as any Sendable
        }
        inflight[key] = (startGeneration, task)
        defer {
            if inflight[key]?.generation == startGeneration { inflight[key] = nil }
        }
        let value = try await task.value
        guard generation == startGeneration else { throw CancellationError() }
        return value as! T
    }
}
