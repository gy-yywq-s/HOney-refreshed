//
//  Coding.swift
//  HOney — shared JSON coders (Band 2/4, no SwiftUI).
//
//  A single decoder handles both the camelCase auth/timetable payloads and the
//  snake_case Experiences payloads: `.convertFromSnakeCase` leaves camelCase keys
//  (which contain no underscores) untouched while normalising snake_case keys.
//

import Foundation

enum HoneyCoding {
    /// Decoder for the Honey backend. Tolerant date parsing (ISO-8601 with or
    /// without fractional seconds, or a Unix epoch number).
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                if let date = ISO8601.date(from: string) { return date }
            }
            if let epoch = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: epoch)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised date value"
            )
        }
        return decoder
    }()

    /// Encoder for Honey request bodies. Model properties for request bodies use
    /// explicit CodingKeys where the wire format is snake_case, so no key
    /// conversion is applied here.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()
}

/// Decoder for the direct-to-school portal (all snake_case wire types).
enum PortalCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static let encoder = JSONEncoder()
}

/// Tolerant ISO-8601 parsing helper.
enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }
}
