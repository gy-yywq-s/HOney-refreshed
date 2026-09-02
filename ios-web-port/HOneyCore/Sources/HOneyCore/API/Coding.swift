// One JSON coder configuration for the whole wire layer. The backend emits
// plain JSON (numbers for epoch ms, ISO strings for dates), so no date
// strategy is needed; the encoder never pretty-prints (request bodies) and
// never sorts keys (the server does not care, and stable output is only a
// test convenience handled there).

import Foundation

public enum WireCoding {
    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encoder() -> JSONEncoder {
        JSONEncoder()
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder().decode(type, from: data)
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder().encode(value)
    }
}

/// ISO-8601 strings as the backend writes them (`toISOString()`, with
/// fractional seconds) — parsed leniently, since the fraction is optional.
public enum ISODate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return withFraction.date(from: string) ?? plain.date(from: string)
    }

    public static func string(_ date: Date) -> String {
        withFraction.string(from: date)
    }
}

public extension Date {
    /// Epoch milliseconds, the unit the backend uses for lesson times.
    var epochMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(epochMillis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }
}
