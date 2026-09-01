//
//  TimetableRepository.swift
//  HOney — app-wide day cache, request coalescing and invalidation.
//

import Foundation

protocol TimetableProviding: Sendable {
    func timetable(date: String) async throws -> TimetableResponse
}

extension HOneyAPI: TimetableProviding {}

struct CachedTimetableDay: Sendable {
    let response: TimetableResponse
    let isFresh: Bool
}

actor TimetableRepository {
    enum Policy: Sendable {
        case cacheFirst
        case reload
    }

    private struct Entry: Sendable {
        let response: TimetableResponse
        let loadedAt: Date
        var lastAccessedAt: Date
    }

    private struct InFlight: Sendable {
        let generation: UUID
        let scopeGeneration: Int
        let task: Task<TimetableResponse, Error>
    }

    private let provider: any TimetableProviding
    private let freshness: TimeInterval
    private let capacity: Int
    private var cache: [String: Entry] = [:]
    private var inFlight: [String: InFlight] = [:]
    private var scopeGeneration = 0

    init(
        provider: any TimetableProviding,
        freshness: TimeInterval = 10 * 60,
        capacity: Int = 45
    ) {
        self.provider = provider
        self.freshness = freshness
        self.capacity = max(7, capacity)
    }

    func cached(date: String, now: Date = .now) -> CachedTimetableDay? {
        guard var entry = cache[date] else { return nil }
        entry.lastAccessedAt = now
        cache[date] = entry
        return CachedTimetableDay(
            response: entry.response,
            isFresh: now.timeIntervalSince(entry.loadedAt) < freshness
        )
    }

    func load(date: String, policy: Policy = .cacheFirst, now: Date = .now) async throws -> TimetableResponse {
        if policy == .cacheFirst,
           let cached = cached(date: date, now: now), cached.isFresh {
            return cached.response
        }

        if let existing = inFlight[date] {
            return try await existing.task.value
        }

        let provider = self.provider
        let generation = UUID()
        let requestScope = scopeGeneration
        let task = Task<TimetableResponse, Error> {
            try Task.checkCancellation()
            let response = try await provider.timetable(date: date)
            try Task.checkCancellation()
            return response
        }
        inFlight[date] = InFlight(generation: generation, scopeGeneration: requestScope, task: task)

        do {
            let response = try await task.value
            guard inFlight[date]?.generation == generation,
                  inFlight[date]?.scopeGeneration == requestScope,
                  scopeGeneration == requestScope else {
                throw CancellationError()
            }
            inFlight[date] = nil
            let completedAt = Date()
            cache[date] = Entry(response: response, loadedAt: completedAt, lastAccessedAt: completedAt)
            evictIfNeeded()
            return response
        } catch {
            if inFlight[date]?.generation == generation { inFlight[date] = nil }
            throw error
        }
    }

    func invalidateAll() {
        scopeGeneration += 1
        for request in inFlight.values { request.task.cancel() }
        inFlight.removeAll()
        cache.removeAll()
    }

    func cachedDateCount() -> Int { cache.count }

    private func evictIfNeeded() {
        guard cache.count > capacity else { return }
        let overflow = cache.count - capacity
        let oldest = cache.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }.prefix(overflow)
        for (key, _) in oldest { cache.removeValue(forKey: key) }
    }
}
