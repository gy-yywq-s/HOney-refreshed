// The stream's behaviour (spec §11): cursor pagination, per-scope state
// restoration, the quiet new-posts probe (main Stream only — the update
// endpoint knows scope + head, not entity filters), reactions with
// optimistic + authoritative + rollback, category-only reports. Shared by
// the Stream, entity pages and search results through FeedKey.
//
// v2: pages come from Community with no identity; "my classes" travels as
// the viewer's canonical exposure; names are joined here from Core; the
// viewer's own reactions are remembered on this iPhone.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class FeedViewModel {
    private let env: AppEnvironment
    private(set) var key: FeedKey
    private(set) var items: [PublicExperienceV2] = []
    private(set) var loading = true
    private(set) var loadingMore = false
    private(set) var error: String?
    private(set) var end = false
    private(set) var newAvailable = false
    private(set) var reactions: [String: ReactionState] = [:]
    private(set) var names = NameMaps()
    /// The top-most visible post, kept for restoration (set by the view).
    var restoreAnchorId: String?
    private var exposure: ExposureScope?
    private var probe: Task<Void, Never>?
    private var generation = 0

    init(env: AppEnvironment, key: FeedKey) {
        self.env = env
        self.key = key
    }

    var name: NameResolver { names.resolver }

    func reactionState(for exp: PublicExperienceV2) -> ReactionState {
        reactions[exp.id] ?? ReactionState(exp, myValue: env.prefs.myReaction(exp.id))
    }

    /// The reader's own words — known on this device only.
    func isMine(_ exp: PublicExperienceV2) -> Bool { env.prefs.isMyPost(exp.id) }

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
        if !names.loaded, let maps = try? await NameMaps.load(env) { names = maps }
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
        if let maps = try? await NameMaps.load(env, reload: true) { names = maps }
        await loadFirst(generation: generation)
    }

    /// Posts that arrived by another route (search results): register
    /// their reaction state so the same row renders and reacts correctly.
    func seed(_ posts: [PublicExperienceV2]) {
        for post in posts where reactions[post.id] == nil {
            reactions[post.id] = reactionState(for: post)
        }
    }

    private func currentExposure() async -> ExposureScope? {
        if key.scope != .myClasses { return nil }
        if let exposure { return exposure }
        exposure = try? await env.publish.exposure()
        return exposure
    }

    private func loadFirst(generation gen: Int) async {
        let community = env.community
        let exposure = await currentExposure()
        do {
            let state = try await env.feedStore.loadFirst(key, exposure: exposure) { try await community.feed($0) }
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

    func loadMoreIfNeeded(current: PublicExperienceV2) async {
        guard !loadingMore, !end, let last = items.last, last.id == current.id else { return }
        loadingMore = true
        let community = env.community
        let gen = generation
        let exposure = await currentExposure()
        do {
            if let state = try await env.feedStore.loadMore(key, exposure: exposure, using: { try await community.feed($0) }), gen == generation {
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
        for item in state.items {
            if var r = reactions[item.id] {
                // Server counts win after an authoritative update elsewhere.
                if !r.busy, r.counts != item.reactions {
                    r.counts = item.reactions
                    reactions[item.id] = r
                }
            } else {
                reactions[item.id] = reactionState(for: item)
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
        guard key.isStream else { return }
        let community = env.community
        let store = env.feedStore
        let key = key
        let exposure = exposure
        probe = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let head = await store.headCursor(for: key) else { continue }
                if let res = try? await community.feedUpdates(FeedUpdatesRequestV2(scope: key.scope, exposure: key.scope == .myClasses ? exposure : nil, head: head)), res.newItemsAvailable {
                    await MainActor.run { self?.newAvailable = true }
                }
            }
        }
    }

    // MARK: Reactions and reports

    func react(_ exp: PublicExperienceV2, value: Int) async {
        var state = reactionState(for: exp)
        if state.busy {
            state.note = "Saving your reaction…"
            reactions[exp.id] = state
            return
        }
        guard let account = env.scope?.honeyId else { return }
        let previous = state.begin(value)
        let next = state.myValue
        reactions[exp.id] = state
        do {
            let result = try await env.publish.react(account: account, experienceId: exp.id, value: next)
            state.accept(result)
            reactions[exp.id] = state
            await env.feedStore.applyReaction(experienceId: exp.id, counts: result.reactions)
        } catch {
            state.rollback(to: previous, note: ExperienceDisplay.reactionFailureNote(error))
            reactions[exp.id] = state
        }
    }

    func report(_ exp: PublicExperienceV2, category: ReportCategory) async -> Result<Void, Error> {
        guard let account = env.scope?.honeyId else { return .failure(APIError.notAuthenticated) }
        do {
            try await env.publish.report(account: account, experienceId: exp.id, category: category)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
