//
//  ComposerDraftStoreTests.swift
//  HOneyTests — single-slot draft semantics (web composerDraft.ts parity).
//

import XCTest
@testable import HOney

final class ComposerDraftStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("draft-store-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndGetRoundTrip() async throws {
        let store = ComposerDraftStore(directory: tempDir)
        try await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        let draft = try await store.get("lesson:l1")
        XCTAssertEqual(draft?.body, "words")
        XCTAssertNil(draft?.rating)
    }

    func testSingleSlotReplacesAcrossTargets() async throws {
        let store = ComposerDraftStore(directory: tempDir)
        try await store.save(targetKey: "lesson:l1", body: "lesson words", rating: nil)
        try await store.save(targetKey: "dish:d1", body: "dish words", rating: 4)

        let old = try await store.get("lesson:l1")
        XCTAssertNil(old, "one slot only: the newer target replaced it")
        let current = try await store.get("dish:d1")
        XCTAssertEqual(current?.body, "dish words")
        XCTAssertEqual(current?.rating, 4)
    }

    func testGetIgnoresAnotherTargetsDraft() async throws {
        let store = ComposerDraftStore(directory: tempDir)
        try await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        let other = try await store.get("lesson:l2")
        XCTAssertNil(other, "a different target's draft never surfaces")
    }

    func testClearOnlyClearsMatchingTarget() async throws {
        let store = ComposerDraftStore(directory: tempDir)
        try await store.save(targetKey: "lesson:l1", body: "words", rating: nil)

        try await store.clear("lesson:l2")
        let stillThere = try await store.get("lesson:l1")
        XCTAssertEqual(stillThere?.body, "words", "clearing another target is a no-op")

        try await store.clear("lesson:l1")
        let gone = try await store.get("lesson:l1")
        XCTAssertNil(gone)
    }

    func testDraftPersistsAcrossInstances() async throws {
        try await ComposerDraftStore(directory: tempDir)
            .save(targetKey: "lesson:l1", body: "durable words", rating: nil)
        let reopened = ComposerDraftStore(directory: tempDir)
        let draft = try await reopened.get("lesson:l1")
        XCTAssertEqual(draft?.body, "durable words", "the draft survives relaunch")
    }

    func testClearAllEmptiesTheSlot() async throws {
        let store = ComposerDraftStore(directory: tempDir)
        try await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        try await store.clearAll()
        let draft = try await store.get("lesson:l1")
        XCTAssertNil(draft)
    }
}
