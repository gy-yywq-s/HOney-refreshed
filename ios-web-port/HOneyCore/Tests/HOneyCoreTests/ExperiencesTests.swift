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
        XCTAssertNotNil(mine, "a recently loaded empty feed is a result and restores")
        XCTAssertEqual(mine?.items.count, 0)
        await store.applyReaction(experienceId: "exp_long", value: 1, counts: ReactionCounts(likes: 1, dislikes: 0))
        let reacted = await store.state(for: FeedKey(scope: .school))
        XCTAssertEqual(reacted?.items[1].myReaction, 1)
    }
}

final class FeedStoreHardeningTests: XCTestCase {
    func testEmptyFeedRestoresOnlyWithinTheWindow() async throws {
        let clock = ComposerControllerTests.Box(Date(timeIntervalSince1970: 1_000))
        let store = FeedStore(now: { clock.value })
        let key = FeedKey(scope: .myClasses)
        _ = try await store.loadFirst(key) { _ in FeedPage(items: [], nextCursor: nil, headCursor: nil) }
        let soon = await store.state(for: key)
        XCTAssertNotNil(soon)
        clock.value = Date(timeIntervalSince1970: 1_000 + FeedStore.emptyRestoreWindow + 1)
        let later = await store.state(for: key)
        XCTAssertNil(later, "after the window an empty feed refetches")
    }

