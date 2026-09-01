//
//  Coding.swift
//  HOney — shared JSON coders (Band 2/4, no SwiftUI).
//
//  The HOney wire contract is camelCase except the Experiences objects, whose
//  snake_case fields are mapped with explicit CodingKeys on the models (see
//  HOneyModels.swift) — no key-conversion strategy, so mixed-shape objects like
//  PublicExperience (snake_case fields + camelCase `publishedDay`) stay exact.
//

import Foundation

enum HOneyCoding {
    /// Decoder for the HOney backend. Tolerant date parsing: ISO-8601 with or
    /// without fractional seconds, or a Unix epoch number — epoch values large
    /// enough to be milliseconds (the contract sends epoch ms for lesson times)
    /// are scaled accordingly.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                if let date = ISO8601.date(from: string) { return date }
            }
            if let epoch = try? container.decode(Double.self) {
                // > 1e12 can only be milliseconds (seconds would be year 33658+).
                return Date(timeIntervalSince1970: epoch > 1e12 ? epoch / 1000 : epoch)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised date value"
            )
        }
        return decoder
    }()

    /// Encoder for HOney request bodies. Model properties for request bodies use
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
