import Foundation
import XCTest
import BigInt
@testable import HOneyCore

/// Interop with the Web (spec §42.1): every value in the shared known-answer
/// vectors (packages/shared/src/community-v2/fixtures/vectors.json) is
/// reproduced here from the same root, epoch and nonce, and the blind-token
/// arithmetic round-trips against the checked-in test issuer key — the same
/// key the Web's own protocol tests use.
final class CommunityV2Tests: XCTestCase {
    struct Vectors: Decodable {
        let labels: [String: String]
        let root: String
        let epoch: SchoolEpoch
        let schoolSalt: String
        let postingPublicKey: String
        let authorTag: String
        let postNonce: String
        let controlPublicKey: String
        let reactionPublicKey: String
        let statement: MineStatement
        let statementCanonical: String
        let statementSignature: String
        let vaultId: String
        let vaultAadRevision3: String
        let prfInput: String
        let prfOutput: String
        let prfWrapKey: String
        let recoverySecret: String
        let recoveryWords: [String]
        let phraseWrapKey: String
    }

    static var fixturesDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("packages/shared/src/community-v2/fixtures")
    }

    func vectors() throws -> Vectors {
        try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: Self.fixturesDirectory.appendingPathComponent("vectors.json")))
    }

    func b64(_ s: String) -> Data { Base64URL.decode(s)! }

    func testLabelsMatchTheProtocol() throws {
        let v = try vectors()
        XCTAssertEqual(v.labels["schoolEpochSaltPrefix"], V2Labels.schoolEpochSaltPrefix)
        XCTAssertEqual(v.labels["postingSigning"], V2Labels.postingSigning)
        XCTAssertEqual(v.labels["postControlPrefix"], V2Labels.postControlPrefix)
        XCTAssertEqual(v.labels["authorTagPrefix"], V2Labels.authorTagPrefix)
        XCTAssertEqual(v.labels["reactionSigning"], V2Labels.reactionSigning)
        XCTAssertEqual(v.labels["vaultPrfWrap"], V2Labels.vaultPrfWrap)
        XCTAssertEqual(v.labels["vaultPhraseWrap"], V2Labels.vaultPhraseWrap)
        XCTAssertEqual(v.labels["vaultPrfInputPrefix"], V2Labels.vaultPrfInputPrefix)
    }

    func testKeyHierarchyReproducesTheVectors() throws {
        let v = try vectors()
        let root = b64(v.root)
        XCTAssertEqual(Base64URL.encode(V2Derivation.schoolSalt(v.epoch)), v.schoolSalt)
        let posting = try V2Derivation.postingKeyPair(root: root, epoch: v.epoch)
        XCTAssertEqual(Base64URL.encode(posting.publicKey), v.postingPublicKey)
        XCTAssertEqual(V2Derivation.authorTag(postingPublicKey: posting.publicKey), v.authorTag)
        let control = try V2Derivation.postControlKeyPair(root: root, postNonce: b64(v.postNonce), epoch: v.epoch)
        XCTAssertEqual(Base64URL.encode(control.publicKey), v.controlPublicKey)
        let reaction = try V2Derivation.reactionKeyPair(root: root, epoch: v.epoch)
        XCTAssertEqual(Base64URL.encode(reaction.publicKey), v.reactionPublicKey)
    }

    func testCanonicalJSONAndSignatures() throws {
        let v = try vectors()
        let statement = try JSONValue(encoding: v.statement)
        XCTAssertEqual(statement.canonical, v.statementCanonical)
        let posting = try V2Derivation.postingKeyPair(root: b64(v.root), epoch: v.epoch)
        // The Web's signature verifies under the derived key …
        XCTAssertTrue(V2Derivation.verifyStatement(publicKey: posting.publicKey, statement: statement, signature: b64(v.statementSignature)))
        // … and ours verifies too (Ed25519 signatures may be randomized on Apple platforms, so bytes are not compared).
        let ours = try V2Derivation.signStatement(privateKey: posting.privateKey, statement: statement)
        XCTAssertTrue(V2Derivation.verifyStatement(publicKey: posting.publicKey, statement: statement, signature: ours))
        XCTAssertFalse(V2Derivation.verifyStatement(publicKey: posting.publicKey, statement: .object(["purpose": .string("x")]), signature: ours))
        // JCS details: key order by UTF-16, escapes, integers, nested nulls.
        let tricky = JSONValue.object(["b": .int(1), "a": .array([.null, .bool(true), .string("q\"\\\n\u{1}é")]), "é": .double(0.5), "Z": .double(3)])
        XCTAssertEqual(tricky.canonical, "{\"Z\":3,\"a\":[null,true,\"q\\\"\\\\\\n\\u0001é\"],\"b\":1,\"é\":0.5}")
        XCTAssertEqual(ControlVault.aad(vaultId: v.vaultId, revision: 3), Data(v.vaultAadRevision3.utf8))
    }

    func testEnvelopeSignsRatingNullExactlyLikeTheWeb() throws {
        let envelope = SignedPostEnvelopeV2(schoolId: "s", academicYear: "y", primaryEntity: EnvelopeEntity(type: "lesson", id: "l1"), contexts: EnvelopeContexts(courseId: "c1"), body: "words", rating: nil, postNonce: "n", postingPublicKey: "p", controlPublicKey: "k", clientNonce: "c")
        let canonical = try JSONValue(encoding: envelope).canonical
        XCTAssertEqual(canonical, "{\"academicYear\":\"y\",\"body\":\"words\",\"clientNonce\":\"c\",\"contexts\":{\"courseId\":\"c1\"},\"controlPublicKey\":\"k\",\"postNonce\":\"n\",\"postingPublicKey\":\"p\",\"primaryEntity\":{\"id\":\"l1\",\"type\":\"lesson\"},\"protocolVersion\":2,\"rating\":null,\"schoolId\":\"s\"}")
    }

    func testWrappersAndRecoveryWordsReproduceTheVectors() throws {
        let v = try vectors()
        XCTAssertEqual(Base64URL.encode(VaultWrappers.prfInput(vaultId: v.vaultId)), v.prfInput)
        XCTAssertEqual(Base64URL.encode(try VaultWrappers.prfWrapKey(prfOutput: b64(v.prfOutput), vaultId: v.vaultId)), v.prfWrapKey)
        XCTAssertEqual(Base64URL.encode(try VaultWrappers.phraseWrapKey(recoverySecret: b64(v.recoverySecret), vaultId: v.vaultId)), v.phraseWrapKey)
        XCTAssertEqual(try RecoveryWords.words(from: b64(v.recoverySecret)), v.recoveryWords)
        XCTAssertEqual(RecoveryWords.secret(from: v.recoveryWords.joined(separator: "  ").uppercased()), b64(v.recoverySecret))
        var wrong = v.recoveryWords
        wrong[3] = wrong[3] == "abandon" ? "zoo" : "abandon"
        XCTAssertNil(RecoveryWords.secret(from: wrong), "a wrong word fails the checksum")
        XCTAssertNil(RecoveryWords.secret(from: Array(v.recoveryWords.prefix(11))))
        // wrap/unwrap round trips, and the wrong secret is refused
        let r = Data.random(32)
        let phrase = try VaultWrappers.wrapWithPhrase(recoverySecret: b64(v.recoverySecret), vaultId: v.vaultId, r: r, now: 1)
        XCTAssertEqual(try VaultWrappers.unwrapWithPhrase(recoverySecret: b64(v.recoverySecret), vaultId: v.vaultId, wrapper: phrase), r)
        XCTAssertThrowsError(try VaultWrappers.unwrapWithPhrase(recoverySecret: Data.random(16), vaultId: v.vaultId, wrapper: phrase))
        let prf = try VaultWrappers.wrapWithPrf(prfOutput: b64(v.prfOutput), vaultId: v.vaultId, credentialId: "cred", r: r, now: 1)
        XCTAssertEqual(try VaultWrappers.unwrapWithPrf(prfOutput: b64(v.prfOutput), vaultId: v.vaultId, wrapper: prf), r)
        let device = Data.random(32)
        let dw = try VaultWrappers.wrapWithDevice(deviceSecret: device, vaultId: v.vaultId, r: r)
        XCTAssertEqual(try VaultWrappers.unwrapWithDevice(deviceSecret: device, vaultId: v.vaultId, wrapped: dw), r)
    }

    func testVaultSealOpenRotateMerge() throws {
        let r = Data.random(32)
        let m = Data.random(32)
        let root = ControlVault.newRootRecord(secret: m, now: 10)
        let epoch = SchoolEpoch(schoolId: "huayaopudong", academicYear: "2026-27")
        let payload = ControlVault.initialPayload(root: root, epochs: [epoch], now: 10)
        let sealed = try ControlVault.seal(r: r, vaultId: "v1", revision: 1, payload: payload)
        let opened = try ControlVault.open(r: r, vaultId: "v1", revision: 1, iv: sealed.iv, ciphertext: sealed.ciphertext)
        XCTAssertEqual(opened, payload)
        XCTAssertThrowsError(try ControlVault.open(r: r, vaultId: "v1", revision: 2, iv: sealed.iv, ciphertext: sealed.ciphertext), "the revision is authenticated")
        XCTAssertThrowsError(try ControlVault.open(r: Data.random(32), vaultId: "v1", revision: 1, iv: sealed.iv, ciphertext: sealed.ciphertext))

        let rotated = ControlVault.rotated(payload, newSecret: Data.random(32), now: 20)
        XCTAssertEqual(rotated.roots.count, 2)
        XCTAssertEqual(rotated.roots[0].state, "legacy")
        XCTAssertEqual(try ControlVault.activeRoot(rotated).rootId, rotated.activeRootId)
        // merge: the side that retired the other's active root wins
        let merged = try ControlVault.merge(local: rotated, remote: payload, now: 30)
        XCTAssertEqual(merged.activeRootId, rotated.activeRootId)
        XCTAssertEqual(merged.roots.count, 2)
        // contradictory rotations are refused
        let other = ControlVault.rotated(payload, newSecret: Data.random(32), now: 21)
        XCTAssertThrowsError(try ControlVault.merge(local: rotated, remote: other, now: 30))
        // wrappers merge by stable id
        let w1 = VaultWrapper.recoveryPhrase(RecoveryPhraseWrapper(iv: "i", wrappedR: "a", createdAt: 1))
        let w2 = VaultWrapper.passkeyPrf(PasskeyPrfWrapper(credentialId: "c", prfInput: "p", iv: "i", wrappedR: "b", createdAt: 1))
        XCTAssertEqual(ControlVault.mergeWrappers(local: [w1], remote: [w2, w1]).count, 2)
        // unknown wrapper kinds survive a decode/encode round trip
        let raw = Data("[{\"type\":\"future\",\"x\":1},{\"type\":\"recovery_phrase\",\"format\":\"words12-v1\",\"iv\":\"i\",\"wrappedR\":\"w\",\"createdAt\":5}]".utf8)
        let wrappers = try WireCoding.decode([VaultWrapper].self, from: raw)
        XCTAssertEqual(wrappers.count, 2)
        if case .unknown = wrappers[0] {} else { XCTFail("unknown kind should be carried through") }
        let reencoded = try JSONValue(encoding: wrappers).canonical
        XCTAssertTrue(reencoded.contains("\"type\":\"future\""))
    }

    func testPairingSealsRToTheNewDeviceOnly() throws {
        let newDevice = Pairing.newKeyPair()
        let r = Data.random(32)
        let sealed = try Pairing.seal(recipientPublicKey: newDevice.publicKey, pairingId: "pair-1", r: r)
        XCTAssertEqual(try Pairing.open(privateKey: newDevice.privateKey, pairingId: "pair-1", enc: sealed.enc, ciphertext: sealed.ciphertext), r)
        XCTAssertThrowsError(try Pairing.open(privateKey: newDevice.privateKey, pairingId: "pair-2", enc: sealed.enc, ciphertext: sealed.ciphertext), "the pairing id is authenticated")
        XCTAssertThrowsError(try Pairing.open(privateKey: Pairing.newKeyPair().privateKey, pairingId: "pair-1", enc: sealed.enc, ciphertext: sealed.ciphertext))
    }

    // MARK: blind tokens against the shared test issuer key

    struct TestIssuerKey: Decodable {
        struct Private: Decodable { let n: String; let e: String; let p: String; let q: String }
        struct Public: Decodable { let n: String; let e: String }
        let `private`: Private
        let `public`: Public
        let purpose: String
    }

    func testIssuerKey() throws -> TestIssuerKey {
        try JSONDecoder().decode(TestIssuerKey.self, from: Data(contentsOf: Self.fixturesDirectory.appendingPathComponent("issuer-test.jwk.json")))
    }

    func testBlindTokenRoundTripWithTheSharedTestKey() throws {
        let key = try testIssuerKey()
        XCTAssertEqual(key.purpose, "test")
        let pk = try IssuerRSAPublicKey(descriptor: IssuerDescriptor(suite: BlindToken.suite, keyId: "kat", publicKey: .init(n: key.public.n, e: key.public.e)))
        XCTAssertEqual(pk.modulusBits, 2048)
        let info = EligibilityInfo(schoolId: "huayaopudong", academicYear: "2026-27", scope: "lesson:L1", contexts: EligibilityContexts(lessonId: "L1", courseId: "c1"), provenance: "verified_lesson", week: 40)
        let infoBytes = try BlindToken.infoBytes(info)
        XCTAssertEqual(String(decoding: infoBytes, as: UTF8.self), "{\"academicYear\":\"2026-27\",\"contexts\":{\"courseId\":\"c1\",\"lessonId\":\"L1\"},\"provenance\":\"verified_lesson\",\"schoolId\":\"huayaopudong\",\"scope\":\"lesson:L1\",\"v\":2,\"week\":40}")

        let message = BlindToken.prepare(Data.random(32))
        XCTAssertEqual(message.count, 64)
        let blinded = try BlindToken.blind(publicKey: pk, message: message, info: infoBytes)
        XCTAssertEqual(blinded.blindedMessage.count, 256)
        // The issuer's side (test-only here): sign with the derived private exponent.
        let blindSig = try BlindToken.blindSign(n: pk.n, p: BigUInt(b64(key.private.p)), q: BigUInt(b64(key.private.q)), blindedMessage: blinded.blindedMessage, info: infoBytes)
        let signature = try BlindToken.finalize(publicKey: pk, blinded: blinded, blindSignature: blindSig)
        XCTAssertTrue(BlindToken.verify(publicKey: pk, signature: signature, message: message, info: infoBytes))
        // Bound to the info: a different scope does not verify; neither does another message.
        var otherInfo = info
        otherInfo.scope = "lesson:L2"
        XCTAssertFalse(BlindToken.verify(publicKey: pk, signature: signature, message: message, info: try BlindToken.infoBytes(otherInfo)))
        XCTAssertFalse(BlindToken.verify(publicKey: pk, signature: signature, message: BlindToken.prepare(Data.random(32)), info: infoBytes))
    }

    func testWebIssuedTokenVerifiesHere() throws {
        // A token produced by the TypeScript implementation with the same test key (vectors:write).
        let url = Self.fixturesDirectory.appendingPathComponent("blind-token-kat.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("blind-token-kat.json not generated yet")
        }
        struct KAT: Decodable { let keyId: String; let info: EligibilityInfo; let message: String; let signature: String; let issuerPublicKey: IssuerDescriptor.PublicKey }
        let kat = try JSONDecoder().decode(KAT.self, from: Data(contentsOf: url))
        let pk = try IssuerRSAPublicKey(descriptor: IssuerDescriptor(suite: BlindToken.suite, keyId: kat.keyId, publicKey: kat.issuerPublicKey))
        XCTAssertTrue(BlindToken.verify(publicKey: pk, signature: b64(kat.signature), message: b64(kat.message), info: try BlindToken.infoBytes(kat.info)))
    }
}
