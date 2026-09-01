//
//  AppModelLifecycleTests.swift
//  HOneyTests — ownership-key lifecycle (audit §3.6): ordinary sign-out keeps
//  keys, notes and drafts; account deletion clears them only on the explicit
//  "erase everything" choice. Plus the two-step consent routing (audit §3.2).
//

import XCTest
@testable import HOney

@MainActor
final class AppModelLifecycleTests: XCTestCase {

    // XCTest lifecycle overrides are nonisolated, so the fixture avoids setUp:
    // a per-instance temp dir and key store, and the model built lazily on the
    // main actor when the first test statement touches it.
    private nonisolated let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("appmodel-tests-\(UUID().uuidString)")
    private nonisolated let keys = InMemoryOwnershipKeyStore()
    private lazy var services = AppServices.stub(tempDir: tempDir, ownershipKeyStore: keys)
    private lazy var model = AppModel(services: services)

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        StubURLProtocol.responses = [:]
        super.tearDown()
    }

    private func seedLocalData() async throws {
        await services.sessionStore.save(HOneySession(
            accessToken: "access",
            accessExpiresAt: Date().addingTimeInterval(3_600),
            refreshToken: "refresh",
            refreshExpiresAt: Date().addingTimeInterval(86_400)
        ))
        try await keys.add(experienceId: "exp-1", ownershipKey: "own-1")
        _ = try await services.privateNoteStore.save(
            id: nil, body: "note", rating: nil,
            target: PrivateNoteTarget(label: "Ms Lin", entityKey: "teacher:t1")
        )
        await services.composerDraftStore.save(targetKey: "lesson:l1", body: "draft", rating: nil)
    }

    // MARK: Sign-out (audit §3.6)

    func testSignOutKeepsOwnershipKeysNotesAndDrafts() async throws {
        try await seedLocalData()

        await model.signOut()

        XCTAssertEqual(model.phase, .signedOut)
        let remainingKeys = try await keys.keys()
        XCTAssertEqual(remainingKeys, ["own-1"], "sign-out never deletes post keys")
        let notes = await services.privateNoteStore.list()
        XCTAssertEqual(notes.count, 1, "sign-out never deletes private notes")
        let draft = await services.composerDraftStore.get("lesson:l1")
        XCTAssertEqual(draft?.body, "draft", "sign-out never deletes drafts")
    }

    // MARK: Account deletion

    func testDeleteAccountKeepingKeysLeavesLocalDataIntact() async throws {
        try await seedLocalData()

        let result = await model.deleteAccount(eraseLocalData: false)

        XCTAssertEqual(result, .complete)
        XCTAssertEqual(model.phase, .signedOut)
        let remainingKeys = try await keys.keys()
        XCTAssertEqual(remainingKeys, ["own-1"], "'keep post keys' preserves control over past posts")
        let notes = await services.privateNoteStore.list()
        XCTAssertEqual(notes.count, 1)
    }

    func testDeleteAccountEraseEverythingClearsKeysNotesAndDrafts() async throws {
        try await seedLocalData()

        let result = await model.deleteAccount(eraseLocalData: true)

        XCTAssertEqual(result, .complete)
        XCTAssertEqual(model.phase, .signedOut)
        let remainingKeys = try await keys.keys()
        XCTAssertTrue(remainingKeys.isEmpty, "'erase everything' clears ownership keys")
        let notes = await services.privateNoteStore.list()
        XCTAssertTrue(notes.isEmpty, "'erase everything' clears private notes")
        let draft = await services.composerDraftStore.get("lesson:l1")
        XCTAssertNil(draft, "'erase everything' clears the draft slot")
    }

    func testDeleteAccountFailureKeepsSessionAndLocalData() async throws {
        try await seedLocalData()
        StubURLProtocol.responses["/api/account"] = (500, Data("server error".utf8))

        let deleted = await model.deleteAccount(eraseLocalData: true)
        let remainingKeys = try await keys.keys()
        let remainingNotes = await services.privateNoteStore.list()
        let remainingDraft = await services.composerDraftStore.get("lesson:l1")

        XCTAssertEqual(deleted, .serverFailed)
        XCTAssertEqual(model.phase, .loading, "failed deletion must not pretend the user is signed out")
        XCTAssertEqual(remainingKeys, ["own-1"])
        XCTAssertEqual(remainingNotes.count, 1)
        XCTAssertNotNil(remainingDraft)
    }

    func testServerDeletionSuccessWithLocalKeyFailureSignsOutAndReportsPartialCleanup() async {
        let failingKeys = FailingClearOwnershipKeyStore()
        let partialServices = AppServices.stub(tempDir: tempDir, ownershipKeyStore: failingKeys)
        await partialServices.sessionStore.save(HOneySession(
            accessToken: "access",
            accessExpiresAt: Date().addingTimeInterval(3_600),
            refreshToken: "refresh",
            refreshExpiresAt: Date().addingTimeInterval(86_400)
        ))
        let partialModel = AppModel(services: partialServices)

        let result = await partialModel.deleteAccount(eraseLocalData: true)

        XCTAssertEqual(result, .localCleanupIncomplete(["post-control keys"]))
        XCTAssertEqual(partialModel.phase, .signedOut)
        XCTAssertTrue(partialModel.loginError?.contains("post-control keys") == true)
    }

    // MARK: Two-step consent (audit §3.2)

    private func loginFixture(consent: Bool) -> Data {
        Data("""
        {
          "honeyId": "h1", "displayName": "Gary", "created": false, "isAdmin": false,
          "consent": { "timetable": \(consent) },
          "session": {
            "accessToken": "at", "accessExpiresAt": "2027-01-01T00:00:00Z",
            "refreshToken": "rt", "refreshExpiresAt": "2027-02-01T00:00:00Z"
          }
        }
        """.utf8)
    }

    func testLoginWithoutPriorConsentEntersConsentPendingPhase() async {
        StubURLProtocol.responses["/api/auth/login"] = (200, loginFixture(consent: false))

        await model.login(username: "gary", password: "pw")

        guard case .consentPending(let profile) = model.phase else {
            return XCTFail("expected consentPending, got \(model.phase)")
        }
        XCTAssertFalse(profile.consent.timetable, "consent was NOT sent with sign-in")
    }

    func testLoginWithExistingConsentSkipsTheConsentStep() async {
        StubURLProtocol.responses["/api/auth/login"] = (200, loginFixture(consent: true))

        await model.login(username: "gary", password: "pw")

        guard case .signedIn(let profile) = model.phase else {
            return XCTFail("expected signedIn, got \(model.phase)")
        }
        XCTAssertTrue(profile.consent.timetable)
    }

    func testNotNowLeavesConsentOffAndSignsIn() async {
        StubURLProtocol.responses["/api/auth/login"] = (200, loginFixture(consent: false))
        // /api/me after the choice reflects consent still off.
        StubURLProtocol.responses["/api/me"] = (200, Data("""
        {
          "honeyId": "h1", "displayName": "Gary", "isAdmin": false,
          "consent": { "timetable": false },
          "connection": { "connected": true, "lastSyncedAt": null, "portalTokenValid": true }
        }
        """.utf8))
        await model.login(username: "gary", password: "pw")

        await model.completeImportConsent(importTimetable: false)

        guard case .signedIn(let profile) = model.phase else {
            return XCTFail("expected signedIn, got \(model.phase)")
        }
        XCTAssertFalse(profile.consent.timetable, "'Not now' grants nothing")
    }
}

private actor FailingClearOwnershipKeyStore: OwnershipKeyStoring {
    enum Failure: Error { case unavailable }

    func map() throws -> [String: String] { [:] }
    func keys() throws -> [String] { [] }
    func ownershipKey(for experienceId: String) throws -> String? { nil }
    func add(experienceId: String, ownershipKey: String) throws {}
    func remove(experienceId: String) throws {}
    func clear() throws { throw Failure.unavailable }
}
