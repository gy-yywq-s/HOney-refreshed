//
//  PrivateNoteStoreTests.swift
//  HOneyTests — private-note CRUD (web PrivateNoteStore parity): create,
//  update-in-place, delete, persistence across instances.
//

import XCTest
@testable import HOney

final class PrivateNoteStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-store-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private let target = PrivateNoteTarget(label: "Ms Lin · Teacher", entityKey: "teacher:t1")

    func testSaveCreatesNoteWithFreshId() async throws {
        let store = PrivateNoteStore(directory: tempDir)
        let note = try await store.save(id: nil, body: "first note", rating: nil, target: target)
        XCTAssertFalse(note.id.isEmpty)
        XCTAssertEqual(note.body, "first note")
        XCTAssertEqual(note.target.entityKey, "teacher:t1")

        let all = try await store.list()
        XCTAssertEqual(all, [note])
    }

    func testSaveWithExistingIdUpdatesInPlace() async throws {
        let store = PrivateNoteStore(directory: tempDir)
        let original = try await store.save(id: nil, body: "v1", rating: nil, target: target)
        let updated = try await store.save(id: original.id, body: "v2", rating: 5, target: target)

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt, "createdAt is preserved")
        XCTAssertGreaterThanOrEqual(updated.updatedAt, original.updatedAt)
        XCTAssertEqual(updated.body, "v2")
        XCTAssertEqual(updated.rating, 5)

        let all = try await store.list()
        XCTAssertEqual(all.count, 1, "updated, not duplicated")
    }

    func testSaveWithUnknownIdCreatesANewNote() async throws {
        let store = PrivateNoteStore(directory: tempDir)
        let note = try await store.save(id: "missing-id", body: "text", rating: nil, target: target)
        XCTAssertNotEqual(note.id, "missing-id", "an unknown id falls back to create")
        let all = try await store.list()
        XCTAssertEqual(all.count, 1)
    }

    func testNoteLookupAndRemove() async throws {
        let store = PrivateNoteStore(directory: tempDir)
        let a = try await store.save(id: nil, body: "a", rating: nil, target: target)
        let b = try await store.save(id: nil, body: "b", rating: nil, target: target)

        let found = try await store.note(id: a.id)
        XCTAssertEqual(found?.body, "a")

        try await store.remove(id: a.id)
        let all = try await store.list()
        XCTAssertEqual(all, [b])
    }

    func testNotesPersistAcrossInstances() async throws {
        let note = try await PrivateNoteStore(directory: tempDir)
            .save(id: nil, body: "durable", rating: nil, target: target)
        let reopened = PrivateNoteStore(directory: tempDir)
        let all = try await reopened.list()
        XCTAssertEqual(all, [note], "notes survive relaunch")
    }

    func testClearAllRemovesEverything() async throws {
        let store = PrivateNoteStore(directory: tempDir)
        _ = try await store.save(id: nil, body: "a", rating: nil, target: target)
        try await store.clearAll()
        let all = try await store.list()
        XCTAssertTrue(all.isEmpty)
    }
}
