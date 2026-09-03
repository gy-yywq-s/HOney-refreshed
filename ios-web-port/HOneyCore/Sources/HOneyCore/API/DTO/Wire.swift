// Wire DTOs — a field-for-field mirror of packages/shared/src/api/contract.ts
// at the locked Web snapshot (2d1b562). Property names keep the wire
// spelling (snake_case where the backend sends snake_case, via CodingKeys),
// epoch milliseconds stay Int64, ISO strings stay String. Nothing here is
// a presentation model; Features map these into what screens show.
//
// Forward compatibility (spec §4.1): unknown fields are ignored by Codable;
// enums the server may extend decode unknown values into `.unknown` instead
// of failing the whole payload.

import Foundation

// MARK: - Session / account

public struct SessionTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var accessExpiresAt: String
    public var refreshToken: String
    public var refreshExpiresAt: String

    public init(accessToken: String, accessExpiresAt: String, refreshToken: String, refreshExpiresAt: String) {
        self.accessToken = accessToken
        self.accessExpiresAt = accessExpiresAt
        self.refreshToken = refreshToken
        self.refreshExpiresAt = refreshExpiresAt
    }
}

public struct LoginInput: Encodable, Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct ConsentFlag: Codable, Sendable, Equatable {
    public var timetable: Bool
    public init(timetable: Bool) { self.timetable = timetable }
}

public struct LoginResponse: Decodable, Sendable, Equatable {
    public var honeyId: String
    public var displayName: String
    public var created: Bool
    public var isAdmin: Bool
    public var consent: ConsentFlag
    public var session: SessionTokens
}

public struct Me: Codable, Sendable, Equatable {
    public struct Consent: Codable, Sendable, Equatable {
        public var timetable: Bool
        public var grantedAt: String?
        public init(timetable: Bool, grantedAt: String?) {
            self.timetable = timetable
            self.grantedAt = grantedAt
        }
    }

    public struct Connection: Codable, Sendable, Equatable {
        public var connected: Bool
        public var lastSyncedAt: String?
        public var portalTokenValid: Bool
        public init(connected: Bool, lastSyncedAt: String?, portalTokenValid: Bool) {
            self.connected = connected
            self.lastSyncedAt = lastSyncedAt
            self.portalTokenValid = portalTokenValid
        }
    }

    public var honeyId: String
    public var displayName: String
    public var isAdmin: Bool
    public var consent: Consent
    public var connection: Connection

    public init(honeyId: String, displayName: String, isAdmin: Bool, consent: Consent, connection: Connection) {
        self.honeyId = honeyId
        self.displayName = displayName
        self.isAdmin = isAdmin
        self.consent = consent
        self.connection = connection
    }
}

// MARK: - Timetable

/// A canonical lesson (docs/architecture/canonical-school-data.md): Subject ·
/// Course ("AL ECON U4", public entity) · Class section (operational, never
/// public) · Lesson · Topic. `courseName` is nil when the source label was
/// unresolved; titles then fall back to the Subject.
public struct Lesson: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var subjectId: String?
    public var subjectName: String
    /// Canonical course id / display name ("AL ECON U4"); nil when the label is unresolved.
    public var courseId: String?
    public var courseName: String?
    /// Operational section ("2026 Autumn · Prep Class"); context only, not an entity.
    public var classSectionId: String?
    public var classSectionName: String?
    public var topicName: String?
    public var teacherId: String?
    public var teacherName: String?
    public var roomId: String?
    public var roomName: String?
    /// Epoch milliseconds (the backend sends numbers, not ISO strings).
    public var startsAt: Int64
    public var endsAt: Int64

    public init(
        id: String, subjectId: String? = nil, subjectName: String,
        courseId: String? = nil, courseName: String? = nil,
        classSectionId: String? = nil, classSectionName: String? = nil,
        topicName: String? = nil,
        teacherId: String? = nil, teacherName: String? = nil,
        roomId: String? = nil, roomName: String? = nil,
        startsAt: Int64, endsAt: Int64
    ) {
        self.id = id
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.courseId = courseId
        self.courseName = courseName
        self.classSectionId = classSectionId
        self.classSectionName = classSectionName
        self.topicName = topicName
        self.teacherId = teacherId
        self.teacherName = teacherName
        self.roomId = roomId
        self.roomName = roomName
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    /// The canonical Course students mean, else the Subject.
    public var title: String { courseName ?? subjectName }
}

public enum TemporalState: String, Codable, Sendable, Equatable {
    case now
    case upcoming
}

/// `NextLesson extends Lesson` on the wire: the lesson fields plus two
/// temporal ones in the same object.
public struct NextLesson: Codable, Sendable, Equatable {
    public var lesson: Lesson
    public var temporalState: TemporalState
    public var minutesUntilStart: Int

    public init(lesson: Lesson, temporalState: TemporalState, minutesUntilStart: Int) {
        self.lesson = lesson
        self.temporalState = temporalState
        self.minutesUntilStart = minutesUntilStart
    }

