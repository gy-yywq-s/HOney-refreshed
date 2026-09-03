// Entity DTOs of the ordinary HOney API (packages/shared/src/api/contract.ts):
// the canonical entity directory Core serves. Everything about posts lives
// in CommunityV2/Contract.swift — Community's identity-free wire.

import Foundation

// MARK: - Entities

public enum EntityType: Sendable, Equatable, Hashable, Codable, CaseIterable {
    case teacher, course, room, dish
    case unknown(String)

    public static var allCases: [EntityType] { [.teacher, .course, .room, .dish] }

    public init(rawValue: String) {
        switch rawValue {
        case "teacher": self = .teacher
        case "course": self = .course
        case "room": self = .room
        case "dish": self = .dish
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .teacher: return "teacher"
        case .course: return "course"
        case .room: return "room"
        case .dish: return "dish"
        case .unknown(let raw): return raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

public struct EntityRef: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var entityKey: String
    public var type: EntityType
    public var name: String
    public var source: String

    public var id: String { entityKey }

    private enum CodingKeys: String, CodingKey {
        case entityKey = "entity_key"
        case type, name, source
    }

    public init(entityKey: String, type: EntityType, name: String, source: String) {
        self.entityKey = entityKey
        self.type = type
        self.name = name
        self.source = source
    }
}

public struct EntitiesResponse: Codable, Sendable, Equatable {
    public var entities: [EntityRef]
    public init(entities: [EntityRef]) { self.entities = entities }
}

/// The type of a post's primary or context reference (lessons included).
public enum EntitySummaryType: Sendable, Equatable, Hashable, Codable {
    case teacher, course, lesson, room, dish
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "teacher": self = .teacher
        case "course": self = .course
        case "lesson": self = .lesson
        case "room": self = .room
        case "dish": self = .dish
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .teacher: return "teacher"
        case .course: return "course"
        case .lesson: return "lesson"
        case .room: return "room"
        case .dish: return "dish"
        case .unknown(let raw): return raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

public enum ExperienceProvenance: Sendable, Equatable, Hashable, Codable {
    case verifiedLesson, verifiedRetrospective, verifiedMember
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "verified_lesson": self = .verifiedLesson
        case "verified_retrospective": self = .verifiedRetrospective
        case "verified_member": self = .verifiedMember
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .verifiedLesson: return "verified_lesson"
        case .verifiedRetrospective: return "verified_retrospective"
        case .verifiedMember: return "verified_member"
        case .unknown(let raw): return raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Reports are category-only; free text is never accepted.
public enum ReportCategory: String, Codable, Sendable, Equatable, CaseIterable {
    case seriousAllegation = "serious_allegation"
    case doxxing
    case slur
    case targetsStudent = "targets_student"
    case notExperience = "not_experience"
    case otherRule = "other_rule"
}

public struct OkResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public init(ok: Bool) { self.ok = ok }
}

/// Every error body the backend sends: `{ "error": "<code>" }`.
public struct APIErrorBody: Codable, Sendable, Equatable {
    public var error: String
    public init(error: String) { self.error = error }
}
