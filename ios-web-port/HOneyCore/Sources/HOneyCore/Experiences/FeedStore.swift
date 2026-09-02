// The Experiences stream's paging state (Web: useFeedController.ts), kept
// per key (scope + entity filters) for the life of the app so leaving and
// returning lands the reader where they were. Every write is tagged with
// the key and generation it belongs to: a scope switch or invalidation
// mid-flight drops the stale page instead of mixing cursors.

import Foundation

public struct FeedKey: Sendable, Hashable, Equatable {
    public var scope: FeedScope
    public var entityKey: String?
    public var teacherId: String?
    public var courseId: String?
    public var roomId: String?

    public init(scope: FeedScope, entityKey: String? = nil, teacherId: String? = nil, courseId: String? = nil, roomId: String? = nil) {
        self.scope = scope
        self.entityKey = entityKey
        self.teacherId = teacherId
        self.courseId = courseId
        self.roomId = roomId
    }

    public func params(cursor: String? = nil, limit: Int? = nil) -> FeedParams {
        FeedParams(scope: scope, cursor: cursor, limit: limit, entityKey: entityKey, teacherId: teacherId, courseId: courseId, roomId: roomId)
    }
}

public struct FeedState: Sendable, Equatable {
    public var items: [PublicExperience] = []
    public var nextCursor: String?
    public var headCursor: String?
    /// True once page one applied — only then is the state worth restoring.
    public var loaded = false
    public var end: Bool { loaded && nextCursor == nil }
    /// The post the reader was at when they left (scroll restoration anchor).
    public var anchorId: String?

    public init() {}

    mutating func apply(_ page: FeedPage, mode: ApplyMode) {
        var base = mode == .replace ? [] : items
        var seen = Set(base.map(\.id))
        for item in page.items where !seen.contains(item.id) {
            seen.insert(item.id)
            base.append(item)
        }
        items = base
        nextCursor = page.nextCursor
        if let head = page.headCursor { headCursor = head }
        loaded = true
    }

    enum ApplyMode { case replace, append }
}

public actor FeedStore {
    private var states: [FeedKey: FeedState] = [:]
    private var generations: [FeedKey: Int] = [:]
    private var inflightFirst: [FeedKey: Task<FeedState, Error>] = [:]
    private var loadingMore: Set<FeedKey> = []

    public init() {}

    public func state(for key: FeedKey) -> FeedState? {
        guard let s = states[key], s.loaded, !s.items.isEmpty else { return nil }
        return s
    }

    public func rememberAnchor(_ id: String?, for key: FeedKey) {
        guard states[key] != nil else { return }
        states[key]?.anchorId = id
    }

    /// Page one. Concurrent callers for the same key share one request.
    public func loadFirst(_ key: FeedKey, using fetch: @escaping @Sendable (FeedParams) async throws -> FeedPage) async throws -> FeedState {
        if let task = inflightFirst[key] { return try await task.value }
        let generation = bump(key)
        let task = Task<FeedState, Error> {
            let page = try await fetch(key.params())
            return try await self.applyFirst(page, key: key, generation: generation)
        }
        inflightFirst[key] = task
        defer { inflightFirst[key] = nil }
        return try await task.value
    }

    private func applyFirst(_ page: FeedPage, key: FeedKey, generation: Int) throws -> FeedState {
        guard generations[key] == generation else { throw CancellationError() }
        var state = FeedState()
        state.apply(page, mode: .replace)
        states[key] = state
        return state
    }

    /// The next page, if there is one and none is in flight. Returns the
    /// merged state, or nil when nothing was fetched.
    public func loadMore(_ key: FeedKey, using fetch: @escaping @Sendable (FeedParams) async throws -> FeedPage) async throws -> FeedState? {
        guard let current = states[key], let cursor = current.nextCursor, !loadingMore.contains(key) else { return nil }
        let generation = generations[key] ?? 0
        loadingMore.insert(key)
        defer { loadingMore.remove(key) }
        let page = try await fetch(key.params(cursor: cursor))
        guard generations[key] == generation, var state = states[key] else { throw CancellationError() }
        state.apply(page, mode: .append)
        states[key] = state
        return state
    }

    /// The head cursor to probe /feed/updates with, if page one has loaded.
    public func headCursor(for key: FeedKey) -> String? {
        states[key]?.headCursor
    }

    /// A reaction result from the server is authoritative everywhere the
    /// post appears (stream, entity page, search).
    public func applyReaction(experienceId: String, value: Int, counts: ReactionCounts?) {
        for (key, var state) in states {
            var changed = false
            for i in state.items.indices where state.items[i].id == experienceId {
                state.items[i].myReaction = value
                state.items[i].reactions = counts
                changed = true
            }
            if changed { states[key] = state }
        }
    }

    /// After a publish or revoke: every stream refetches on next visit.
    public func invalidateAll() {
        // Every key that ever loaded OR is loading right now moves on, so an
        // in-flight first page from before the invalidation is dropped too.
        for key in Set(generations.keys).union(inflightFirst.keys) { _ = bump(key) }
        states.removeAll()
        inflightFirst.removeAll()
        loadingMore.removeAll()
    }

    private func bump(_ key: FeedKey) -> Int {
        let next = (generations[key] ?? 0) + 1
        generations[key] = next
        return next
    }
}

/// One post's reaction, optimistic then authoritative (Web: ExperiencePost.tsx).
public struct ReactionState: Sendable, Equatable {
    public var myValue: Int
    public var counts: ReactionCounts?
    public var pending: Int = 0
    public var note: String?

    public init(myValue: Int, counts: ReactionCounts?) {
        self.myValue = myValue
        self.counts = counts
    }

    public init(_ exp: PublicExperience) {
        self.init(myValue: exp.myReaction ?? 0, counts: exp.reactions)
    }

    public var busy: Bool { pending != 0 }

    /// The value to send when the student taps `value`: a second tap on the
    /// active reaction clears it.
    public func next(for value: Int) -> Int { myValue == value ? 0 : value }

    /// Optimistic step; returns the previous state for rollback.
    public mutating func begin(_ value: Int) -> ReactionState {
        let previous = self
        pending = value
        note = nil
        myValue = next(for: value)
        return previous
    }

    public mutating func accept(_ result: ReactResponse) {
        myValue = result.value
        counts = result.reactions
        pending = 0
    }

    public mutating func rollback(to previous: ReactionState, note: String) {
        myValue = previous.myValue
        counts = previous.counts
        pending = 0
        self.note = note
    }
}