    private enum CodingKeys: String, CodingKey {
        case temporalState, minutesUntilStart
    }

    public init(from decoder: Decoder) throws {
        lesson = try Lesson(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        temporalState = try c.decode(TemporalState.self, forKey: .temporalState)
        minutesUntilStart = try c.decode(Int.self, forKey: .minutesUntilStart)
    }

    public func encode(to encoder: Encoder) throws {
        try lesson.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(temporalState, forKey: .temporalState)
        try c.encode(minutesUntilStart, forKey: .minutesUntilStart)
    }
}

public struct TimetableResponse: Codable, Sendable, Equatable {
    public var date: String
    public var lessons: [Lesson]
    public var lastSyncedAt: String?
    public init(date: String, lessons: [Lesson], lastSyncedAt: String?) {
        self.date = date
        self.lessons = lessons
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct TimetableRangeResponse: Codable, Sendable, Equatable {
    public struct Day: Codable, Sendable, Equatable {
        public var date: String
        public var lessons: [Lesson]
        public init(date: String, lessons: [Lesson]) {
            self.date = date
            self.lessons = lessons
        }
    }

    public var from: String
    public var to: String
    public var days: [Day]
    public var lastSyncedAt: String?
    public init(from: String, to: String, days: [Day], lastSyncedAt: String?) {
        self.from = from
        self.to = to
        self.days = days
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct NextLessonResponse: Codable, Sendable, Equatable {
    public var nextLesson: NextLesson?
    public var lastSyncedAt: String?
    public init(nextLesson: NextLesson?, lastSyncedAt: String?) {
        self.nextLesson = nextLesson
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct HistoryParams: Sendable, Equatable {
    public enum Order: String, Sendable { case asc, desc }
    public var q: String?
    public var teacherId: String?
    public var courseId: String?
    public var before: String?
    public var limit: Int?
    public var order: Order?
    public init(q: String? = nil, teacherId: String? = nil, courseId: String? = nil, before: String? = nil, limit: Int? = nil, order: Order? = nil) {
        self.q = q
        self.teacherId = teacherId
        self.courseId = courseId
        self.before = before
        self.limit = limit
        self.order = order
    }
}

public struct HistoryResponse: Codable, Sendable, Equatable {
    public var lessons: [Lesson]
    public init(lessons: [Lesson]) { self.lessons = lessons }
}

public struct DirectoryEntry: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DirectoryResponse: Codable, Sendable, Equatable {
    public var teachers: [DirectoryEntry]
    public var courses: [DirectoryEntry]
    public var rooms: [DirectoryEntry]
    public init(teachers: [DirectoryEntry], courses: [DirectoryEntry], rooms: [DirectoryEntry]) {
        self.teachers = teachers
        self.courses = courses
        self.rooms = rooms
    }
}

public enum SyncStatus: Sendable, Equatable, Codable {
    case ok
    case portalReconnectRequired
    case noConsent
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SyncStatus(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    public init(rawValue: String) {
        switch rawValue {
        case "ok": self = .ok
        case "portal_reconnect_required": self = .portalReconnectRequired
        case "no_consent": self = .noConsent
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .ok: return "ok"
        case .portalReconnectRequired: return "portal_reconnect_required"
        case .noConsent: return "no_consent"
        case .unknown(let raw): return raw
        }
    }
}

public struct SyncResponse: Codable, Sendable, Equatable {
    public var status: SyncStatus
    public var lessons: Int
    public var teachers: Int
    public var courses: Int
    public var rooms: Int
    /// Source labels the canonical resolver could not place (Dash only; never in browse lists).
    public var unresolved: Int?
    public init(status: SyncStatus, lessons: Int, teachers: Int, courses: Int, rooms: Int, unresolved: Int? = nil) {
        self.status = status
        self.lessons = lessons
        self.teachers = teachers
        self.courses = courses
        self.rooms = rooms
        self.unresolved = unresolved
    }
}

/// GET /api/portal/entry — a discriminated union on `status`.
public enum PortalEntryResponse: Sendable, Equatable, Codable {
    case ok(url: String, expiresAt: Int64)
    case reconnectRequired

    private enum CodingKeys: String, CodingKey { case status, url, expiresAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let status = try c.decode(String.self, forKey: .status)
        switch status {
        case "ok":
            self = .ok(url: try c.decode(String.self, forKey: .url), expiresAt: try c.decode(Int64.self, forKey: .expiresAt))
        case "portal_reconnect_required":
            self = .reconnectRequired
        default:
            throw DecodingError.dataCorruptedError(forKey: .status, in: c, debugDescription: "unknown portal entry status \(status)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ok(let url, let expiresAt):
            try c.encode("ok", forKey: .status)
            try c.encode(url, forKey: .url)
            try c.encode(expiresAt, forKey: .expiresAt)
        case .reconnectRequired:
            try c.encode("portal_reconnect_required", forKey: .status)
        }
    }
}

