// 12-word recovery phrase (spec §37): a random 128-bit secret encoded with
// the fixed 2048-word BIP-39 English list and a 4-bit checksum. The words are
// recovery material, never a password; the secret only wraps R.
// Mirrors packages/shared/src/community-v2/recovery-words.ts (via @scure/bip39).

import Crypto
import Foundation

public enum RecoveryWords {
    public static let count = 12

    public static func newSecret() -> Data { .random(16) }

    /// 128 entropy bits ‖ 4 checksum bits (the first bits of SHA-256) → 12 × 11-bit indices.
    public static func words(from secret: Data) throws -> [String] {
        guard secret.count == 16 else { throw V2Error.invalidInput("recovery secret must be 16 bytes") }
        let checksum = Data(SHA256.hash(data: secret))[0] >> 4
        var bits: [Bool] = []
        bits.reserveCapacity(132)
        for byte in secret { for i in (0..<8).reversed() { bits.append((byte >> UInt8(i)) & 1 == 1) } }
        for i in (0..<4).reversed() { bits.append((checksum >> UInt8(i)) & 1 == 1) }
        var out: [String] = []
        for w in 0..<count {
            var index = 0
            for b in 0..<11 { index = index << 1 | (bits[w * 11 + b] ? 1 : 0) }
            out.append(Bip39English.words[index])
        }
        return out
    }

    /// Normalizes whitespace and case; nil when the words or the checksum are wrong.
    public static func secret(from input: String) -> Data? {
        let words = input.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return secret(from: words)
    }

    public static func secret(from words: [String]) -> Data? {
        let normalized = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        guard normalized.count == count else { return nil }
        var bits: [Bool] = []
        for word in normalized {
            guard let index = Bip39English.index[word] else { return nil }
            for b in (0..<11).reversed() { bits.append((index >> b) & 1 == 1) }
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<128 where bits[i] { bytes[i / 8] |= 1 << UInt8(7 - i % 8) }
        let secret = Data(bytes)
        let expected = Data(SHA256.hash(data: secret))[0] >> 4
        var checksum: UInt8 = 0
        for i in 0..<4 { checksum = checksum << 1 | (bits[128 + i] ? 1 : 0) }
        return checksum == expected ? secret : nil
    }

    public static func isWord(_ word: String) -> Bool {
        Bip39English.index[word.lowercased().trimmingCharacters(in: .whitespaces)] != nil
    }

    public static var wordlist: [String] { Bip39English.words }
}

extension Bip39English {
    static let index: [String: Int] = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
}
