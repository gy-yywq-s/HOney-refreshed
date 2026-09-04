// RFC 8785 JSON Canonicalization Scheme (JCS): the bytes every v2 signature
// is computed over, on Web and iPhone alike. Members sorted by UTF-16 code
// units, no whitespace, strings escaped as ES JSON.stringify does, numbers
// as ES Number::toString. Mirrors packages/shared/src/community-v2/canonical-json.ts;
// the shared vectors pin the output.

import Foundation

public indirect enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public var canonical: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return JSONValue.number(d)
        case .string(let s): return JSONValue.quote(s)
        case .array(let items): return "[" + items.map(\.canonical).joined(separator: ",") + "]"
        case .object(let members):
            let keys = members.keys.sorted { Array($0.utf16).lexicographicallyPrecedes(Array($1.utf16)) }
            return "{" + keys.map { JSONValue.quote($0) + ":" + members[$0]!.canonical }.joined(separator: ",") + "}"
        }
    }

    public var canonicalData: Data { Data(canonical.utf8) }

    /// ES Number::toString for the values the protocol carries (integers and
    /// plain decimals); exponents are normalized to the JS spelling.
    static func number(_ d: Double) -> String {
        precondition(d.isFinite, "non-finite number")
        if d == d.rounded(), abs(d) < 1e21 { return String(Int64(d)) }
        var s = String(d)
        if let e = s.firstIndex(of: "e") {
            var exp = String(s[s.index(after: e)...])
            var sign = ""
            if exp.hasPrefix("+") { exp.removeFirst() } else if exp.hasPrefix("-") { sign = "-"; exp.removeFirst() }
            while exp.hasPrefix("0"), exp.count > 1 { exp.removeFirst() }
            s = String(s[..<e]) + "e" + sign + exp
        }
        return s
    }

    static func quote(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }

    // MARK: Building from Codable / Foundation values

    /// The JSON tree of an Encodable value (nil members are absent, as on the Web).
    public init<T: Encodable>(encoding value: T) throws {
        let data = try WireCoding.encode(value)
        self = try JSONValue(jsonData: data)
    }

    public init(jsonData: Data) throws {
        let any = try JSONSerialization.jsonObject(with: jsonData, options: [.fragmentsAllowed])
        self = try JSONValue(any: any)
    }

    public init(any: Any) throws {
        if any is NSNull { self = .null; return }
        #if canImport(Darwin)
        if let n = any as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { self = .bool(n.boolValue); return }
            if let i = Int64(exactly: n) { self = .int(i); return }
            self = .double(n.doubleValue)
            return
        }
        #else
        if let b = any as? Bool { self = .bool(b); return }
        if let i = any as? Int { self = .int(Int64(i)); return }
        if let i = any as? Int64 { self = .int(i); return }
        if let u = any as? UInt64, let i = Int64(exactly: u) { self = .int(i); return }
        if let d = any as? Double {
            if d == d.rounded(), abs(d) < 9.2e18 { self = .int(Int64(d)) } else { self = .double(d) }
            return
        }
        if let n = any as? NSNumber {
            if let i = Int64(exactly: n) { self = .int(i); return }
            self = .double(n.doubleValue)
            return
        }
        #endif
        if let s = any as? String { self = .string(s); return }
        if let a = any as? [Any] { self = .array(try a.map { try JSONValue(any: $0) }); return }
        if let o = any as? [String: Any] {
            var members: [String: JSONValue] = [:]
            for (k, v) in o { members[k] = try JSONValue(any: v) }
            self = .object(members)
            return
        }
        throw CanonicalJSONError.unsupported(String(describing: type(of: any)))
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let m) = self { return m[key] }
        return nil
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var intValue: Int64? {
        switch self {
        case .int(let i): return i
        case .double(let d) where d == d.rounded(): return Int64(d)
        default: return nil
        }
    }
}

public enum CanonicalJSONError: Error, Sendable, Equatable {
    case unsupported(String)
}

public enum CanonicalJSON {
    public static func canonicalize(_ value: JSONValue) -> String { value.canonical }
    public static func bytes(_ value: JSONValue) -> Data { value.canonicalData }
    public static func bytes<T: Encodable>(of value: T) throws -> Data { try JSONValue(encoding: value).canonicalData }
}
