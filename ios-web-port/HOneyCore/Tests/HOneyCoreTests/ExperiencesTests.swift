import XCTest
import BigInt
@testable import HOneyCore

final class FeedStoreTests: XCTestCase {
    let exposure = ExposureScope(teachers: ["t_76b873b12d89"], courses: ["c_al_econ_u4"], lessons: ["tok_a1"])

    func testPagesAppendDedupeAndEnd() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .school)
        let page1 = try Fixtures.decode(FeedPageV2.self, "feed-page")
        let first = try await store.loadFirst(key, exposure: exposure) { request in
            XCTAssertNil(request.cursor)
            XCTAssertNil(request.exposure, "the school scope sends no exposure")
            return page1
        }
        XCTAssertEqual(first.items.count, 3)
        XCTAssertFalse(first.end)
        let more = try await store.loadMore(key, exposure: exposure) { request in
            XCTAssertEqual(request.cursor, "cur_opaque_next")
            return FeedPageV2(items: [page1.items[0], PublicExperienceV2(id: "exp_new", primary: EntityRefV2(type: .room, id: "r_345"), contexts: [], body: "New", provenance: .verifiedMember, publishedDay: 20699, reactions: nil)], nextCursor: nil, headCursor: nil)
        }
        XCTAssertEqual(more?.items.map(\.id), ["exp_short", "exp_long", "exp_dish", "exp_new"], "duplicates dropped")
        XCTAssertTrue(more!.end)
        let head = await store.headCursor(for: key)
        XCTAssertEqual(head, "cur_opaque_head", "head cursor survives a page without one")
        let noMore = try await store.loadMore(key, exposure: exposure) { _ in XCTFail("no cursor → no fetch"); return page1 }
        XCTAssertNil(noMore)
    }

    func testMyClassesCarriesTheExposure() async throws {
        let store = FeedStore()
        _ = try await store.loadFirst(FeedKey(scope: .myClasses), exposure: exposure) { request in
            XCTAssertEqual(request.exposure, self.exposure)
            XCTAssertEqual(request.scope, .myClasses)
            return FeedPageV2(items: [], nextCursor: nil, headCursor: nil)
        }
    }

    func testStaleFirstPageIsDroppedAfterInvalidation() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .myClasses)
        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        let task = Task { try await store.loadFirst(key, exposure: nil) { _ in
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
        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        _ = try await store.loadFirst(FeedKey(scope: .school), exposure: nil) { _ in page }
        _ = try await store.loadFirst(FeedKey(scope: .myClasses), exposure: exposure) { _ in FeedPageV2(items: [], nextCursor: nil, headCursor: "h") }
        let school = await store.state(for: FeedKey(scope: .school))
        XCTAssertEqual(school?.items.count, 3)
        let mine = await store.state(for: FeedKey(scope: .myClasses))
        XCTAssertNotNil(mine, "a recently loaded empty feed is a result and restores")
        XCTAssertEqual(mine?.items.count, 0)
        await store.applyReaction(experienceId: "exp_long", counts: ReactionCounts(likes: 1, dislikes: 0))
        let reacted = await store.state(for: FeedKey(scope: .school))
        XCTAssertEqual(reacted?.items[1].reactions, ReactionCounts(likes: 1, dislikes: 0))
    }
}

final class FeedStoreHardeningTests: XCTestCase {
    func testEmptyFeedRestoresOnlyWithinTheWindow() async throws {
        let clock = ComposerControllerTests.Box(Date(timeIntervalSince1970: 1_000))
        let store = FeedStore(now: { clock.value })
        let key = FeedKey(scope: .myClasses)
        _ = try await store.loadFirst(key, exposure: nil) { _ in FeedPageV2(items: [], nextCursor: nil, headCursor: nil) }
        let soon = await store.state(for: key)
        XCTAssertNotNil(soon)
        clock.value = Date(timeIntervalSince1970: 1_000 + FeedStore.emptyRestoreWindow + 1)
        let later = await store.state(for: key)
        XCTAssertNil(later, "after the window an empty feed refetches")
    }

