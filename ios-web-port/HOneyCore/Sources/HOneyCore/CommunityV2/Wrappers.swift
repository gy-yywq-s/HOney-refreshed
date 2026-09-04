// Wrapping the vault root R (spec §35.2, §36, §37): each recovery method
// derives its own AES-256-GCM key and wraps the same 32-byte R.
//
//   device key        a random key kept in the Keychain (iPhone) — never leaves
//   passkey PRF       K = HKDF(P, salt = SHA-256(vaultId), info = vault-prf-wrap)
//   recovery phrase   K = HKDF(S_phrase, salt = SHA-256(vaultId), info = vault-phrase-wrap)
//
// Mirrors packages/shared/src/community-v2/wrappers.ts.

import Crypto
import Foundation

public struct WrappedR: Sendable, Equatable {
    public var iv: String
    public var wrappedR: String
}

public enum WrapperKind: String, Sendable {
    case passkeyPrf = "passkey_prf"
    case recoveryPhrase = "recovery_phrase"
    case device
}

public enum VaultWrappers {
    public static func aad(vaultId: String, kind: WrapperKind) -> Data {
        Data.utf8("honey/v2/wrapper\0\(kind.rawValue)\0\(vaultId)")
    }

    public static func wrap(key: Data, r: Data, aad: Data) throws -> WrappedR {
        let sealed = try ControlVault.aesSeal(key: key, plaintext: r, aad: aad)
        return WrappedR(iv: Base64URL.encode(sealed.iv), wrappedR: Base64URL.encode(sealed.ciphertext))
    }

    public static func unwrap(key: Data, wrapped: WrappedR, aad: Data) throws -> Data {
        guard let iv = Base64URL.decode(wrapped.iv), let ct = Base64URL.decode(wrapped.wrappedR) else { throw V2Error.invalidInput("bad wrapper encoding") }
        return try ControlVault.aesOpen(key: key, iv: iv, ciphertext: ct, aad: aad)
    }

    // MARK: passkey PRF

    /// prfInput = SHA-256("honey/v2/vault-prf-input\0" ‖ vaultId).
    public static func prfInput(vaultId: String) -> Data {
        Data(SHA256.hash(data: Data.concat(Data.utf8(V2Labels.vaultPrfInputPrefix), Data.utf8(vaultId))))
    }

    public static func prfWrapKey(prfOutput: Data, vaultId: String) throws -> Data {
        guard prfOutput.count == 32 else { throw V2Error.invalidInput("PRF output must be 32 bytes") }
        return V2Derivation.hkdf32(ikm: prfOutput, salt: Data(SHA256.hash(data: Data.utf8(vaultId))), info: Data.utf8(V2Labels.vaultPrfWrap))
    }

    public static func wrapWithPrf(prfOutput: Data, vaultId: String, credentialId: String, r: Data, now: Int64, label: String? = nil) throws -> PasskeyPrfWrapper {
        let w = try wrap(key: try prfWrapKey(prfOutput: prfOutput, vaultId: vaultId), r: r, aad: aad(vaultId: vaultId, kind: .passkeyPrf))
        return PasskeyPrfWrapper(credentialId: credentialId, prfInput: Base64URL.encode(prfInput(vaultId: vaultId)), iv: w.iv, wrappedR: w.wrappedR, createdAt: now, label: label)
    }

    public static func unwrapWithPrf(prfOutput: Data, vaultId: String, wrapper: PasskeyPrfWrapper) throws -> Data {
        try unwrap(key: try prfWrapKey(prfOutput: prfOutput, vaultId: vaultId), wrapped: WrappedR(iv: wrapper.iv, wrappedR: wrapper.wrappedR), aad: aad(vaultId: vaultId, kind: .passkeyPrf))
    }

    // MARK: recovery phrase

    public static func phraseWrapKey(recoverySecret: Data, vaultId: String) throws -> Data {
        guard recoverySecret.count == 16 else { throw V2Error.invalidInput("recovery secret must be 16 bytes") }
        return V2Derivation.hkdf32(ikm: recoverySecret, salt: Data(SHA256.hash(data: Data.utf8(vaultId))), info: Data.utf8(V2Labels.vaultPhraseWrap))
    }

    public static func wrapWithPhrase(recoverySecret: Data, vaultId: String, r: Data, now: Int64) throws -> RecoveryPhraseWrapper {
        let w = try wrap(key: try phraseWrapKey(recoverySecret: recoverySecret, vaultId: vaultId), r: r, aad: aad(vaultId: vaultId, kind: .recoveryPhrase))
        return RecoveryPhraseWrapper(iv: w.iv, wrappedR: w.wrappedR, createdAt: now)
    }

    public static func unwrapWithPhrase(recoverySecret: Data, vaultId: String, wrapper: RecoveryPhraseWrapper) throws -> Data {
        try unwrap(key: try phraseWrapKey(recoverySecret: recoverySecret, vaultId: vaultId), wrapped: WrappedR(iv: wrapper.iv, wrappedR: wrapper.wrappedR), aad: aad(vaultId: vaultId, kind: .recoveryPhrase))
    }

    // MARK: device key (Keychain-held random key)

    public static func deviceWrapKey(deviceSecret: Data, vaultId: String) throws -> Data {
        guard deviceSecret.count == 32 else { throw V2Error.invalidInput("device secret must be 32 bytes") }
        return V2Derivation.hkdf32(ikm: deviceSecret, salt: Data(SHA256.hash(data: Data.utf8(vaultId))), info: Data.utf8(V2Labels.vaultDeviceWrap))
    }

    public static func wrapWithDevice(deviceSecret: Data, vaultId: String, r: Data) throws -> WrappedR {
        try wrap(key: try deviceWrapKey(deviceSecret: deviceSecret, vaultId: vaultId), r: r, aad: aad(vaultId: vaultId, kind: .device))
    }

    public static func unwrapWithDevice(deviceSecret: Data, vaultId: String, wrapped: WrappedR) throws -> Data {
        try unwrap(key: try deviceWrapKey(deviceSecret: deviceSecret, vaultId: vaultId), wrapped: wrapped, aad: aad(vaultId: vaultId, kind: .device))
    }
}
