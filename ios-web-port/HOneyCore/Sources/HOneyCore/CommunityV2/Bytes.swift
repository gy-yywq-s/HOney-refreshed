// Byte helpers shared by the Anonymous Control v2 code: base64url without
// padding (every byte field on the wire), hex (tags), UTF-8 and random bytes.
// Mirrors packages/shared/src/community-v2/bytes.ts.

import Foundation

public enum Base64URL {
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ text: String) -> Data? {
        var s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}

public extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }

    init?(hexString: String) {
        let chars = Array(hexString.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var out = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = Data.nibble(chars[i]), let lo = Data.nibble(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        self = out
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: return c - 48
        case 97...102: return c - 87
        case 65...70: return c - 55
        default: return nil
        }
    }

    static func utf8(_ s: String) -> Data { Data(s.utf8) }

    static func random(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255, using: &SystemRandomNumberGenerator.shared) }
        return Data(bytes)
    }

    static func concat(_ parts: Data...) -> Data {
        var out = Data()
        for p in parts { out.append(p) }
        return out
    }
}

private extension SystemRandomNumberGenerator {
    nonisolated(unsafe) static var shared = SystemRandomNumberGenerator()
}