    func testStaleCompletionDoesNotEvictANewerInFlightRequest() async throws {
        let store = FeedStore()
        let key = FeedKey(scope: .school)
        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        let calls = ComposerControllerTests.Box(0)
        let slow = Task { try await store.loadFirst(key, exposure: nil) { _ in
            calls.value += 1
            try await Task.sleep(nanoseconds: 120_000_000)
            return page
        } }
        try await Task.sleep(nanoseconds: 10_000_000)
        await store.invalidateAll()
        let fresh = Task { try await store.loadFirst(key, exposure: nil) { _ in
            calls.value += 1
            try await Task.sleep(nanoseconds: 200_000_000)
            return page
        } }
        _ = try? await slow.value
        try await Task.sleep(nanoseconds: 20_000_000)
        let third = try await store.loadFirst(key, exposure: nil) { _ in
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
        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        var state = ReactionState(page.items[0], myValue: 1) // remembered on the device; likes 3
        XCTAssertEqual(state.next(for: 1), 0, "second tap clears")
        XCTAssertEqual(state.next(for: -1), -1)
        let previous = state.begin(-1)
        XCTAssertEqual(state.myValue, -1)
        XCTAssertTrue(state.busy)
        state.accept(try Fixtures.decode(ReactResponseV2.self, "react"))
        XCTAssertEqual(state.myValue, -1)
        XCTAssertEqual(state.counts, ReactionCounts(likes: 3, dislikes: 2))
        XCTAssertFalse(state.busy)
        let p2 = state.begin(1)
        state.rollback(to: p2, note: ExperienceDisplay.reactionFailureNote(APIError(status: 422, code: "reactor_unknown")))
        XCTAssertEqual(state.myValue, -1)
        XCTAssertEqual(state.note, "Reactions are open to students of this school.")
        _ = previous
        state.accept(try Fixtures.decode(ReactResponseV2.self, "react-hidden"))
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
    }

    static func prepared(_ target: PublishTarget, body: String, rating: Int?) -> PreparedPost {
        let info = EligibilityInfo(schoolId: "huayaopudong", academicYear: "2026-27", scope: target.lessonId.map { "lesson:\($0)" } ?? target.entityKey ?? "", contexts: EligibilityContexts(lessonId: target.lessonId), provenance: "verified_lesson", week: 36)
        let envelope = SignedPostEnvelopeV2(schoolId: "huayaopudong", academicYear: "2026-27", primaryEntity: EnvelopeEntity(type: info.scopeParts.type, id: info.scopeParts.id), contexts: EnvelopeContexts(info.contexts), body: body, rating: rating, postNonce: "n", postingPublicKey: "p", controlPublicKey: "c", clientNonce: "cn")
        return PreparedPost(token: EligibilityToken(keyId: "k", info: info, message: "m", signature: "s"), envelope: envelope, postSignature: "sig")
    }

    func makeController(
        scope: ComposerScope = ComposerScope(lessonId: "L1"),
        checks: [CheckResponseV2],
        publishError: APIError? = nil,
        draftFails: Bool = false,
        restoreNeeded: Bool = false
    ) -> Harness {
        let events = Box<[String]>([])
        let drafts = Box<[(String, String, Int?)]>([])
        let publishes = Box(0)
        let queue = Box(checks)
        let deps = ComposerDependencies(
            prepare: { target, body, rating in
                if restoreNeeded { throw PublishError.postControlsRestoreNeeded }
                events.value.append("prepare:\(target.lessonId ?? target.entityKey ?? ""):\(body):\(rating.map(String.init) ?? "-")")
                return Self.prepared(target, body: body, rating: rating)
            },
            check: { prepared, ticket in
                events.value.append("check:\(prepared.envelope.body):\(ticket ?? "-")")
                return queue.value.removeFirst()
            },
            publish: { prepared, pass in
                publishes.value += 1
                if let publishError { throw publishError }
                events.value.append("publish:\(pass):\(prepared.envelope.body)")
                return PublishResponseV2(ok: true, experienceId: "exp_new", postNonce: "n")
            },
            saveDraft: { key, body, rating in
                if draftFails { throw ComposerDraftStoreError.notWritten }
                drafts.value.append((key, body, rating))
            },
            clearDraft: { key in events.value.append("clear:\(key)") }
        )
        return Harness(controller: ComposerController(scope: scope, deps: deps), events: events, drafts: drafts, publishes: publishes)
    }

    func testPublishLanePreparesChecksPublishesAndClearsTheDraftLast() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckResponseV2.self, "check-publish")])
        let outcome = await h.controller.continueToShare(body: "  words  ", rating: 4)
        XCTAssertEqual(outcome.status, .published(experienceId: "exp_new"))
        XCTAssertTrue(outcome.draftPersisted)
        XCTAssertEqual(h.drafts.value.first?.1, "  words  ", "draft persisted before the network")
        XCTAssertEqual(h.events.value, ["prepare:L1:words:-", "check:words:-", "publish:pass_fixture:words", "clear:lesson:L1"])
    }

    func testDraftWriteFailureIsReportedNotHidden() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckResponseV2.self, "check-failed-closed")], draftFails: true)
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertFalse(outcome.draftPersisted)
        XCTAssertEqual(outcome.notice?.text, ModerationCopy.failedClosedUnsaved, "never 'your words remain on this iPhone' when they do not")
        let saved = await h.controller.autosave(body: "x", rating: nil)
        XCTAssertFalse(saved)
    }

    func testRestoreNeededKeepsTheDraftAndSaysSo() async throws {
        let h = makeController(checks: [], restoreNeeded: true)
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .postControlsRestoreNeeded)
        XCTAssertEqual(outcome.notice?.text, ModerationCopy.restoreNeeded)
        XCTAssertEqual(h.publishes.value, 0)
        XCTAssertEqual(h.drafts.value.count, 1)
    }

    func testNudgeWaitsForAnExplicitChoice() async throws {
        let h = makeController(checks: [
            try Fixtures.decode(CheckResponseV2.self, "check-nudge"),
            try Fixtures.decode(CheckResponseV2.self, "check-edit-required"),
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

    func testShareAsWrittenPublishesExactlyThePreparedPost() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckResponseV2.self, "check-nudge")])
        _ = await h.controller.continueToShare(body: "short", rating: nil)
        let shared = await h.controller.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .published(experienceId: "exp_new"))
        XCTAssertEqual(h.publishes.value, 1)
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("check") }.count, 1, "no second check")
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("prepare") }.count, 1, "no second token — the checked envelope is what publishes")
    }

    func testStaleTokenOnShareAsWrittenReRunsTheCheck() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckResponseV2.self, "check-nudge"), try Fixtures.decode(CheckResponseV2.self, "check-publish")], publishError: APIError(status: 422, code: "token_used"))
        _ = await h.controller.continueToShare(body: "short", rating: nil)
        let shared = await h.controller.shareAsWritten(body: "short", rating: nil)
        XCTAssertEqual(shared.status, .editing, "the second publish also fails in this harness; what matters is the re-check happened")
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("check") }.count, 2)
        XCTAssertEqual(h.events.value.filter { $0.hasPrefix("prepare") }.count, 2, "a fresh token was prepared")
    }

    func testCooldownTicketReusedOnlyForUnchangedText() async throws {
        let cooldown = try Fixtures.decode(CheckResponseV2.self, "check-cooldown")
        let h = makeController(checks: [cooldown, try Fixtures.decode(CheckResponseV2.self, "check-publish"), cooldown])
        let outcome = await h.controller.continueToShare(body: "angry words", rating: nil)
        guard case .cooldown(let retryAt, _) = outcome.status else { return XCTFail() }
        XCTAssertEqual(retryAt, cooldown.cooldown?.retryAt)
        let held = await h.controller.heldCooldown(body: "angry words ", rating: nil)
        XCTAssertNotNil(held)
        let notHeld = await h.controller.heldCooldown(body: "calmer words", rating: nil)
        XCTAssertNil(notHeld)
        let checked = await h.controller.wasChecked(body: "angry words", rating: nil)
        XCTAssertTrue(checked)
        _ = await h.controller.continueToShare(body: "angry words", rating: nil)
        XCTAssertEqual(h.events.value.last { $0.hasPrefix("check") }, "check:angry words:cool_fixture")
        _ = await h.controller.continueToShare(body: "calmer words", rating: nil)
        XCTAssertEqual(h.events.value.last { $0.hasPrefix("check") }, "check:calmer words:-", "edited text checks fresh")
    }

    func testRefusalLanesKeepTheDraftWithCopy() async throws {
        let h = makeController(checks: [
            try Fixtures.decode(CheckResponseV2.self, "check-edit-required"),
            try Fixtures.decode(CheckResponseV2.self, "check-out-of-scope"),
            try Fixtures.decode(CheckResponseV2.self, "check-failed-closed"),
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

    func testPublishErrorCopy() async throws {
        let h = makeController(checks: [try Fixtures.decode(CheckResponseV2.self, "check-publish")], publishError: APIError(status: 422, code: "publications_disabled"))
        let outcome = await h.controller.continueToShare(body: "x", rating: nil)
        XCTAssertEqual(outcome.status, .editing)
        XCTAssertEqual(outcome.notice?.text, SubmitErrorCopy.byCode["publications_disabled"])
    }

    func testDishRatingOnlyTravelsForDishes() async throws {
        let h = makeController(scope: ComposerScope(entityKey: "teacher:t1", isDish: false), checks: [try Fixtures.decode(CheckResponseV2.self, "check-publish")])
        _ = await h.controller.continueToShare(body: "x", rating: 5)
        XCTAssertEqual(h.events.value.first, "prepare:teacher:t1:x:-", "no rating for a teacher")
        let dish = makeController(scope: ComposerScope(entityKey: "dish:d1", isDish: true), checks: [try Fixtures.decode(CheckResponseV2.self, "check-publish")])
        _ = await dish.controller.continueToShare(body: "x", rating: 5)
        XCTAssertEqual(dish.events.value.first, "prepare:dish:d1:x:5")
    }

    func testModerationDecisionAdapterCoversEveryLane() throws {
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckResponseV2.self, "check-publish")), .publishable(pass: "pass_fixture"))
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckResponseV2.self, "check-nudge")), .nudge(pass: "pass_fixture", reasons: ["composition:low_information"]))
        XCTAssertEqual(ModerationDecision(try Fixtures.decode(CheckResponseV2.self, "check-out-of-scope")), .outOfScope(reasons: []))
        XCTAssertEqual(ModerationDecision(CheckResponseV2(lane: .publish, reasons: [], policyVersion: 7, pass: nil)), .unavailable, "a publish lane without a pass is unusable, never a publish")
        XCTAssertEqual(ModerationDecision(CheckResponseV2(lane: .unknown("future"), reasons: [], policyVersion: 9)), .unavailable)
    }
}