    func testStaleCompletionDoesNotEvictANewerInFlightRequest() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .school)
        let page = try Fixtures.decode(FeedPage.self, "feed-page")
        let calls = ComposerControllerTests.Box(0)
        let slow = Task { try await store.loadFirst(key) { _ in
            calls.value += 1
            try await Task.sleep(nanoseconds: 120_000_000)
            return page
        } }
        try await Task.sleep(nanoseconds: 10_000_000)
        await store.invalidateAll()
        // A new first-page request starts while the old one is still winding down.
        let fresh = Task { try await store.loadFirst(key) { _ in
            calls.value += 1
            try await Task.sleep(nanoseconds: 200_000_000)
            return page
        } }
        _ = try? await slow.value
        // A third caller during the fresh request must coalesce onto it, not start another.
        try await Task.sleep(nanoseconds: 20_000_000)
        let third = try await store.loadFirst(key) { _ in
            calls.value += 1
            return page
        }
        let freshState = try await fresh.value
        XCTAssertEqual(third.items.count, freshState.items.count)
        XCTAssertEqual(calls.value, 2, "the stale completion did not clear the fresh registry entry")
    }

    func testStreamKeyIsTheOnlyProbeTarget() {
        XCTAssertTrue(FeedKey(scope: .school).isStream)
        XCTAssertFalse(FeedKey(scope: .school, teacherId: "t").isStream)
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
    final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

    struct Harness {
        let controller: ComposerController
        let events: Box<[String]>
        let drafts: Box<[(String, String, Int?)]>
        let publishes: Box<Int>
        let journal: Box<[String: PublicationRecord]>
        let keychain: Box<[String: String]>
    }

    func makeController(
        scope: ComposerScope = ComposerScope(lessonId: "L1"),
        checks: [CheckExperienceResponse],
        publishError: APIError? = nil,
        keyFails: Bool = false,
        draftFails: Bool = false,
        journalFails: Bool = false
    ) -> Harness {
        let events = Box<[String]>([])
        let drafts = Box<[(String, String, Int?)]>([])
        let publishes = Box(0)
        let queue = Box(checks)
        let journal = Box<[String: PublicationRecord]>([:])
        let keychain = Box<[String: String]>([:])
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
                keychain.value[id] = key
                events.value.append("key:\(id):\(key)")
            },
            keyIsStored: { id in keychain.value[id] != nil },
            saveDraft: { key, body, rating in
                if draftFails { throw ComposerDraftStoreError.notWritten }
                drafts.value.append((key, body, rating))
            },
            clearDraft: { key in events.value.append("clear:\(key)") },
            journalWrite: { record in
                if journalFails { throw PublicationJournalError.notWritten }
                journal.value[record.experienceId] = record
                events.value.append("journal:\(record.experienceId)")
            },
            journalRemove: { id in
                journal.value[id] = nil
                events.value.append("unjournal:\(id)")
            }
        )
        return Harness(controller: ComposerController(scope: scope, deps: deps), events: events, drafts: drafts, publishes: publishes, journal: journal, keychain: keychain)
    }

    func testPublishLaneJournalsBeforeKeyAndClearsDraftLast() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")])
        let outcome = await h.controller.continueToShare(body: "  words  ", rating: 4)
        XCTAssertEqual(outcome.status, .published(experienceId: "exp_new", ownershipKey: "own"))
        XCTAssertTrue(outcome.draftPersisted)
        XCTAssertEqual(h.drafts.value.first?.1, "  words  ", "draft persisted before the network")
        XCTAssertEqual(h.events.value, ["eligibility:L1", "check:words:-", "publish:elig:pass_fixture:words", "journal:exp_new", "key:exp_new:own", "unjournal:exp_new", "clear:lesson:L1"])
        XCTAssertTrue(h.journal.value.isEmpty)
    }

    func testDraftWriteFailureIsReportedNotHidden() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-failed-closed")], draftFails: true)
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertFalse(outcome.draftPersisted)
        XCTAssertEqual(outcome.notice?.text, ModerationCopy.failedClosedUnsaved, "never 'your words remain on this iPhone' when they do not")
        let saved = await h.controller.autosave(body: "x", rating: nil)
        XCTAssertFalse(saved)
    }

    func testNudgeWaitsForAnExplicitChoice() async throws {
        let h = makeController(checks: [
            try Fixtures.decode(CheckExperienceResponse.self, "check-nudge"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-edit-required"),
        ])
        let outcome = await h.controller.continueToShare(body: "short", rating: nil)
        XCTAssertEqual(outcome.status, .nudge(reasons: ["composition:low_information"]))
        XCTAssertEqual(h.publishes.value, 0, "a nudge never publishes by itself")
        let back = await h.controller.backToEditing()
        XCTAssertEqual(back.status, .editing)
        let shared = await h.controller.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .editing, "after leaving the preflight the pass is gone → a fresh check ran (and refused)")
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("check") }.count, 2)
        XCTAssertEqual(h.publishes.value, 0)
    }

    func testShareAsWrittenUsesHeldPass() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-nudge")])
        _ = await h.controller.continueToShare(body: "short", rating: nil)
        let shared = await h.controller.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .published(experienceId: "exp_new", ownershipKey: "own"))
        XCTAssertEqual(h.publishes.value, 1)
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("check") }.count, 1, "no second check")
    }

    func testCooldownTicketReusedOnlyForUnchangedText() async throws {
        let cooldown = try Fixtures.decode(CheckExperienceResponse.self, "check-cooldown")
        let h = makeController(checks: [cooldown, try Fixtures.decode(CheckExperienceResponse.self, "check-publish"), cooldown])
        let outcome = await h.controller.continueToShare(body: "angry words", rating: nil)
        guard case .cooldown(let retryAt, _) = outcome.status else { return XCTFail() }
        XCTAssertEqual(retryAt, cooldown.cooldown?.retryAt)
        let held = await h.controller.heldCooldown(body: "angry words ", rating: nil)
        XCTAssertNotNil(held)
        let notHeld = await h.controller.heldCooldown(body: "calmer words", rating: nil)
        XCTAssertNil(notHeld)
        let checked = await h.controller.wasChecked(body: "angry words", rating: nil)
        XCTAssertTrue(checked)
        let unchecked = await h.controller.wasChecked(body: "calmer words", rating: nil)
        XCTAssertFalse(unchecked)
        _ = await h.controller.continueToShare(body: "angry words", rating: nil)
        XCTAssertEqual(h.events.value.last { $0.hasPrefix("check") }, "check:angry words:cool_fixture")
        _ = await h.controller.continueToShare(body: "calmer words", rating: nil)
        XCTAssertEqual(h.events.value.last { $0.hasPrefix("check") }, "check:calmer words:-", "edited text checks fresh")
    }

    func testRefusalLanesKeepTheDraftWithCopy() async throws {
        let h = makeController(checks: [
            try Fixtures.decode(CheckExperienceResponse.self, "check-edit-required"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-out-of-scope"),
            try Fixtures.decode(CheckExperienceResponse.self, "check-failed-closed"),
        ])
        let edit = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(edit.status, .editing)
        XCTAssertEqual(edit.notice?.text, ModerationCopy.editRequired)
        XCTAssertEqual(edit.notice?.reasons, ["expression:targets_student"])
        let scope = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(scope.notice?.suggestKeepPrivate, true)
        let failed = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(failed.notice?.tone, .danger)
        XCTAssertEqual(failed.notice?.text, ModerationCopy.failedClosed)
        XCTAssertEqual(h.publishes.value, 0)
        XCTAssertEqual(h.drafts.value.count, 3, "every attempt persisted the draft first")
    }

    func testKeychainFailureKeepsTheJournalAndRetryCompletes() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")], keyFails: true)
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .publishedKeyUnsaved(experienceId: "exp_new", ownershipKey: "own", journaled: true))
        XCTAssertEqual(h.journal.value["exp_new"]?.ownershipKey, "own", "the key survives process death in the journal")
        XCTAssertTrue(h.events.value.contains("clear:lesson:L1"), "the draft is cleared once the key is journaled")
        // Later the Keychain works again (simulate by storing directly then retrying readback path)
        h.keychain.value["exp_new"] = "own"
        let retried = await h.controller.retryStoringKey()
        // storeKey still throws in this harness, but the key is present: settle must verify readback,
        // and since storeKey threw before readback the outcome stays unsaved.
        XCTAssertEqual(retried.status, .publishedKeyUnsaved(experienceId: "exp_new", ownershipKey: "own", journaled: true))
    }

    func testJournalAndKeychainBothFailingKeepsTheDraft() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")], keyFails: true, journalFails: true)
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .publishedKeyUnsaved(experienceId: "exp_new", ownershipKey: "own", journaled: false))
        XCTAssertFalse(h.events.value.contains("clear:lesson:L1"), "nothing durable holds the key: the draft stays too")
    }

    func testRetryAfterKeychainRecovers() async throws {
        let keyFails = Box(true)
        let events = Box<[String]>([])
        let keychain = Box<[String: String]>([:])
        let journal = Box<[String: PublicationRecord]>([:])
        let queue = Box([try Fixtures.decode(CheckExperienceResponse.self, "check-publish")])
        let deps = ComposerDependencies(
            eligibility: { _ in ExperienceEligibilityResponse(ok: true, eligibilityToken: "e", expiresAt: 0) },
            check: { _ in queue.value.removeFirst() },
            publish: { _ in PublishExperienceResponse(ok: true, experienceId: "exp", ownershipKey: "own") },
            storeKey: { id, key in
                if keyFails.value { throw SecretStoreError.writeFailed }
                keychain.value[id] = key
            },
            keyIsStored: { keychain.value[$0] != nil },
            saveDraft: { _, _, _ in },
            clearDraft: { events.value.append("clear:\($0)") },
            journalWrite: { journal.value[$0.experienceId] = $0 },
            journalRemove: { journal.value[$0] = nil; events.value.append("unjournal:\($0)") }
        )
        let c = ComposerController(scope: ComposerScope(lessonId: "L1"), deps: deps)
        let first = await c.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(first.status, .publishedKeyUnsaved(experienceId: "exp", ownershipKey: "own", journaled: true))
        keyFails.value = false
        let second = await c.retryStoringKey()
        XCTAssertEqual(second.status, .published(experienceId: "exp", ownershipKey: "own"))
        XCTAssertTrue(journal.value.isEmpty, "the journal entry goes once the Keychain has the key")
        XCTAssertEqual(keychain.value["exp"], "own")
    }

    func testPublishErrorCopy() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")], publishError: APIError(status: 422, code: "publications_disabled"))
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .editing)
        XCTAssertEqual(outcome.notice?.text, SubmitErrorCopy.byCode["publications_disabled"])
    }

    func testDishRatingOnlyTravelsForDishes() async throws {
        let h = makeController(scope: ComposerScope(entityKey: "teacher:t1", isDish: false), checks: [try Fixtures.decode(CheckExperienceResponse.self, "check-publish")])
        _ = await h.controller.continueToShare(body: "x", rating: 5)
        XCTAssertTrue(h.events.value.contains("eligibility:teacher:t1"))
        XCTAssertEqual(h.events.value.last { $0.hasPrefix("publish") }, "publish:elig:pass_fixture:x")
    }

    func testModerationDecisionAdapterCoversEveryLane() throws {
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckExperienceResponse.self, "check-publish")), .publishable(pass: "pass_fixture"))
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckExperienceResponse.self, "check-nudge")), .nudge(pass: "pass_fixture", reasons: ["composition:low_information"]))
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckExperienceResponse.self, "check-out-of-scope")), .outOfScope(reasons: []))
        XCTAssertEqual(ModerationDecision(CheckExperienceResponse(lane: .publish, reasons: [], policyVersion: 7, pass: nil)), .unavailable, "a publish lane without a pass is unusable, never a publish")
        XCTAssertEqual(ModerationDecision(CheckExperienceResponse(lane: .unknown("future"), reasons: [], policyVersion: 9)), .unavailable)
    }
}
