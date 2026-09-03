// Device pairing (spec §38): the new device makes an ephemeral X25519 key
// pair; the signed-in device HPKE-seals R to it (RFC 9180 base mode,
// DHKEM(X25519) · HKDF-SHA256 · AES-256-GCM); the relay holds only the
// ciphertext for minutes. Mirrors packages/shared/src/community-v2/pairing.ts.

import Crypto
import Foundation

public struct PairingKeyPair: Sendable, Equatable {
    /// base64url raw 32 bytes
    public var publicKey: String
    public var privateKey: String
}

public enum Pairing {
    static let suite = HPKE.Ciphersuite(kem: .Curve25519_HKDF_SHA256, kdf: .HKDF_SHA256, aead: .AES_GCM_256)

    public static func newKeyPair() -> PairingKeyPair {
        let key = Curve25519.KeyAgreement.PrivateKey()
        return PairingKeyPair(publicKey: Base64URL.encode(key.publicKey.rawRepresentation), privateKey: Base64URL.encode(key.rawRepresentation))
    }

    static func aad(pairingId: String) -> Data { Data.utf8("\(V2Labels.pairingInfo)\0\(pairingId)") }

    public static func seal(recipientPublicKey: String, pairingId: String, r: Data) throws -> (enc: String, ciphertext: String) {
        guard let pk = Base64URL.decode(recipientPublicKey) else { throw V2Error.invalidInput("bad public key") }
        let recipient = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: pk)
        var sender = try HPKE.Sender(recipientKey: recipient, ciphersuite: suite, info: Data.utf8(V2Labels.pairingInfo))
        let ct = try sender.seal(r, authenticating: aad(pairingId: pairingId))
        return (Base64URL.encode(sender.encapsulatedKey), Base64URL.encode(ct))
    }

    public static func open(privateKey: String, pairingId: String, enc: String, ciphertext: String) throws -> Data {
        guard let sk = Base64URL.decode(privateKey), let encData = Base64URL.decode(enc), let ct = Base64URL.decode(ciphertext) else {
            throw V2Error.invalidInput("bad pairing encoding")
        }
        let key = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: sk)
        var recipient = try HPKE.Recipient(privateKey: key, ciphersuite: suite, info: Data.utf8(V2Labels.pairingInfo), encapsulatedKey: encData)
        return try recipient.open(ct, authenticating: aad(pairingId: pairingId))
    }
}
