// The key hierarchy (spec §30): one client-generated root M; per school/year
// posting identity; per-post control keys; purpose-separated subkeys.
// HKDF-SHA-256 + Ed25519 from swift-crypto, so the iPhone derives exactly
// the keys the Web derives (checked against fixtures/vectors.json).
// Mirrors packages/shared/src/community-v2/derivation.ts.

import Crypto
import Foundation

public struct SchoolEpoch: Codable, Sendable, Equatable, Hashable {
    public var schoolId: String
    public var academicYear: String
    public init(schoolId: String, academicYear: String) {
        self.schoolId = schoolId
        self.academicYear = academicYear
    }
}

/// An Ed25519 key pair; `privateKey` is the 32-byte seed.
public struct Ed25519KeyPair: Sendable, Equatable {
    public let publicKey: Data
    public let privateKey: Data

    init(seed: Data) throws {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        publicKey = key.publicKey.rawRepresentation
        privateKey = seed
    }
}

public enum V2Derivation {
    static func hkdf32(ikm: Data, salt: Data, info: Data) -> Data {
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: ikm), salt: salt, info: info, outputByteCount: 32)
        return key.withUnsafeBytes { Data($0) }
    }

    /// schoolSalt = SHA-256("honey/v2/school-epoch\0" ‖ schoolId ‖ "\0" ‖ academicYear).
    public static func schoolSalt(_ epoch: SchoolEpoch) -> Data {
        Data(SHA256.hash(data: Data.concat(Data.utf8(V2Labels.schoolEpochSaltPrefix), Data.utf8(epoch.schoolId), Data.utf8("\0"), Data.utf8(epoch.academicYear))))
    }

    /// The stable school/year posting identity: same root + epoch → same key.
    public static func postingKeyPair(root: Data, epoch: SchoolEpoch) throws -> Ed25519KeyPair {
        try Ed25519KeyPair(seed: hkdf32(ikm: root, salt: schoolSalt(epoch), info: Data.utf8(V2Labels.postingSigning)))
    }

    /// Internal Community linkage handle — never public, never joined across years.
    public static func authorTag(postingPublicKey: Data) -> String {
        Data(SHA256.hash(data: Data.concat(Data.utf8(V2Labels.authorTagPrefix), postingPublicKey))).hexString
    }

    /// Per-post control key: root + postNonce (32 bytes) + epoch → independent key.
    public static func postControlKeyPair(root: Data, postNonce: Data, epoch: SchoolEpoch) throws -> Ed25519KeyPair {
        guard postNonce.count == 32 else { throw V2Error.invalidInput("postNonce must be 32 bytes") }
        let info = Data.concat(Data.utf8(V2Labels.postControlPrefix), Data.utf8(epoch.schoolId), Data.utf8("\0"), Data.utf8(epoch.academicYear))
        return try Ed25519KeyPair(seed: hkdf32(ikm: root, salt: postNonce, info: info))
    }

    /// Reaction/report identity per school/year — a different purpose, an unlinkable key.
    public static func reactionKeyPair(root: Data, epoch: SchoolEpoch) throws -> Ed25519KeyPair {
        try Ed25519KeyPair(seed: hkdf32(ikm: root, salt: schoolSalt(epoch), info: Data.utf8(V2Labels.reactionSigning)))
    }

    public static func reactorTag(reactionPublicKey: Data) -> String {
        Data(SHA256.hash(data: Data.concat(Data.utf8(V2Labels.reactorTagPrefix), reactionPublicKey))).hexString
    }

    /// Device-local private-notes key (never uploaded).
    public static func privateNotesKey(root: Data, deviceSalt: Data) -> Data {
        hkdf32(ikm: root, salt: deviceSalt, info: Data.utf8(V2Labels.privateNotesLocal))
    }

    /// Sign the JCS bytes of a statement.
    public static func signStatement(privateKey seed: Data, statement: JSONValue) throws -> Data {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        return try key.signature(for: statement.canonicalData)
    }

    public static func signStatement<T: Encodable>(privateKey seed: Data, _ statement: T) throws -> Data {
        try signStatement(privateKey: seed, statement: JSONValue(encoding: statement))
    }

    public static func verifyStatement(publicKey: Data, statement: JSONValue, signature: Data) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else { return false }
        return key.isValidSignature(signature, for: statement.canonicalData)
    }

    public static func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).hexString
    }
}

public enum V2Error: Error, Sendable, Equatable {
    case invalidInput(String)
    case vaultInvalid(String)
    case vaultConflict(String)
    case wrongKey
    case unsupported(String)
}
