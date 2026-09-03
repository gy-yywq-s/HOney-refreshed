// Blind eligibility tokens (spec §31): the client side of
// RSAPBSSA-SHA384-PSS-Randomized (the CFRG partially-blind RSA scheme as
// @cloudflare/blindrsa-ts implements it) — prepare, blind, finalize — plus
// the verifier, all over plain modular arithmetic (BigInt). swift-crypto's
// RSA cannot host the DERIVED public exponent e′ (BoringSSL refuses it), so
// nothing here touches an RSA key object: only n, e′ and the PSS encoding.
// The scope and canonical context are PUBLIC METADATA (`info`, the JCS bytes
// of EligibilityInfo) bound into the signature.
//
// Mirrors packages/shared/src/community-v2/blind-token.ts and the library's
// partially_blindrsa.js; the shared test issuer key and a Web-produced token
// pin the arithmetic.

import BigInt
import Crypto
import Foundation

public struct IssuerRSAPublicKey: Sendable, Equatable {
    public let keyId: String
    public let n: BigUInt
    public let e: BigUInt
    public var modulusBits: Int { n.bitWidth }
    public var modulusBytes: Int { (modulusBits + 7) / 8 }

    public init(keyId: String, n: BigUInt, e: BigUInt) {
        self.keyId = keyId
        self.n = n
        self.e = e
    }

    public init(descriptor: IssuerDescriptor) throws {
        guard let n = Base64URL.decode(descriptor.publicKey.n), let e = Base64URL.decode(descriptor.publicKey.e) else {
            throw V2Error.invalidInput("issuer key is not base64url")
        }
        self.init(keyId: descriptor.keyId, n: BigUInt(n), e: BigUInt(e))
    }
}

/// The prepared, blinded token the client keeps between the two rounds.
public struct BlindedToken: Sendable, Equatable {
    /// The prepared message (random prefix ‖ nonce), kept for finalize.
    public let message: Data
    public let blindedMessage: Data
    public let inverse: Data
}

public enum BlindTokenError: Error, Sendable, Equatable {
    case invalidInput
    case blindingError
    case unexpectedInputSize
    case invalidSignature
}

public enum BlindToken {
    public static let suite = V2Labels.eligibilitySuite
    static let hashLength = 48 // SHA-384
    static let saltLength = 48 // PSS-Randomized: sLen = hLen
    static let preparePrefix = 32 // PrepareType.Randomized

    public static func infoBytes(_ info: EligibilityInfo) throws -> Data {
        try CanonicalJSON.bytes(of: info)
    }

    // MARK: integers ↔ bytes

    static func i2osp(_ x: BigUInt, _ length: Int) throws -> Data {
        let bytes = x.serialize()
        guard bytes.count <= length else { throw BlindTokenError.unexpectedInputSize }
        return Data(repeating: 0, count: length - bytes.count) + bytes
    }

    static func os2ip(_ data: Data) -> BigUInt { BigUInt(data) }

    static func int4(_ n: Int) -> Data { Data([UInt8(n >> 24 & 0xff), UInt8(n >> 16 & 0xff), UInt8(n >> 8 & 0xff), UInt8(n & 0xff)]) }

    /// msg_prime = "msg" ‖ int_to_bytes(len(info), 4) ‖ info ‖ msg
    static func messagePrime(info: Data, message: Data) -> Data {
        Data.concat(Data.utf8("msg"), int4(info.count), info, message)
    }

    // MARK: derived public key (the partially-blind trick)

    /// pk_derived = (n, e′) with e′ from HKDF-SHA384(IKM = "key" ‖ info ‖ 0x00, salt = n, info = "PBRSA").
    public static func derivedExponent(n: BigUInt, info: Data) throws -> BigUInt {
        let modulusLen = (n.bitWidth + 7) / 8
        let lambdaLen = n.bitWidth >> 4
        let hkdfLen = lambdaLen + 16
        let ikm = Data.concat(Data.utf8("key"), info, Data([0x00]))
        let salt = try i2osp(n, modulusLen)
        let expanded = HKDF<SHA384>.deriveKey(inputKeyMaterial: SymmetricKey(data: ikm), salt: salt, info: Data.utf8("PBRSA"), outputByteCount: hkdfLen)
        var bytes = expanded.withUnsafeBytes { Data($0) }
        bytes[0] &= 0x3f
        bytes[lambdaLen - 1] |= 0x01
        return os2ip(bytes.prefix(lambdaLen))
    }

    // MARK: EMSA-PSS (RFC 8017 §9.1) with SHA-384, MGF1-SHA-384

    static func mgf1(_ seed: Data, _ length: Int) -> Data {
        var out = Data()
        var counter: UInt32 = 0
        while out.count < length {
            var block = seed
            block.append(int4(Int(counter)))
            out.append(Data(SHA384.hash(data: block)))
            counter += 1
        }
        return out.prefix(length)
    }

