import XCTest
@testable import HOneyCore

final class FeedStoreTests: XCTestCase {
    func testPagesAppendDedupeAndEnd() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .school)
        let page1 = try Fixtures.decode(FeedPage.self, "feed-page")
        let first = try await store.loadFirst(key) { params in
            XCTAssertNil(params.cursor)
            return page1
        }
        XCTAssertEqual(first.items.count, 3)
        XCTAssertFalse(first.end)
        let more = try await store.loadMore(key) { params in
            XCTAssertEqual(params.cursor, "cur_opaque_next")
            return FeedPage(items: [page1.items[0], PublicExperience(id: "exp_new", entityKey: "room:r_345", body: "New", provenance: .verifiedMember, publishedDay: 20699, reactions: nil)], nextCursor: nil, headCursor: nil)
        }
        XCTAssertEqual(more?.items.map(\.id), ["exp_short", "exp_long", "exp_dish", "exp_new"], "duplicates dropped")
        XCTAssertTrue(more!.end)
        let head = await store.headCursor(for: key)
        XCTAssertEqual(head, "cur_opaque_head", "head cursor survives a page without one")
        let noMore = try await store.loadMore(key) { _ in XCTFail("no cursor → no fetch"); return page1 }
        XCTAssertNil(noMore)
    }

    func testStaleFirstPageIsDroppedAfterInvalidation() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .myClasses)
        let page = try Fixtures.decode(FeedPage.self, "feed-page")
        let task = Task { try await store.loadFirst(key) { _ in
            try await Task.sleep(nanoseconds: 100_000_000)
            return page
        } }
        try await Task.sleep(nanoseconds: 10_000_000)
        await store.invalidateAll()
        do {
            _ = try await task.value
            XCTFail("stale page must not apply")
        } catch is CancellationError {}
        let state = await store.state(for: key)
        XCTAssertNil(state)
    }

    func testScopesNeverMix() async throws {
        let store = FeedStore()
        let page = try Fixtures.decode(FeedPage.self, "feed-page")
        _ = try await store.loadFirst(FeedKey(scope: .school)) { _ in page }
        _ = try await store.loadFirst(FeedKey(scope: .myClasses)) { _ in FeedPage(items: [], nextCursor: nil, headCursor: "h") }
        let school = await store.state(for: FeedKey(scope: .school))
        XCTAssertEqual(school?.items.count, 3)
        let mine = await store.state(for: FeedKey(scope: .myClasses))
        XCTAssertNil(mine, "an empty loaded feed is not restored — it refetches")
        await store.applyReaction(experienceId: "exp_long", value: 1, counts: ReactionCounts(likes: 1, dislikes: 0))
        let reacted = await store.state(for: FeedKey(scope: .school))
        XCTAssertEqual(reacted?.items[1].myReaction, 1)
    }
}

final class ReactionStateTests: XCTestCase {
    func testOptimisticThenAuthoritativeThenRollback() throws {
        let page = try Fixtures.decode(FeedPage.self, "feed-page")
        var state = ReactionState(page.items[0]) // myReaction 1, likes 3
        XCTAssertEqual(state.next(for: 1), 0, "second tap clears")
        XCTAssertEqual(state.next(for: -1), -1)
        let previous = state.begin(-1)
        XCTAssertEqual(state.myValue, -1)
        XCTAssertTrue(state.busy)
        state.accept(try Fixtures.decode(ReactResponse.self, "react"))
        XCTAssertEqual(state.myValue, -1)
        XCTAssertEqual(state.counts, ReactionCounts(likes: 3, dislikes: 2))
        XCTAssertFalse(state.busy)
        let p2 = state.begin(1)
        state.rollback(to: p2, note: ExperienceDisplay.reactionFailureNote(APIError(status: 422, code: "not_eligible")))
        XCTAssertEqual(state.myValue, -1)
        XCTAssertEqual(state.note, "Reactions are open to students who have had the same class or place.")
        _ = previous
        state.accept(try Fixtures.decode(ReactResponse.self, "react-hidden"))
        XCTAssertNil(state.counts, "hidden counts stay hidden")
    }
}

final class ComposerControllerTests: XCTestCase {
    struct Harness {
        var checks: [CheckExperienceResponse]
        var publishError: APIError?
        var keyFails = false
        let drafts = InMemoryDrafts()
        var storedKeys: [(String, String)] = []
        var publishCalls = 0
    }

    final class InMemoryDrafts: @unchecked Sendable {
        var saved: [(String, String, Int?)] = []
        var cleared: [String] = []
    }

    final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

    func makeController(scope: ComposerScope = ComposerScope(lessonId: "L1"), checks: [CheckExperienceResponse], publishError: APIError? = nil, keyFails: Bool = false) -> (ComposerController, Box<[String]>, Box<[(String, String, Int?)]>, Box<Int>) {
        let events = Box<[String]>([])
        let drafts = Box<[(String, String, Int?)]>([])
        let publishes = Box(0)
        let queue = Box(checks)
        let deps = ComposerDependencies(
            eligibility: { input in
                events.value.append("eligibility:\(input.lessonId ?? input.entityKey ?? "")")
                return ExperienceEligibilityResponse(ok: true, eligibilityToken: "elig", expiresAt: 0)
            },
            check: { input in
                events.value.append("check:\(input.body):\(input.cooldownTicket ?? "-")")
                return queue.value.removeFirst()
            },
            publish: { input in
                publishes.value += 1
                if let publishError { throw publishError }
                events.value.append("publish:\(input.eligibilityToken):\(input.pass):\(input.body)")
                return PublishExperienceResponse(ok: true, experienceId: "exp_new", ownershipKey: "own")
            },
            storeKey: { id, key in
                if keyFails { throw SecretStoreError.writeFailed }
                events.value.append("key:\(id):\(key)")
            },
            saveDraft: { key, body, rating in drafts.value.append((key, body, rating)) },
            clearDraft: { key in events.value.append("clear:\(key)") }
        )
        return (ComposerController(scope: scope, deps: deps), events, drafts, publishes)
    }

