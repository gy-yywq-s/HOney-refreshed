//
//  ComposeExperienceViewModelTests.swift
//  HOneyTests — the composer state machine (web useComposer parity): draft
//  saved before any network call, lane → status/notice mapping, the held nudge
//  pass, stale-pass silent re-check, and publish clearing the draft slot.
//

import XCTest
@testable import HOney

@MainActor
final class ComposeExperienceViewModelTests: XCTestCase {

    // XCTest lifecycle overrides are nonisolated, so the fixture avoids setUp:
    // a per-instance temp dir, file-backed stores created on demand (they hold
    // no in-memory state), and one in-memory key store.
    private nonisolated let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("compose-vm-tests-\(UUID().uuidString)")
    private nonisolated let keys = InMemoryOwnershipKeyStore()
    private var drafts: ComposerDraftStore { ComposerDraftStore(directory: tempDir) }
    private var notes: PrivateNoteStore { PrivateNoteStore(directory: tempDir) }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private let lessonTarget = ComposerTarget(label: "Maths", detail: "Mon", lessonId: "l1")
    private let dishTarget = ComposerTarget(
        label: "Braised tofu", detail: "Food", entityKey: "dish:d1", isDish: true
    )

    private func makeVM(
        target: ComposerTarget?, seedNote: PrivateNote? = nil, api: StubExperienceAPI
    ) -> ComposeExperienceViewModel {
        ComposeExperienceViewModel(
            target: target, seedNote: seedNote,
            api: api, drafts: drafts, notes: notes, ownershipKeys: keys
        )
    }

    // MARK: Draft preservation (audit §3.4)

    func testDraftSavedBeforeCheckAndKeptWhenEligibilityFails() async {
        let api = StubExperienceAPI(eligibility: [.failure(URLError(.notConnectedToInternet))])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "my words"

        await vm.publish()

        let saved = await drafts.get("lesson:l1")
        XCTAssertEqual(saved?.body, "my words", "draft persisted before the network call")
        XCTAssertEqual(vm.body, "my words", "editor text untouched")
        XCTAssertEqual(vm.status, .editing)
        XCTAssertEqual(vm.notice?.tone, .danger)
        XCTAssertEqual(vm.notice?.text, ExperienceSubmitCopy.networkError)
    }

    func testHydrateRestoresSavedDraftForSameTarget() async {
        await drafts.save(targetKey: "lesson:l1", body: "earlier words", rating: nil)
        let vm = makeVM(target: lessonTarget, api: StubExperienceAPI())
        await vm.hydrate()
        XCTAssertEqual(vm.body, "earlier words")
    }

    // MARK: Lane → status/notice mapping

    func testPublishLanePublishesStoresKeyAndClearsDraft() async {
        let api = StubExperienceAPI(check: [.success(StubExperienceAPI.lane(.publish, pass: "pass-1"))])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "  publishable words  "

        await vm.publish()

        XCTAssertEqual(vm.status, .published(ownershipKey: "own-1", experienceId: "exp-1"))
        let storedKey = await keys.ownershipKey(for: "exp-1")
        XCTAssertEqual(storedKey, "own-1")
        let draft = await drafts.get("lesson:l1")
        XCTAssertNil(draft, "successful publish clears the slot")
        let publishRequests = await api.publishRequests
        XCTAssertEqual(publishRequests.first?.body, "publishable words", "body is trimmed on the wire")
        XCTAssertEqual(publishRequests.first?.eligibilityToken, "elig-1")
        XCTAssertEqual(publishRequests.first?.pass, "pass-1")
    }