/// The v2 flow end to end over scripted Core + Community transports: the
/// token is blinded and finalized against a real key, the envelope is signed
/// with the derived posting key and Community's check request carries no
/// identity — only proofs.
final class PublishClientTests: XCTestCase {
    struct World {
        let publish: PublishClient
        let controls: PostControls
        let core: ScriptedTransport
        let community: ScriptedTransport
        let key: CommunityV2Tests.TestIssuerKey
    }

    func makeWorld() async throws -> World {
        let key = try JSONDecoder().decode(CommunityV2Tests.TestIssuerKey.self, from: Data(contentsOf: CommunityV2Tests.fixturesDirectory.appendingPathComponent("issuer-test.jwk.json")))
        let issuer = IssuerDescriptor(suite: BlindToken.suite, keyId: "kat", publicKey: .init(n: key.public.n, e: key.public.e))
        let info = try Fixtures.decode(EligibilityInfoResponse.self, "eligibility-info").info
        let core = ScriptedTransport { req in
            switch req.url.path {
            case "/api/community/issuer": return HTTPResponse(status: 200, body: try WireCoding.encode(issuer))
            case "/api/community/scope": return HTTPResponse(status: 200, body: try Fixtures.data("scope"))
            case "/api/community/eligibility/info": return HTTPResponse(status: 200, body: try WireCoding.encode(EligibilityInfoResponse(ok: true, info: info)))
            case "/api/community/eligibility":
                struct Body: Decodable { let blindedMessage: String }
                let blinded = try WireCoding.decode(Body.self, from: req.body!)
                let sig = try BlindToken.blindSign(n: BigUIntFrom(key.public.n), p: BigUIntFrom(key.private.p), q: BigUIntFrom(key.private.q), blindedMessage: Base64URL.decode(blinded.blindedMessage)!, info: try BlindToken.infoBytes(info))
                return HTTPResponse(status: 200, body: try WireCoding.encode(EligibilityIssued(ok: true, keyId: "kat", info: info, blindSignature: Base64URL.encode(sig))))
            case "/api/vault": return HTTPResponse(status: 404, body: Data(#"{"error":"no_vault"}"#.utf8))
            default: return HTTPResponse(status: 404)
            }
        }
        let community = ScriptedTransport { req in
            switch req.url.path {
            case "/community/v2/check": return HTTPResponse(status: 200, body: try Fixtures.data("check-publish"))
            case "/community/v2/publish": return HTTPResponse(status: 200, body: try Fixtures.data("publish"))
            default: return HTTPResponse(status: 404)
            }
        }
        let api = APIClient(baseURL: URL(string: "https://honey.example")!, transport: core, sessionStore: InMemorySessionStore(try Fixtures.decode(SessionTokens.self, "session-refresh")))
        let controls = PostControls(api: api, storage: SecretPostControlStore(store: InMemorySecretStore()))
        let prefs = Preferences(defaults: UserDefaults(suiteName: "honey-publish-\(UUID().uuidString)")!)
        prefs.setAccount("h_1")
        let publish = PublishClient(api: api, community: CommunityAPIClient(baseURL: URL(string: "https://honey.example")!, transport: community), controls: controls, memory: prefs)
        return World(publish: publish, controls: controls, core: core, community: community, key: key)
    }

    func testPrepareCheckPublishCarriesProofsAndNoIdentity() async throws {
        let w = try await makeWorld()
        let prepared = try await w.publish.preparePost(account: "h_1", target: PublishTarget(lessonId: "tok_a1"), body: " Econ made sense ", rating: nil)
        // The token verifies under the issuer key with the bound info (Community's offline check).
        let pk = try IssuerRSAPublicKey(descriptor: IssuerDescriptor(suite: BlindToken.suite, keyId: "kat", publicKey: .init(n: w.key.public.n, e: w.key.public.e)))
        XCTAssertTrue(BlindToken.verify(publicKey: pk, signature: Base64URL.decode(prepared.token.signature)!, message: Base64URL.decode(prepared.token.message)!, info: try BlindToken.infoBytes(prepared.token.info)))
        // The envelope is signed by the posting key derived from the root this device just created.
        let roots = try await w.controls.unlock(account: "h_1")!
        let posting = try V2Derivation.postingKeyPair(root: roots.active.secret, epoch: prepared.token.info.epoch)
        XCTAssertEqual(prepared.envelope.postingPublicKey, Base64URL.encode(posting.publicKey))
        XCTAssertTrue(V2Derivation.verifyStatement(publicKey: posting.publicKey, statement: try JSONValue(encoding: prepared.envelope), signature: Base64URL.decode(prepared.postSignature)!))
        XCTAssertEqual(prepared.envelope.body, "Econ made sense")
        XCTAssertEqual(prepared.envelope.primaryEntity, EnvelopeEntity(type: "lesson", id: "tok_a1"))
        XCTAssertEqual(prepared.envelope.contexts.courseId, "c_al_econ_u4")

        let check = try await w.publish.check(prepared, cooldownTicket: nil)
        XCTAssertEqual(check.lane, .publish)
        let published = try await w.publish.publish(prepared, pass: check.pass!)
        XCTAssertEqual(published.experienceId, "exp_new")
        for req in [w.community.request(at: 0), w.community.request(at: 1)] {
            for header in req.headers.keys {
                XCTAssertFalse(header.lowercased().contains("authorization"), "Community must never see a session")
                XCTAssertFalse(header.lowercased().contains("cookie"))
            }
            let body = try JSONSerialization.jsonObject(with: req.body!) as! [String: Any]
            XCTAssertNil(body["honeyId"])
            XCTAssertNotNil(body["token"])
        }
        // Core saw exactly one counted issuance and the uncounted describe.
        let corePaths = (0..<w.core.count).map { w.core.request(at: $0).url.path }
        XCTAssertEqual(corePaths.filter { $0 == "/api/community/eligibility" }.count, 1)
        XCTAssertEqual(corePaths.filter { $0 == "/api/community/eligibility/info" }.count, 1)
    }
}

func BigUIntFrom(_ base64url: String) -> BigUInt {
    BigUInt(Base64URL.decode(base64url)!)
}