    func testPublishLaneStoresKeyAndClearsDraft() async throws {
        let (c, events, drafts, _) = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")])
        let outcome = await c.continueToShare(body: "  words  ", rating: 4)
        XCTAssertEqual(outcome.status, .published(experienceId: "exp_new", ownershipKey: "own"))
        XCTAssertEqual(drafts.value.first?.1, "  words  ", "draft persisted before the network")
        XCTAssertEqual(events.value, ["eligibility:L1", "check:words:-", "publish:elig:pass_fixture:words", "clear:lesson:L1", "key:exp_new:own"])
    }

    func testNudgeWaitsForAnExplicitChoice() async throws {
        let (c, events, _, publishes) = makeController(checks: [
            try Fixtures.decode(CheckExperienceResponse.self, "check-nudge"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-edit-required"),
        ])
        let outcome = await c.continueToShare(body: "short", rating: nil)
        XCTAssertEqual(outcome.status, .nudge(reasons: ["composition:low_information"]))
        XCTAssertEqual(publishes.value, 0, "a nudge never publishes by itself")
        let back = await c.backToEditing()
        XCTAssertEqual(back.status, .editing)
        let shared = await c.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .editing, "after leaving the preflight the pass is gone → a fresh check ran (and refused)")
        XCTAssertEqual(events.value.filter { $0.hasPrefix("check") }.count, 2)
        XCTAssertEqual(publishes.value, 0)
    }

    func testShareAsWrittenUsesHeldPass() async throws {
        let (c, events, _, publishes) = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-nudge")])
        _ = await c.continueToShare(body: "short", rating: nil)
        let shared = await c.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .published(experienceId: "exp_new", ownershipKey: "own"))
        XCTAssertEqual(publishes.value, 1)
        XCTAssertEqual(events.value.filter { $0.hasPrefix("check") }.count, 1, "no second check")
    }

    func testCooldownTicketReusedOnlyForUnchangedText() async throws {
        let cooldown = try Fixtures.decode(CheckExperienceResponse.self, "check-cooldown")
        let (c, events, _, _) = makeController(checks: [cooldown, try Fixtures.decode(CheckExperienceResponse.self, "check-publish"), cooldown])
        let outcome = await c.continueToShare(body: "angry words", rating: nil)
        guard case .cooldown(let retryAt, _) = outcome.status else { return XCTFail() }
        XCTAssertEqual(retryAt, cooldown.cooldown?.retryAt)
        let held = await c.heldCooldown(body: "angry words ", rating: nil)
        XCTAssertNotNil(held)
        let notHeld = await c.heldCooldown(body: "calmer words", rating: nil)
        XCTAssertNil(notHeld)
        _ = await c.continueToShare(body: "angry words", rating: nil)
        XCTAssertEqual(events.value.last { $0.hasPrefix("check") }, "check:angry words:cool_fixture")
        _ = await c.continueToShare(body: "calmer words", rating: nil)
        XCTAssertEqual(events.value.last { $0.hasPrefix("check") }, "check:calmer words:-", "edited text checks fresh")
    }

    func testRefusalLanesKeepTheDraftWithCopy() async throws {
        let (c, _, drafts, publishes) = makeController(checks: [
            try Fixtures.decode(CheckExperienceResponse.self, "check-edit-required"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-out-of-scope"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-failed-closed"),
        ])
        let edit = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(edit.status, .editing)
        XCTAssertEqual(edit.notice?.text, ModerationCopy.editRequired)
        XCTAssertEqual(edit.notice?.reasons, ["expression:targets_student"])
        let scope = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(scope.notice?.suggestKeepPrivate, true)
        let failed = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(failed.notice?.tone, .danger)
        XCTAssertEqual(failed.notice?.text, ModerationCopy.failedClosed)
        XCTAssertEqual(publishes.value, 0)
        XCTAssertEqual(drafts.value.count, 3, "every attempt persisted the draft first")
    }

    func testPublishedButKeyUnsavedIsHonest() async throws {
        let (c, _, _, _) = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")], keyFails: true)
        let outcome = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .publishedKeyUnsaved(experienceId: "exp_new", ownershipKey: "own"))
        let retried = await c.retryStoringKey()
        XCTAssertEqual(retried.status, .publishedKeyUnsaved(experienceId: "exp_new", ownershipKey: "own"))
    }

    func testPublishErrorCopy() async throws {
        let (c, _, _, _) = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")], publishError: APIError(status: 422, code: "publications_disabled"))
        let outcome = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .editing)
        XCTAssertEqual(outcome.notice?.text, SubmitErrorCopy.byCode["publications_disabled"])
    }

    func testDishRatingOnlyTravelsForDishes() async throws {
        let (c, events, _, _) = makeController(scope: ComposerScope(entityKey: "teacher:t1", isDish: false), checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")])
        _ = await c.continueToShare(body: "x", rating: 5)
        XCTAssertTrue(events.value.contains("eligibility:teacher:t1"))
        // rating is dropped for a non-dish target: the publish body has no rating
        XCTAssertEqual(events.value.last { $0.hasPrefix("publish") }, "publish:elig:pass_fixture:x")
    }
}
