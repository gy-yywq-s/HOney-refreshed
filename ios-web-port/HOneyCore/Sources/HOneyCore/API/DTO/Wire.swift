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

public struct Lesson: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var subjectName: String
    public var topicName: String?
    public var teacherId: String?
    public var teacherName: String?
    public var courseId: String?
    public var courseName: String?
    public var roomId: String?
    public var roomName: String?
    /// Epoch milliseconds (the backend sends numbers, not ISO strings).
    public var startsAt: Int64
    public var endsAt: Int64

    public init(
        id: String, subjectName: String, topicName: String? = nil,
        teacherId: String? = nil, teacherName: String? = nil,
        courseId: String? = nil, courseName: String? = nil,
        roomId: String? = nil, roomName: String? = nil,
        startsAt: Int64, endsAt: Int64
    ) {
        self.id = id
        self.subjectName = subjectName
        self.topicName = topicName
        self.teacherId = teacherId
        self.teacherName = teacherName
        self.courseId = courseId
        self.courseName = courseName
        self.roomId = roomId
        self.roomName = roomName
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
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
    public init(status: SyncStatus, lessons: Int, teachers: Int, courses: Int, rooms: Int) {
        self.status = status
        self.lessons = lessons
        self.teachers = teachers
        self.courses = courses
        self.rooms = rooms
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

// MARK: - Experiences

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

public struct ReactionCounts: Codable, Sendable, Equatable, Hashable {
    public var likes: Int
    public var dislikes: Int
    public init(likes: Int, dislikes: Int) {
        self.likes = likes
        self.dislikes = dislikes
    }
}

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

public struct EntitySummary: Codable, Sendable, Equatable, Hashable {
    public var type: EntitySummaryType
    public var id: String
    public var name: String?
    public init(type: EntitySummaryType, id: String, name: String?) {
        self.type = type
        self.id = id
        self.name = name
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

/// A published post as the PUBLIC feed exposes it: no author, coarse day only.
public struct PublicExperience: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var entityKey: String
    public var ctxTeacherId: String?
    public var ctxCourseId: String?
    public var ctxRoomId: String?
    public var body: String?
    public var rating: Int?
    public var provenance: ExperienceProvenance
    public var publishedDay: Int?
    /// nil means counts are hidden (below the small-cohort threshold).
    public var reactions: ReactionCounts?
    /// The viewer's own reaction: 1, -1 or 0; absent on older payloads.
    public var myReaction: Int?
    public var primary: EntitySummary?
    public var contexts: [EntitySummary]?

    private enum CodingKeys: String, CodingKey {
        case id
        case entityKey = "entity_key"
        case ctxTeacherId = "ctx_teacher_id"
        case ctxCourseId = "ctx_course_id"
        case ctxRoomId = "ctx_room_id"
        case body, rating, provenance, publishedDay, reactions, myReaction, primary, contexts
    }

    public init(
        id: String, entityKey: String,
        ctxTeacherId: String? = nil, ctxCourseId: String? = nil, ctxRoomId: String? = nil,
        body: String?, rating: Int? = nil, provenance: ExperienceProvenance,
        publishedDay: Int?, reactions: ReactionCounts?, myReaction: Int? = nil,
        primary: EntitySummary? = nil, contexts: [EntitySummary]? = nil
    ) {
        self.id = id
        self.entityKey = entityKey
        self.ctxTeacherId = ctxTeacherId
        self.ctxCourseId = ctxCourseId
        self.ctxRoomId = ctxRoomId
        self.body = body
        self.rating = rating
        self.provenance = provenance
        self.publishedDay = publishedDay
        self.reactions = reactions
        self.myReaction = myReaction
        self.primary = primary
        self.contexts = contexts
    }
}

public struct ExperiencesFeedResponse: Codable, Sendable, Equatable {
    public var experiences: [PublicExperience]
    public init(experiences: [PublicExperience]) { self.experiences = experiences }
}

public enum FeedScope: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case myClasses = "my_classes"
    case school
}

public struct FeedParams: Sendable, Equatable, Hashable {
    public var scope: FeedScope
    /// Opaque, sealed server cursor. Never decoded client-side.
    public var cursor: String?
    public var limit: Int?
    public var entityKey: String?
    public var teacherId: String?
    public var courseId: String?
    public var roomId: String?

    public init(scope: FeedScope, cursor: String? = nil, limit: Int? = nil, entityKey: String? = nil, teacherId: String? = nil, courseId: String? = nil, roomId: String? = nil) {
        self.scope = scope
        self.cursor = cursor
        self.limit = limit
        self.entityKey = entityKey
        self.teacherId = teacherId
        self.courseId = courseId
        self.roomId = roomId
    }
}

public struct SearchResponse: Codable, Sendable, Equatable {
    public var q: String
    public var entities: [EntityRef]
    public var experiences: [PublicExperience]
    public init(q: String, entities: [EntityRef], experiences: [PublicExperience]) {
        self.q = q
        self.entities = entities
        self.experiences = experiences
    }
}

/// Descriptive counts for an entity page — never a score.
public struct EntityStats: Codable, Sendable, Equatable {
    public var experiences: Int
    public var courses: Int
    public var teachers: Int
    public init(experiences: Int, courses: Int, teachers: Int) {
        self.experiences = experiences
        self.courses = courses
        self.teachers = teachers
    }
}

public struct FeedPage: Codable, Sendable, Equatable {
    public var items: [PublicExperience]
    /// nil = end of stream. Passed back verbatim to continue.
    public var nextCursor: String?
    public var headCursor: String?
    public init(items: [PublicExperience], nextCursor: String?, headCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
        self.headCursor = headCursor
    }
}

public struct FeedUpdatesResponse: Codable, Sendable, Equatable {
    public var newItemsAvailable: Bool
    public init(newItemsAvailable: Bool) { self.newItemsAvailable = newItemsAvailable }
}

// MARK: Publication flow

/// Exactly one of lessonId / entityKey.
public struct ExperienceEligibilityInput: Encodable, Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var entityKey: String?
    public init(lessonId: String? = nil, entityKey: String? = nil) {
        self.lessonId = lessonId
        self.entityKey = entityKey
    }
}

public struct ExperienceEligibilityResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var eligibilityToken: String
    public var expiresAt: Int64
    public init(ok: Bool, eligibilityToken: String, expiresAt: Int64) {
        self.ok = ok
        self.eligibilityToken = eligibilityToken
        self.expiresAt = expiresAt
    }
}

