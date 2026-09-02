import XCTest
@testable import HOneyCore

/// Review 11d42e3 §3.1: nothing account-scoped leaks across accounts, and
/// nothing account-scoped is readable or writable while signed out.
final class AccountScopeTests: XCTestCase {
    func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("honey-scope-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testDraftsArePerAccountAndVerified() throws {
        let drafts = ComposerDraftStore(directory: tempDir())
        XCTAssertThrowsError(try drafts.save(targetKey: "teacher:t1", body: "x", rating: nil)) { error in
            XCTAssertEqual(error as? ComposerDraftStoreError, .noAccount)
        }
        XCTAssertNil(drafts.get("teacher:t1"), "signed out reads nothing")
        drafts.setAccount("h_a")
        try drafts.save(targetKey: "teacher:t1", body: "A's words", rating: nil)
        XCTAssertEqual(drafts.get("teacher:t1")?.body, "A's words")
        drafts.setAccount("h_b")
        XCTAssertNil(drafts.get("teacher:t1"), "same target key, other account: nothing")
        try drafts.save(targetKey: "teacher:t1", body: "B's words", rating: 3)
        drafts.setAccount("h_a")
        XCTAssertEqual(drafts.get("teacher:t1")?.body, "A's words", "A's draft survived B's")
        try drafts.clear("teacher:t1")
        XCTAssertNil(drafts.get("teacher:t1"))
        drafts.setAccount(nil)
        XCTAssertNil(drafts.get("teacher:t1"))
    }

    func testDraftSaveFailsLoudlyWhenTheDirectoryIsAFile() throws {
        let dir = tempDir()
        // Make "drafts" a file so the directory cannot be created.
        try Data("x".utf8).write(to: dir.appendingPathComponent("drafts"))
        let drafts = ComposerDraftStore(directory: dir)
        drafts.setAccount("h_a")
        XCTAssertThrowsError(try drafts.save(targetKey: "lesson:1", body: "y", rating: nil))
    }