    static func pssEncode(_ message: Data, emBits: Int) throws -> Data {
        let emLen = (emBits + 7) / 8
        let mHash = Data(SHA384.hash(data: message))
        guard emLen >= hashLength + saltLength + 2 else { throw BlindTokenError.invalidInput }
        let salt = Data.random(saltLength)
        let mPrime = Data.concat(Data(repeating: 0, count: 8), mHash, salt)
        let h = Data(SHA384.hash(data: mPrime))
        let ps = Data(repeating: 0, count: emLen - saltLength - hashLength - 2)
        let db = Data.concat(ps, Data([0x01]), salt)
        let dbMask = mgf1(h, emLen - hashLength - 1)
        var masked = Data(zip(db, dbMask).map { $0 ^ $1 })
        masked[0] &= UInt8(0xff >> (8 * emLen - emBits))
        return Data.concat(masked, h, Data([0xbc]))
    }

    static func pssVerify(_ message: Data, em: Data, emBits: Int) -> Bool {
        let emLen = (emBits + 7) / 8
        guard em.count == emLen, emLen >= hashLength + saltLength + 2, em.last == 0xbc else { return false }
        let mHash = Data(SHA384.hash(data: message))
        let maskedDB = em.prefix(emLen - hashLength - 1)
        let h = em.dropFirst(emLen - hashLength - 1).prefix(hashLength)
        let topBits = 8 * emLen - emBits
        guard maskedDB.first! >> UInt8(8 - topBits) == 0 || topBits == 0 else { return false }
        let dbMask = mgf1(Data(h), emLen - hashLength - 1)
        var db = Data(zip(maskedDB, dbMask).map { $0 ^ $1 })
        db[0] &= UInt8(0xff >> topBits)
        let psLen = emLen - hashLength - saltLength - 2
        for i in 0..<psLen where db[i] != 0 { return false }
        guard db[psLen] == 0x01 else { return false }
        let salt = db.suffix(saltLength)
        let mPrime = Data.concat(Data(repeating: 0, count: 8), mHash, Data(salt))
        return Data(SHA384.hash(data: mPrime)) == Data(h)
    }

    // MARK: protocol steps

    /// Client, step 0: prepare = random 32-byte prefix ‖ message.
    public static func prepare(_ message: Data) -> Data {
        Data.random(preparePrefix) + message
    }

    static func randomBelow(_ n: BigUInt, byteLength: Int) -> BigUInt {
        while true {
            let candidate = os2ip(.random(byteLength))
            if candidate >= 1, candidate < n { return candidate }
        }
    }

    /// Client, step 1: blind the prepared message under the issuer key and the expected info.
    public static func blind(publicKey: IssuerRSAPublicKey, message: Data, info: Data) throws -> BlindedToken {
        let n = publicKey.n
        let kLen = publicKey.modulusBytes
        let encoded = try pssEncode(messagePrime(info: info, message: message), emBits: publicKey.modulusBits - 1)
        let m = os2ip(encoded)
        guard m.greatestCommonDivisor(with: n) == 1 else { throw BlindTokenError.invalidInput }
        let r = randomBelow(n, byteLength: kLen)
        guard let rInv = r.inverse(n) else { throw BlindTokenError.blindingError }
        let ePrime = try derivedExponent(n: n, info: info)
        let x = r.power(ePrime, modulus: n)
        let z = (m * x) % n
        return BlindedToken(message: message, blindedMessage: try i2osp(z, kLen), inverse: try i2osp(rInv, kLen))
    }

    /// Client, step 2: sig = blindSig · r⁻¹ mod n. Community verifies offline (spec: the client does not need to).
    public static func finalize(publicKey: IssuerRSAPublicKey, blinded: BlindedToken, blindSignature: Data) throws -> Data {
        let kLen = publicKey.modulusBytes
        guard blindSignature.count == kLen, blinded.inverse.count == kLen else { throw BlindTokenError.unexpectedInputSize }
        let s = (os2ip(blindSignature) * os2ip(blinded.inverse)) % publicKey.n
        return try i2osp(s, kLen)
    }

    /// Verifier: RSASSA-PSS-VERIFY with (n, e′) over msg_prime.
    public static func verify(publicKey: IssuerRSAPublicKey, signature: Data, message: Data, info: Data) -> Bool {
        guard signature.count == publicKey.modulusBytes else { return false }
        let s = os2ip(signature)
        guard s < publicKey.n else { return false }
        guard let ePrime = try? derivedExponent(n: publicKey.n, info: info) else { return false }
        let m = s.power(ePrime, modulus: publicKey.n)
        let emBits = publicKey.modulusBits - 1
        guard let em = try? i2osp(m, (emBits + 7) / 8) else { return false }
        return pssVerify(messagePrime(info: info, message: message), em: em, emBits: emBits)
    }

    /// Issuer (TEST ONLY — the real issuer is HOney Core): s = m^d′ mod n with d′ = e′⁻¹ mod φ(n).
    public static func blindSign(n: BigUInt, p: BigUInt, q: BigUInt, blindedMessage: Data, info: Data) throws -> Data {
        let phi = (p - 1) * (q - 1)
        let ePrime = try derivedExponent(n: n, info: info)
        guard let dPrime = ePrime.inverse(phi) else { throw BlindTokenError.invalidInput }
        let m = os2ip(blindedMessage)
        let s = m.power(dPrime, modulus: n)
        guard s.power(ePrime, modulus: n) == m else { throw BlindTokenError.invalidSignature }
        return try i2osp(s, (n.bitWidth + 7) / 8)
    }

    /// The single-use handle Community reserves and consumes: SHA-256 of the signature.
    public static func tokenHash(signature: Data) -> String {
        Base64URL.encode(Data(SHA256.hash(data: signature)))
    }
}