    func testNudgeLaneHoldsPassAndAsksTheUser() async {
        let api = StubExperienceAPI(check: [
            .success(StubExperienceAPI.lane(.nudge, reasons: ["Add when this happened"], pass: "pass-n"))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "short verdict"

        await vm.publish()

        XCTAssertEqual(vm.status, .nudge(reasons: ["Add when this happened"]))
        let published = await api.publishRequests
        XCTAssertTrue(published.isEmpty, "a nudge NEVER auto-publishes")
        let saved = await drafts.get("lesson:l1")
        XCTAssertEqual(saved?.body, "short verdict")
    }

    func testCooldownLaneHoldsTicketAndRecheckSendsIt() async {
        let api = StubExperienceAPI(check: [
            .success(StubExperienceAPI.lane(.cooldown, reasons: ["Heated"], cooldown: CheckCooldown(ticket: "cd-1", retryAt: 1_756_704_000_000))),
            .success(StubExperienceAPI.lane(.publish, pass: "pass-2"))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "heated words"

        await vm.publish()
        XCTAssertEqual(vm.status, .cooldown(retryAt: 1_756_704_000_000, reasons: ["Heated"]))

        await vm.recheckAfterCooldown()
        let checks = await api.checkRequests
        XCTAssertEqual(checks.count, 2)
        XCTAssertNil(checks[0].cooldownTicket)
        XCTAssertEqual(checks[1].cooldownTicket, "cd-1", "re-check carries the held ticket")
        XCTAssertEqual(vm.status, .published(ownershipKey: "own-1", experienceId: "exp-1"))
    }

    func testEditRequiredKeepsDraftWithWarnNotice() async {
        let api = StubExperienceAPI(check: [
            .success(StubExperienceAPI.lane(.editRequired, reasons: ["Names a student"]))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "needs a rephrase"

        await vm.publish()

        XCTAssertEqual(vm.status, .editing)
        XCTAssertEqual(vm.notice?.tone, .warn)
        XCTAssertEqual(vm.notice?.text, ComposeExperienceViewModel.editRequiredCopy)
        XCTAssertEqual(vm.notice?.reasons, ["Names a student"])
        XCTAssertEqual(vm.body, "needs a rephrase")
    }

    func testOutOfScopeSuggestsKeepPrivate() async {
        let api = StubExperienceAPI(check: [.success(StubExperienceAPI.lane(.outOfScope))])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "something for the school"

        await vm.publish()

        XCTAssertEqual(vm.status, .editing)
        XCTAssertEqual(vm.notice?.tone, .warn)
        XCTAssertEqual(vm.notice?.text, ComposeExperienceViewModel.outOfScopeCopy)
        XCTAssertEqual(vm.notice?.suggestKeepPrivate, true)
    }

    func testBlockedSeriousAndFailedClosedKeepDraftWithDangerNotice() async {
        for (lane, copy) in [
            (CheckLane.blockedSerious, ComposeExperienceViewModel.blockedCopy),
            (CheckLane.failedClosed, ComposeExperienceViewModel.failedClosedCopy)
        ] {
            let api = StubExperienceAPI(check: [.success(StubExperienceAPI.lane(lane))])
            let vm = makeVM(target: lessonTarget, api: api)
            await vm.hydrate()
            vm.body = "kept words"

            await vm.publish()

            XCTAssertEqual(vm.status, .editing)
            XCTAssertEqual(vm.notice?.tone, .danger)
            XCTAssertEqual(vm.notice?.text, copy)
            XCTAssertEqual(vm.body, "kept words")
            let published = await api.publishRequests
            XCTAssertTrue(published.isEmpty)
        }
    }

    func testCheckErrorCodeMapsToWebCopy() async {
        let api = StubExperienceAPI(check: [
            .failure(HOneyAPIError.http(status: 422, body: #"{"error":"already_reviewed"}"#))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "second review"

        await vm.publish()

        XCTAssertEqual(vm.notice?.text, ExperienceSubmitCopy.byCode["already_reviewed"])
    }

    // MARK: Nudge follow-ups

    func testPublishAsIsUsesTheHeldPass() async {
        let api = StubExperienceAPI(check: [
            .success(StubExperienceAPI.lane(.nudge, reasons: ["r"], pass: "pass-held"))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "as is"

        await vm.publish()
        await vm.publishAsIs()

        XCTAssertEqual(vm.status, .published(ownershipKey: "own-1", experienceId: "exp-1"))
        let eligibilityCalls = await api.eligibilityCalls
        XCTAssertEqual(eligibilityCalls, 1, "no second eligibility round-trip")
        let publishRequests = await api.publishRequests
        XCTAssertEqual(publishRequests.first?.pass, "pass-held")
    }

    func testStalePassSilentlyReRunsTheCheck() async {
        let api = StubExperienceAPI(
            check: [
                .success(StubExperienceAPI.lane(.nudge, reasons: [], pass: "pass-old")),
                .success(StubExperienceAPI.lane(.publish, pass: "pass-new"))
            ],
            publish: [
                .failure(HOneyAPIError.http(status: 422, body: #"{"error":"pass_invalid"}"#)),
                .success(PublishExperienceResponse(ok: true, experienceId: "exp-2", ownershipKey: "own-2"))
            ]
        )
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "stale pass words"

        await vm.publish()      // → nudge, holds pass-old
        await vm.publishAsIs()  // publish fails stale → silent re-check → publish

        XCTAssertEqual(vm.status, .published(ownershipKey: "own-2", experienceId: "exp-2"))
        XCTAssertNil(vm.notice, "the stale pass is invisible to the user")
        let checks = await api.checkRequests
        XCTAssertEqual(checks.count, 2)
    }

    func testAddContextDropsThePass() async {
        let api = StubExperienceAPI(check: [
            .success(StubExperienceAPI.lane(.nudge, reasons: [], pass: "pass-1")),
            .success(StubExperienceAPI.lane(.publish, pass: "pass-2"))
        ])
        let vm = makeVM(target: lessonTarget, api: api)
        await vm.hydrate()
        vm.body = "first words"

        await vm.publish()
        vm.backToEditing()
        XCTAssertEqual(vm.status, .editing)

        await vm.publishAsIs() // no held pass → full re-check
        let eligibilityCalls = await api.eligibilityCalls
        XCTAssertEqual(eligibilityCalls, 2, "edited words need a fresh eligibility + check")
    }

    // MARK: Keep private (audit §3.5)

    func testKeepPrivateSavesNoteWithoutTouchingTheNetwork() async {
        let api = StubExperienceAPI()
        let vm = makeVM(target: dishTarget, api: api)
        await vm.hydrate()
        vm.body = "private thought"
        vm.rating = 3

        await vm.keepPrivate()

        let saved = await notes.list()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.body, "private thought")
        XCTAssertEqual(saved.first?.rating, 3)
        XCTAssertEqual(saved.first?.target.label, "Braised tofu · Food")
        XCTAssertEqual(saved.first?.target.entityKey, "dish:d1")
        XCTAssertEqual(saved.first?.target.entityType, "dish")
        XCTAssertEqual(vm.savedNote?.id, saved.first?.id)
        let calls = await api.totalCalls
        XCTAssertEqual(calls, 0, "saving a note never touches the network")
    }

    func testKeepPrivateUpdatesTheSeedingNote() async throws {
        let original = try await notes.save(
            id: nil, body: "v1", rating: nil,
            target: PrivateNoteTarget(label: "Maths · Mon", lessonId: "l1")
        )
        let api = StubExperienceAPI()
        let vm = makeVM(target: lessonTarget, seedNote: original, api: api)
        await vm.hydrate()
        XCTAssertEqual(vm.body, "v1", "composer is seeded with the note's text")

        vm.body = "v2"
        await vm.keepPrivate()

        let saved = await notes.list()
        XCTAssertEqual(saved.count, 1, "the note is updated, not duplicated")
        XCTAssertEqual(saved.first?.id, original.id)
        XCTAssertEqual(saved.first?.body, "v2")
    }
}