    func testPreferencesArePerAccountExceptDeviceLevel() {
        let defaults = UserDefaults(suiteName: "honey-scope-\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        prefs.rememberContext(RecentContext(name: "x", type: .teacher, entityId: "t"))
        XCTAssertEqual(prefs.recentContexts, [], "signed out: writes dropped")
        prefs.firstPublishDisclosureSeen = true
        XCTAssertFalse(prefs.firstPublishDisclosureSeen)

        prefs.setAccount("h_a")
        prefs.rememberContext(RecentContext(name: "朱昂明", type: .teacher, entityId: "t1"))
        prefs.firstPublishDisclosureSeen = true
        prefs.feedScope = .school
        prefs.exploreCategory = .dish
        prefs.background = .night

        prefs.setAccount("h_b")
        XCTAssertEqual(prefs.recentContexts, [])
        XCTAssertFalse(prefs.firstPublishDisclosureSeen, "the disclosure is per account")
        XCTAssertEqual(prefs.feedScope, .myClasses)
        XCTAssertEqual(prefs.exploreCategory, .teacher)
        XCTAssertEqual(prefs.background, .night, "appearance is device-level")

        prefs.setAccount("h_a")
        XCTAssertEqual(prefs.recentContexts.map(\.name), ["朱昂明"])
        XCTAssertTrue(prefs.firstPublishDisclosureSeen)
        XCTAssertEqual(prefs.feedScope, .school)
    }

    func testDisclosureVersionBumpRequiresSeeingItAgain() {
        let defaults = UserDefaults(suiteName: "honey-scope-\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        prefs.setAccount("h_a")
        defaults.set(Preferences.disclosureVersion - 1, forKey: "honey.exp.firstPublishSeen.h_a")
        XCTAssertFalse(prefs.firstPublishDisclosureSeen)
    }

    func testPublicationJournalIsDurableAndPerAccount() async throws {
        let journal = PublicationJournal(directory: tempDir())
        await journal.setAccount("h_a")
        try await journal.write(PublicationRecord(experienceId: "e1", ownershipKey: "k1", targetKey: "lesson:1", createdAt: 1))
        try await journal.write(PublicationRecord(experienceId: "e2", ownershipKey: "k2", targetKey: "dish:1", createdAt: 2))
        let pending = try await journal.pending()
        XCTAssertEqual(pending.map(\.experienceId), ["e1", "e2"])
        await journal.setAccount("h_b")
        let other = try await journal.pending()
        XCTAssertEqual(other, [])
        await journal.setAccount("h_a")
        try await journal.remove(experienceId: "e1")
        let rest = try await journal.pending()
        XCTAssertEqual(rest.map(\.ownershipKey), ["k2"])
        try await journal.remove(experienceId: "e2")
        let none = try await journal.pending()
        XCTAssertEqual(none, [])
        await journal.setAccount(nil)
        do {
            try await journal.write(PublicationRecord(experienceId: "e3", ownershipKey: "k3", targetKey: "x", createdAt: 3))
            XCTFail("no account → no journal")
        } catch let error as PublicationJournalError {
            XCTAssertEqual(error, .noAccount)
        }
    }

    func testOwnershipKeysSignedOutNamespaceIsEmptyAndReadOnly() throws {
        let keys = SecretOwnershipKeyStore(store: InMemorySecretStore(), account: SecretOwnershipKeyStore.signedOutAccount)
        XCTAssertEqual(try keys.list(), [])
        XCTAssertThrowsError(try keys.add(key: "k", experienceId: "e"))
    }
}

/// Review §3.1.4: a request that started before invalidation (school sync,
/// account change) never writes into the newer cache.
final class TimetableRepositoryTests: XCTestCase {
    final class SlowProvider: TimetableProviding, @unchecked Sendable {
        var delayNs: UInt64 = 0
        var label = "A"
        private(set) var calls = 0

        func timetable(date: String) async throws -> TimetableResponse {
            calls += 1
            if delayNs > 0 { try await Task.sleep(nanoseconds: delayNs) }
            return TimetableResponse(date: date, lessons: [Lesson(id: label, subjectName: label, startsAt: 0, endsAt: 1)], lastSyncedAt: nil)
        }

        func timetableRange(from: String, to: String) async throws -> TimetableRangeResponse {
            TimetableRangeResponse(from: from, to: to, days: [], lastSyncedAt: nil)
        }

        func nextLesson() async throws -> NextLessonResponse { NextLessonResponse(nextLesson: nil, lastSyncedAt: nil) }
        func directory() async throws -> DirectoryResponse { DirectoryResponse(teachers: [], courses: [], rooms: []) }
        func entities(type: EntityType?, q: String?) async throws -> EntitiesResponse { EntitiesResponse(entities: []) }
        func history(_ params: HistoryParams) async throws -> HistoryResponse {
            calls += 1
            return HistoryResponse(lessons: [])
        }
    }

    func testLateResponseDoesNotRepopulateAfterInvalidation() async throws {
        let provider = SlowProvider()
        provider.delayNs = 150_000_000
        let repo = TimetableRepository(provider: provider)
        let first = Task { try await repo.day("2026-09-02") }
        try await Task.sleep(nanoseconds: 20_000_000)
        await repo.invalidateAll()
        do {
            _ = try await first.value
            XCTFail("the pre-invalidation request must not deliver")
        } catch is CancellationError {}
        let cached = await repo.cachedDay("2026-09-02")
        XCTAssertNil(cached, "nothing from the old generation lands in the cache")
        provider.label = "B"
        provider.delayNs = 0
        let fresh = try await repo.day("2026-09-02")
        XCTAssertEqual(fresh.lessons.first?.subjectName, "B")
    }

    func testCoalescingAndHistoryKeyIncludesBeforeAndOrder() async throws {
        let provider = SlowProvider()
        provider.delayNs = 50_000_000
        let repo = TimetableRepository(provider: provider)
        async let a = repo.day("2026-09-02")
        async let b = repo.day("2026-09-02")
        _ = try await (a, b)
        XCTAssertEqual(provider.calls, 1, "concurrent callers share one request")
        provider.delayNs = 0
        _ = try await repo.history(HistoryParams(limit: 200, order: .desc))
        _ = try await repo.history(HistoryParams(limit: 200, order: .asc))
        _ = try await repo.history(HistoryParams(before: "x", limit: 200, order: .asc))
        _ = try await repo.history(HistoryParams(limit: 200, order: .desc))
        XCTAssertEqual(provider.calls, 4, "distinct before/order are distinct cache keys; a repeat is cached")
    }
}