public struct CheckExperienceInput: Encodable, Sendable, Equatable {
    public var lessonId: String?
    public var entityKey: String?
    public var body: String
    public var rating: Int?
    public var cooldownTicket: String?
    public init(lessonId: String? = nil, entityKey: String? = nil, body: String, rating: Int? = nil, cooldownTicket: String? = nil) {
        self.lessonId = lessonId
        self.entityKey = entityKey
        self.body = body
        self.rating = rating
        self.cooldownTicket = cooldownTicket
    }
}

public enum CheckLane: Sendable, Equatable, Hashable, Codable {
    case publish, nudge, cooldown, editRequired, blockedSerious, outOfScope, failedClosed
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "publish": self = .publish
        case "nudge": self = .nudge
        case "cooldown": self = .cooldown
        case "edit_required": self = .editRequired
        case "blocked_serious": self = .blockedSerious
        case "out_of_scope": self = .outOfScope
        case "failed_closed": self = .failedClosed
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .publish: return "publish"
        case .nudge: return "nudge"
        case .cooldown: return "cooldown"
        case .editRequired: return "edit_required"
        case .blockedSerious: return "blocked_serious"
        case .outOfScope: return "out_of_scope"
        case .failedClosed: return "failed_closed"
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

public struct CheckExperienceResponse: Codable, Sendable, Equatable {
    public struct Cooldown: Codable, Sendable, Equatable {
        public var ticket: String
        public var retryAt: Int64
        public init(ticket: String, retryAt: Int64) {
            self.ticket = ticket
            self.retryAt = retryAt
        }
    }

