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

    func testSaveAndGetRoundTrip() async {
        let store = ComposerDraftStore(directory: tempDir)
        await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        let draft = await store.get("lesson:l1")
        XCTAssertEqual(draft?.body, "words")
        XCTAssertNil(draft?.rating)
    }

    func testSingleSlotReplacesAcrossTargets() async {
        let store = ComposerDraftStore(directory: tempDir)
        await store.save(targetKey: "lesson:l1", body: "lesson words", rating: nil)
        await store.save(targetKey: "dish:d1", body: "dish words", rating: 4)

        let old = await store.get("lesson:l1")
        XCTAssertNil(old, "one slot only: the newer target replaced it")
        let current = await store.get("dish:d1")
        XCTAssertEqual(current?.body, "dish words")
        XCTAssertEqual(current?.rating, 4)
    }

    func testGetIgnoresAnotherTargetsDraft() async {
        let store = ComposerDraftStore(directory: tempDir)
        await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        let other = await store.get("lesson:l2")
        XCTAssertNil(other, "a different target's draft never surfaces")
    }

    func testClearOnlyClearsMatchingTarget() async {
        let store = ComposerDraftStore(directory: tempDir)
        await store.save(targetKey: "lesson:l1", body: "words", rating: nil)

        await store.clear("lesson:l2")
        let stillThere = await store.get("lesson:l1")
        XCTAssertEqual(stillThere?.body, "words", "clearing another target is a no-op")

        await store.clear("lesson:l1")
        let gone = await store.get("lesson:l1")
        XCTAssertNil(gone)
    }

    func testDraftPersistsAcrossInstances() async {
        await ComposerDraftStore(directory: tempDir)
            .save(targetKey: "lesson:l1", body: "durable words", rating: nil)
        let reopened = ComposerDraftStore(directory: tempDir)
        let draft = await reopened.get("lesson:l1")
        XCTAssertEqual(draft?.body, "durable words", "the draft survives relaunch")
    }

    func testClearAllEmptiesTheSlot() async {
        let store = ComposerDraftStore(directory: tempDir)
        await store.save(targetKey: "lesson:l1", body: "words", rating: nil)
        await store.clearAll()
        let draft = await store.get("lesson:l1")
        XCTAssertNil(draft)
    }
}
