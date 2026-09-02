// The stream's behaviour (spec §11): cursor pagination, per-scope state
// restoration, the quiet new-posts probe, reactions with optimistic +
// authoritative + rollback, category-only reports. Shared by the Stream,
// entity pages and search results through FeedKey.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class FeedViewModel {
    private let env: AppEnvironment
    private(set) var key: FeedKey
    private(set) var items: [PublicExperience] = []
    private(set) var loading = true
    private(set) var loadingMore = false
    private(set) var error: String?
    private(set) var end = false
    private(set) var newAvailable = false
    private(set) var reactions: [String: ReactionState] = [:]
    var restoreAnchorId: String?
    private var probe: Task<Void, Never>?
    private var generation = 0

    init(env: AppEnvironment, key: FeedKey) {
        self.env = env
        self.key = key
    }

    func switchScope(_ scope: FeedScope) async {
        guard scope != key.scope else { return }
        await env.feedStore.rememberAnchor(restoreAnchorId, for: key)
        key = FeedKey(scope: scope, entityKey: key.entityKey, teacherId: key.teacherId, courseId: key.courseId, roomId: key.roomId)
        env.prefs.feedScope = scope
        await enter()
    }

    /// On appear: restore the remembered state for this key or fetch page one.
    func enter() async {
        generation += 1
        let gen = generation
        newAvailable = false
        error = nil
        if let restored = await env.feedStore.state(for: key) {
            apply(restored)
            restoreAnchorId = restored.anchorId
            loading = false
        } else {
            items = []
            end = false
            loading = true
            await loadFirst(generation: gen)
        }
        startProbe()
    }

    func leave() async {
        probe?.cancel()
        probe = nil
        await env.feedStore.rememberAnchor(restoreAnchorId, for: key)
    }

    func refresh() async {
        generation += 1
        newAvailable = false
        await loadFirst(generation: generation)
    }

    private func loadFirst(generation gen: Int) async {
        let api = env.api
        do {
            let state = try await env.feedStore.loadFirst(key) { try await api.feedPage($0) }
            guard gen == generation else { return }
            apply(state)
            error = nil
        } catch is CancellationError {
        } catch {
            guard gen == generation else { return }
            if items.isEmpty { self.error = APIErrorCopy.describe(error) }
        }
        if gen == generation { loading = false }
    }

    func loadMoreIfNeeded(current: PublicExperience) async {
        guard !loadingMore, !end, let last = items.last, last.id == current.id else { return }
        loadingMore = true
        let api = env.api
        let gen = generation
        do {
            if let state = try await env.feedStore.loadMore(key, using: { try await api.feedPage($0) }), gen == generation {
                apply(state)
            }
        } catch {
            // quiet — the next appearance of the last row retries
        }
        loadingMore = false
    }

    private func apply(_ state: FeedState) {
        items = state.items
        end = state.end
        for item in state.items where reactions[item.id] == nil {
            reactions[item.id] = ReactionState(item)
        }
        for item in state.items {
            // Server state wins after an authoritative update elsewhere.
            if var r = reactions[item.id], !r.busy, r.myValue != (item.myReaction ?? 0) || r.counts != item.reactions {
                r.myValue = item.myReaction ?? 0
                r.counts = item.reactions
                reactions[item.id] = r
            }
        }
    }

    /// The banner action: back to the top of a fresh stream.
    func jumpToNew() async {
        restoreAnchorId = nil
        await refresh()
    }

    private func startProbe() {
        probe?.cancel()
        let api = env.api
        let store = env.feedStore
        let key = key
        probe = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let head = await store.headCursor(for: key) else { continue }
                if let res = try? await api.feedUpdates(scope: key.scope, head: head), res.newItemsAvailable {
                    await MainActor.run { self?.newAvailable = true }
                }
            }
        }
    }

    // MARK: Reactions and reports

    func react(_ exp: PublicExperience, value: Int) async {
        var state = reactions[exp.id] ?? ReactionState(exp)
        if state.busy {
            state.note = "Saving your reaction…"
            reactions[exp.id] = state
            return
        }
        let previous = state.begin(value)
        let next = state.myValue
        reactions[exp.id] = state
        do {
            let result = try await env.api.react(experienceId: exp.id, value: next)
            state.accept(result)
            reactions[exp.id] = state
            await env.feedStore.applyReaction(experienceId: exp.id, value: result.value, counts: result.reactions)
        } catch {
            state.rollback(to: previous, note: ExperienceDisplay.reactionFailureNote(error))
            reactions[exp.id] = state
        }
    }

    func report(_ exp: PublicExperience, category: ReportCategory) async -> Result<Void, Error> {
        do {
            _ = try await env.api.report(experienceId: exp.id, category: category)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