    public var lane: CheckLane
    public var reasons: [String]
    public var policyVersion: Int
    /// Present for lanes `publish` and `nudge`.
    public var pass: String?
    /// Present for lane `cooldown`.
    public var cooldown: Cooldown?

    public init(lane: CheckLane, reasons: [String], policyVersion: Int, pass: String? = nil, cooldown: Cooldown? = nil) {
        self.lane = lane
        self.reasons = reasons
        self.policyVersion = policyVersion
        self.pass = pass
        self.cooldown = cooldown
    }
}

public struct PublishExperienceInput: Encodable, Sendable, Equatable {
    public var eligibilityToken: String
    public var pass: String
    public var body: String
    public var rating: Int?
    public init(eligibilityToken: String, pass: String, body: String, rating: Int? = nil) {
        self.eligibilityToken = eligibilityToken
        self.pass = pass
        self.body = body
        self.rating = rating
    }
}

public struct PublishExperienceResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var experienceId: String
    /// Client-held; the server keeps only a hash. Shown once — store it.
    public var ownershipKey: String
    public init(ok: Bool, experienceId: String, ownershipKey: String) {
        self.ok = ok
        self.experienceId = experienceId
        self.ownershipKey = ownershipKey
    }
}

public enum MyExperienceStatus: Sendable, Equatable, Hashable, Codable {
    case published, blocked, revoked
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "published": self = .published
        case "blocked": self = .blocked
        case "revoked": self = .revoked
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .published: return "published"
        case .blocked: return "blocked"
        case .revoked: return "revoked"
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

public struct MyExperience: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var entityKey: String
    public var lessonId: String?
    public var ctxTeacherId: String?
    public var ctxCourseId: String?
    public var ctxRoomId: String?
    public var body: String?
    public var rating: Int?
    public var provenance: ExperienceProvenance
    public var status: MyExperienceStatus
    public var statusDetail: String?
    public var policyVersion: Int
    public var createdAt: Int64
    public var publishedAt: Int64?

    private enum CodingKeys: String, CodingKey {
        case id
        case entityKey = "entity_key"
        case lessonId = "lesson_id"
        case ctxTeacherId = "ctx_teacher_id"
        case ctxCourseId = "ctx_course_id"
        case ctxRoomId = "ctx_room_id"
        case body, rating, provenance, status
        case statusDetail = "status_detail"
        case policyVersion = "policy_version"
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }

    public init(
        id: String, entityKey: String, lessonId: String? = nil,
        ctxTeacherId: String? = nil, ctxCourseId: String? = nil, ctxRoomId: String? = nil,
        body: String?, rating: Int? = nil, provenance: ExperienceProvenance,
        status: MyExperienceStatus, statusDetail: String? = nil, policyVersion: Int,
        createdAt: Int64, publishedAt: Int64?
    ) {
        self.id = id
        self.entityKey = entityKey
        self.lessonId = lessonId
        self.ctxTeacherId = ctxTeacherId
        self.ctxCourseId = ctxCourseId
        self.ctxRoomId = ctxRoomId
        self.body = body
        self.rating = rating
        self.provenance = provenance
        self.status = status
        self.statusDetail = statusDetail
        self.policyVersion = policyVersion
        self.createdAt = createdAt
        self.publishedAt = publishedAt
    }
}

public struct MyExperiencesResponse: Codable, Sendable, Equatable {
    public var experiences: [MyExperience]
    public init(experiences: [MyExperience]) { self.experiences = experiences }
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

/// POST /api/experiences/:id/react → the authoritative state to render.
public struct ReactResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var value: Int
    public var reactions: ReactionCounts?
    public init(ok: Bool, value: Int, reactions: ReactionCounts?) {
        self.ok = ok
        self.value = value
        self.reactions = reactions
    }
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
