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

/// Post controls on the device (spec §35): the roots live in the Keychain
/// sealed under a per-account device secret; nothing is readable across
/// accounts; a Keychain that refuses to write surfaces, never pretends.
final class PostControlStoreTests: XCTestCase {
    struct NoVault: VaultAPI {
        var record: VaultRecord?
        func vault() async throws -> VaultRecord? { record }
        func vaultPut(_ request: VaultPutRequest) async throws -> VaultPutResponse { .ok(revision: request.baseRevision + 1, updatedAt: 1) }
        func vaultDelete() async throws {}
        func vaultPairingOffer(recipientPublicKey: String) async throws -> PairingOffer { PairingOffer(pairingId: "p", recipientPublicKey: recipientPublicKey, expiresAt: 0) }
        func vaultPairingRead(pairingId: String) async throws -> PairingOffer { PairingOffer(pairingId: pairingId, recipientPublicKey: "", expiresAt: 0) }
        func vaultPairingDeliver(pairingId: String, enc: String, ciphertext: String) async throws {}
        func vaultPairingClaim(pairingId: String) async throws -> PairingDelivery? { nil }
    }

    func testRootsAreSealedPerAccountAndReadBack() async throws {
        let secrets = InMemorySecretStore()
        let controls = PostControls(api: NoVault(), storage: SecretPostControlStore(store: secrets))
        let epoch = SchoolEpoch(schoolId: "huayaopudong", academicYear: "2026-27")
        let status = try await controls.status(account: "h_1")
        XCTAssertEqual(status, .none)
        let roots = try await controls.create(account: "h_1", epoch: epoch)
        XCTAssertEqual(roots.roots.count, 1)
        XCTAssertEqual(roots.active.state, "active")
        let again = try await controls.unlock(account: "h_1")
        XCTAssertEqual(again, roots, "the same roots come back from the Keychain")
        let other = try await controls.unlock(account: "h_2")
        XCTAssertNil(other, "another account sees nothing")
        // The Keychain never holds a root or R in the clear.
        for name in try secrets.keys(withPrefix: "honey.v2.") {
            let bytes = try secrets.read(name) ?? Data()
            XCTAssertFalse(bytes.range(of: roots.active.secret) != nil, "root in the clear at \(name)")
            XCTAssertFalse(bytes.range(of: roots.r) != nil, "R in the clear at \(name)")
        }
        if case .localOnly(let local) = try await controls.status(account: "h_1") { XCTAssertEqual(local, roots) } else { XCTFail("local only") }
        try await controls.eraseLocal(account: "h_1")
        let erased = try await controls.unlock(account: "h_1")
        XCTAssertNil(erased)
    }

    func testKeychainWriteFailureSurfaces() async {
        let secrets = InMemorySecretStore()
        secrets.failWrites = true
        let controls = PostControls(api: NoVault(), storage: SecretPostControlStore(store: secrets))
        do {
            _ = try await controls.create(account: "h", epoch: SchoolEpoch(schoolId: "s", academicYear: "y"))
            XCTFail("a refused write must not report a created root")
        } catch {}
    }
}

final class LocalStoresTests: XCTestCase {
    func testComposerDraftSlotIsKeyedByTarget() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let drafts = ComposerDraftStore(directory: dir)
        drafts.setAccount("h_1")
        try drafts.save(targetKey: "lesson:1", body: "hello", rating: nil)
        XCTAssertEqual(drafts.get("lesson:1")?.body, "hello")
        XCTAssertNil(drafts.get("dish:2"))
        try drafts.clear("dish:2")
        XCTAssertNotNil(drafts.get("lesson:1"), "clearing another target leaves the slot")
        try drafts.clear("lesson:1")
        XCTAssertNil(drafts.get("lesson:1"))
    }

    func testPreferencesDefaults() {
        let defaults = UserDefaults(suiteName: "honey-tests-\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        prefs.setAccount("h_1")
        XCTAssertTrue(prefs.stayConnectedWanted, "saved login is wanted by default")
        prefs.stayConnectedWanted = false
        XCTAssertFalse(prefs.stayConnectedWanted)
        XCTAssertEqual(prefs.feedScope, .myClasses)
        XCTAssertEqual(prefs.language, .system)
        XCTAssertNil(prefs.background)
        prefs.rememberContext(RecentContext(name: "朱昂明", type: .teacher, entityId: "t1"))
        prefs.rememberContext(RecentContext(name: "309", type: .room, entityId: "r1"))
        prefs.rememberContext(RecentContext(name: "朱昂明", type: .teacher, entityId: "t1"))
        XCTAssertEqual(prefs.recentContexts.map(\.name), ["朱昂明", "309"])
    }

    func testTransferBundleCarriesNotesOnly() async throws {
        let full = """
        {"version":1,"accountHint":"h_1","privateNotes":[{"id":"n1","body":"kept","rating":null,"target":{"label":"Ms Lin"},"cooldown":null,"createdAt":1,"updatedAt":2}]}
        """
        let b2 = try TransferBundle.decode(Data(full.utf8))
        XCTAssertEqual(b2.accountHint, "h_1")
        XCTAssertEqual(b2.privateNotes.first?.body, "kept")
        XCTAssertThrowsError(try TransferBundle.decode(Data(#"{"version":2}"#.utf8)))
        // A v1 key export is not a bundle any more: post controls travel through the vault.
        let keysOnly = #"{"version":1,"keys":[{"key":"k1","experienceId":"e1","createdAt":1,"kind":"public"}]}"#
        XCTAssertEqual(try TransferBundle.decode(Data(keysOnly.utf8)).privateNotes.count, 0)

        let notes = PrivateNoteStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await notes.setAccount("h_1")
        let report = await b2.apply(notes: notes)
        XCTAssertEqual(report.notesAdded, 1)
        XCTAssertTrue(report.failures.isEmpty)
        let again = await b2.apply(notes: notes)
        XCTAssertEqual(again.notesAdded, 0, "deduplicated")
    }

    func testReactionMemoryIsPerAccount() {
        let prefs = Preferences(defaults: UserDefaults(suiteName: "honey-tests-\(UUID().uuidString)")!)
        prefs.setAccount("h_1")
        XCTAssertEqual(prefs.myReaction("e1"), 0)
        prefs.setMyReaction("e1", 1)
        XCTAssertEqual(prefs.myReaction("e1"), 1)
        prefs.setReactorRegistered("mark")
        XCTAssertTrue(prefs.reactorRegistered("mark"))
        prefs.setAccount("h_2")
        XCTAssertEqual(prefs.myReaction("e1"), 0, "another account remembers nothing")
        XCTAssertFalse(prefs.reactorRegistered("mark"))
        prefs.setAccount("h_1")
        prefs.setMyReaction("e1", 0)
        XCTAssertEqual(prefs.myReaction("e1"), 0)
    }
}
