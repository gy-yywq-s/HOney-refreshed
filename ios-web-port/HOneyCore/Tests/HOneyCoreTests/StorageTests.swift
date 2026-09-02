import XCTest
@testable import HOneyCore

final class PrivateNoteStoreTests: XCTestCase {
    func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("honey-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRoundTripPreservesCreatedAtAndIsNamespaced() async throws {
        let store = PrivateNoteStore(directory: tempDir())
        await store.setAccount("h_1")
        let target = PrivateNoteTarget(label: "Noodles", entityKey: "dish:a_123", entityType: "dish")
        let saved = try await store.save(body: "the-canteen-noodles", rating: 4, target: target)
        XCTAssertFalse(saved.id.isEmpty)
        let listed = try await store.list()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed[0].body, "the-canteen-noodles")
        XCTAssertEqual(listed[0].rating, 4)

        let updated = try await store.save(id: saved.id, body: "edited", rating: nil, target: target, cooldown: .some(NoteCooldown(until: 5, ticket: "t")))
        XCTAssertEqual(updated.createdAt, saved.createdAt)
        let reloaded = try await store.note(id: saved.id)
        XCTAssertEqual(reloaded?.cooldown?.ticket, "t")
        let kept = try await store.save(id: saved.id, body: "edited again", rating: nil, target: target)
        XCTAssertEqual(kept.cooldown?.ticket, "t", "omitting cooldown keeps it")
        let cleared = try await store.save(id: saved.id, body: "calm", rating: nil, target: target, cooldown: .some(nil))
        XCTAssertNil(cleared.cooldown)

        await store.setAccount("h_2")
        let other = try await store.list()
        XCTAssertEqual(other.count, 0, "another account sees nothing")
        await store.setAccount("h_1")
        try await store.remove(id: saved.id)
        let after = try await store.list()
        XCTAssertEqual(after.count, 0)
    }

    func testNoAccountRefusesToWrite() async {
        let store = PrivateNoteStore(directory: tempDir())
        do {
            _ = try await store.save(body: "x", rating: nil, target: PrivateNoteTarget(label: "x"))
            XCTFail()
        } catch let error as PrivateNoteStoreError {
            XCTAssertEqual(error, .noAccount)
        } catch { XCTFail("\(error)") }
    }

    func testFileCarriesVersionAndAccount() async throws {
        let dir = tempDir()
        let store = PrivateNoteStore(directory: dir)
        await store.setAccount("h_1")
        _ = try await store.save(body: "x", rating: nil, target: PrivateNoteTarget(label: "x"))
        let file = dir.appendingPathComponent("notes/h_1.v1.json")
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        XCTAssertEqual(obj["version"] as? Int, 1)
        XCTAssertEqual(obj["account"] as? String, "h_1")
    }
}

final class OwnershipKeyStoreTests: XCTestCase {
    func testAddListRemoveNamespaced() throws {
        let secrets = InMemorySecretStore()
        let store = SecretOwnershipKeyStore(store: secrets, account: "h_1")
        XCTAssertEqual(try store.list(), [])
        try store.add(key: "ok-1", experienceId: "e-1")
        try store.add(key: "ok-2", experienceId: "e-2")
        XCTAssertEqual(try store.list().map(\.key), ["ok-1", "ok-2"])
        XCTAssertEqual(try store.list()[0].kind, "public")
        XCTAssertEqual(SecretOwnershipKeyStore(store: secrets, account: "h_1").count(), 2, "a fresh store over the same secrets sees the same keys")
        XCTAssertEqual(SecretOwnershipKeyStore(store: secrets, account: "h_2").count(), 0, "another account sees nothing")
        try store.remove(key: "ok-1")
        XCTAssertEqual(try store.list().map(\.key), ["ok-2"])
    }

    func testExportImportIsTheWebFileShape() throws {
        let a = SecretOwnershipKeyStore(store: InMemorySecretStore(), account: "h")
        try a.add(key: "ok-1", experienceId: "e-1")
        try a.add(key: "ok-2", experienceId: "e-2")
        let exported = try a.exportJSON()
        let obj = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        XCTAssertEqual(obj["version"] as? Int, 1)
        XCTAssertEqual((obj["keys"] as? [[String: Any]])?.count, 2)

        let b = SecretOwnershipKeyStore(store: InMemorySecretStore(), account: "h")
        try b.add(key: "ok-2", experienceId: "e-2")
        XCTAssertEqual(try b.importJSON(exported), 1)
        XCTAssertEqual(b.count(), 2)
        XCTAssertThrowsError(try b.importJSON(Data(#"{"hello":"world"}"#.utf8)))
        XCTAssertEqual(b.count(), 2)

        // The Web's literal export file
        let web = #"{"version":1,"keys":[{"key":"ok-9","experienceId":"e-9","createdAt":1788000000000,"kind":"public"}]}"#
        XCTAssertEqual(try b.importJSON(Data(web.utf8)), 1)
    }

    func testKeychainWriteFailureSurfaces() {
        let secrets = InMemorySecretStore()
        secrets.failWrites = true
        let store = SecretOwnershipKeyStore(store: secrets, account: "h")
        XCTAssertThrowsError(try store.add(key: "k", experienceId: "e"))
    }
}

final class LocalStoresTests: XCTestCase {
    func testComposerDraftSlotIsKeyedByTarget() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let drafts = ComposerDraftStore(directory: dir)
        drafts.save(targetKey: "lesson:1", body: "hello", rating: nil)
        XCTAssertEqual(drafts.get("lesson:1")?.body, "hello")
        XCTAssertNil(drafts.get("dish:2"))
        drafts.clear("dish:2")
        XCTAssertNotNil(drafts.get("lesson:1"), "clearing another target leaves the slot")
        drafts.clear("lesson:1")
        XCTAssertNil(drafts.get("lesson:1"))
    }

    func testPreferencesDefaults() {
        let defaults = UserDefaults(suiteName: "honey-tests-\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        XCTAssertTrue(prefs.stayConnectedWanted, "saved login is wanted by default")
        prefs.stayConnectedWanted = false
        XCTAssertFalse(prefs.stayConnectedWanted)
        XCTAssertEqual(prefs.feedScope, .myClasses)
        XCTAssertEqual(prefs.language, .system)
        XCTAssertEqual(prefs.appearance, .system)
        prefs.rememberContext(RecentContext(name: "朱昂明", type: .teacher, entityId: "t1"))
        prefs.rememberContext(RecentContext(name: "309", type: .room, entityId: "r1"))
        prefs.rememberContext(RecentContext(name: "朱昂明", type: .teacher, entityId: "t1"))
        XCTAssertEqual(prefs.recentContexts.map(\.name), ["朱昂明", "309"])
    }

    func testTransferBundleAcceptsBothShapes() async throws {
        let keysOnly = #"{"version":1,"keys":[{"key":"k1","experienceId":"e1","createdAt":1,"kind":"public"}]}"#
        let bundle = try TransferBundle.decode(Data(keysOnly.utf8))
        XCTAssertEqual(bundle.ownershipKeys.count, 1)
        let full = """
        {"version":1,"accountHint":"h_1","privateNotes":[{"id":"n1","body":"kept","rating":null,"target":{"label":"Ms Lin"},"cooldown":null,"createdAt":1,"updatedAt":2}],
         "ownershipKeys":[{"key":"k2","experienceId":"e2","createdAt":1,"kind":"public"},{"key":"","experienceId":"bad","createdAt":1,"kind":"public"}]}
        """
        let b2 = try TransferBundle.decode(Data(full.utf8))
        XCTAssertEqual(b2.accountHint, "h_1")
        XCTAssertEqual(b2.privateNotes.first?.body, "kept")
        XCTAssertEqual(b2.ownershipKeys.count, 1, "invalid entries dropped")
        XCTAssertThrowsError(try TransferBundle.decode(Data(#"{"version":2}"#.utf8)))

        let keys = SecretOwnershipKeyStore(store: InMemorySecretStore(), account: "h_1")
        let notes = PrivateNoteStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await notes.setAccount("h_1")
        let report = await b2.apply(keys: keys, notes: notes)
        XCTAssertEqual(report.keysAdded, 1)
        XCTAssertEqual(report.notesAdded, 1)
        XCTAssertTrue(report.failures.isEmpty)
        let again = await b2.apply(keys: keys, notes: notes)
        XCTAssertEqual(again.keysAdded, 0)
        XCTAssertEqual(again.notesAdded, 0, "deduplicated")
    }
}
