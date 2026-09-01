//
//  HOneyModels.swift
//  HOney — Codable models for the HOney backend API (Band 2/4, no SwiftUI).
//

import Foundation

// MARK: - Auth & account

struct HOneySession: Codable, Sendable, Equatable {
    let accessToken: String
    let accessExpiresAt: Date
    let refreshToken: String
    let refreshExpiresAt: Date
}

struct HOneyConsent: Codable, Sendable, Equatable {
    var timetable: Bool
}

struct HOneyConnection: Codable, Sendable, Equatable {
    let connected: Bool
    let lastSyncedAt: Date?
    let portalTokenValid: Bool
}

struct HOneyProfile: Codable, Sendable, Equatable {
    let honeyId: String
    let displayName: String
    let isAdmin: Bool
    var consent: HOneyConsent
    var connection: HOneyConnection?
}

struct LoginResponse: Codable, Sendable {
    let honeyId: String
    let displayName: String
    let created: Bool
    let isAdmin: Bool
    let consent: HOneyConsent
    let session: HOneySession

    var profile: HOneyProfile {
        HOneyProfile(honeyId: honeyId, displayName: displayName, isAdmin: isAdmin, consent: consent, connection: nil)
    }
}

struct MeResponse: Codable, Sendable {
    let honeyId: String
    let displayName: String
    let isAdmin: Bool
    let consent: HOneyConsent
    let connection: HOneyConnection?

    var profile: HOneyProfile {
        HOneyProfile(honeyId: honeyId, displayName: displayName, isAdmin: isAdmin, consent: consent, connection: connection)
    }
}

// MARK: - Timetable / lessons

struct Lesson: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let subjectName: String
    let topicName: String?
    let teacherId: String?
    let teacherName: String?
    let courseId: String?
    let courseName: String?
    let roomId: String?
    let roomName: String?
    let startsAt: Date
    let endsAt: Date
}

struct TimetableResponse: Codable, Sendable {
    let date: String
    let lessons: [Lesson]
    let lastSyncedAt: Date?
}

/// Temporal state for the "next lesson" surface. Decoded leniently — an unknown
/// value falls back to `.upcoming`.
enum LessonTemporalState: String, Codable, Sendable {
    case now
    case upcoming
    case later
    case none

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? "upcoming"
        self = LessonTemporalState(rawValue: raw) ?? .upcoming
    }
}

struct NextLesson: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let subjectName: String
    let topicName: String?
    let teacherName: String?
    let courseName: String?
    let roomName: String?
    let startsAt: Date
    let endsAt: Date
    let temporalState: LessonTemporalState
    let minutesUntilStart: Int?

    static func == (lhs: NextLesson, rhs: NextLesson) -> Bool { lhs.id == rhs.id }
}

struct NextLessonResponse: Codable, Sendable {
    let nextLesson: NextLesson?
    let lastSyncedAt: Date?
}

struct HistoryResponse: Codable, Sendable {
    let lessons: [Lesson]
}

// MARK: - Directory & entities

struct DirectoryEntry: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct DirectoryResponse: Codable, Sendable {
    let teachers: [DirectoryEntry]
    let courses: [DirectoryEntry]
    let rooms: [DirectoryEntry]
}

/// Browsable Experiences entity kinds (contract `EntityType`). V1: lesson is a
/// compose target but NOT a browsable entity, and course ids appear only as
/// lesson CONTEXT for filter-time association.
enum EntityType: String, Codable, Sendable, CaseIterable {
    case teacher
    case room
    case dish
}

/// Registry entry for a browsable Experiences entity (contract `EntityRef`).
struct EntityRef: Codable, Sendable, Identifiable, Hashable {
    let entityKey: String
    let type: EntityType
    let name: String
    let source: EntitySource

    var id: String { entityKey }

    enum EntitySource: String, Codable, Sendable {
        case organic
        case admin
    }

    enum CodingKeys: String, CodingKey {
        case entityKey = "entity_key"
        case type
        case name
        case source
    }
}

struct EntitiesResponse: Codable, Sendable {
    let entities: [EntityRef]
}

// MARK: - Experiences (anonymous community)

struct ReactionCounts: Codable, Sendable, Equatable {
    let likes: Int
    let dislikes: Int
}

/// Provenance of a published post (contract `ExperienceProvenance`). Decoded
/// leniently: an unknown value falls back to `.verifiedMember`, mirroring the
/// web label fallback, so a future provenance never breaks feed decoding.
enum ExperienceProvenance: String, Codable, Sendable {
    case verifiedLesson = "verified_lesson"
    case verifiedRetrospective = "verified_retrospective"
    case verifiedMember = "verified_member"

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ExperienceProvenance(rawValue: raw) ?? .verifiedMember
    }

    /// Honest label — never "verified use" for dishes (spec §7.3).
    var label: String {
        switch self {
        case .verifiedLesson: return "Verified lesson experience"
        case .verifiedRetrospective: return "Based on a past lesson"
        case .verifiedMember: return "Verified school member"
        }
    }
}

/// A published post as the PUBLIC feed exposes it (contract `PublicExperience`):
/// no author, no raw lesson id, no internal status/policy fields, and only a
/// coarse day bucket (days since epoch) — exact timestamps never exist publicly.
struct PublicExperience: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let entityKey: String
    // Filter-time association context (ids, not names). Names are resolved at
    // the view layer via the directory when available.
    let ctxTeacherId: String?
    let ctxCourseId: String?
    let ctxRoomId: String?
    let body: String?
    let rating: Int?
    let provenance: ExperienceProvenance
    /// Coarse public date bucket (days since the Unix epoch), or nil.
    let publishedDay: Int?
    /// nil means counts are hidden (below the small-cohort threshold).
    let reactions: ReactionCounts?

    enum CodingKeys: String, CodingKey {
        case id
        case entityKey = "entity_key"
        case ctxTeacherId = "ctx_teacher_id"
        case ctxCourseId = "ctx_course_id"
        case ctxRoomId = "ctx_room_id"
        case body
        case rating
        case provenance
        case publishedDay
        case reactions
    }

    /// Display body, empty when the server withheld it.
    var bodyText: String { body ?? "" }

    /// Coarse published date from the day bucket (midnight UTC of that day).
    var publishedDate: Date? {
        guard let d = publishedDay else { return nil }
        return Date(timeIntervalSince1970: Double(d) * 86_400)
    }
}

struct ExperiencesFeedResponse: Codable, Sendable {
    let experiences: [PublicExperience]
}

// MARK: - Own submissions (looked up by client-held ownership keys)

/// A "mine" row only ever exists for a post that was actually published — the
/// check/publish split means rejected drafts are never stored server-side.
enum MyExperienceStatus: String, Codable, Sendable {
    case published
    case blocked
    case revoked
}

/// Own-submission row (contract `MyExperience`).
struct MyExperience: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let entityKey: String
    /// Opaque lesson token — never the roster-joinable instance id.
    let lessonId: String?
    let ctxTeacherId: String?
    let ctxCourseId: String?
    let ctxRoomId: String?
    let body: String?
    let rating: Int?
    let provenance: ExperienceProvenance
    let status: MyExperienceStatus
    let statusDetail: String?
    let policyVersion: Int
    /// Epoch milliseconds.
    let createdAt: Int
    /// Epoch milliseconds, or nil.
    let publishedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case entityKey = "entity_key"
        case lessonId = "lesson_id"
        case ctxTeacherId = "ctx_teacher_id"
        case ctxCourseId = "ctx_course_id"
        case ctxRoomId = "ctx_room_id"
        case body
        case rating
        case provenance
        case status
        case statusDetail = "status_detail"
        case policyVersion = "policy_version"
        case createdAt = "created_at"
        case publishedAt = "published_at"
    }
}

struct MyExperiencesResponse: Codable, Sendable {
    let experiences: [MyExperience]
}

// MARK: - Publication flow: eligibility → check → publish (contract §Experiences)
//
// Publication is a two-call preflight plus an identity-free write:
//   1. POST /api/experiences/eligibility (authenticated) → single-use token
//   2. POST /api/experiences/check       (authenticated) → moderation lane
//      (+ short-lived content-bound pass when the lane permits publication);
//      the draft body is NEVER persisted by check.
//   3. POST /api/experiences/publish     (NO session auth) → verifies the
//      eligibility token + pass and stores the post. The publish request
//      carries no account identity; published posts store no author ID.

struct ExperienceEligibilityRequest: Encodable, Sendable {
    /// Exactly one of lessonId / entityKey.
    let lessonId: String?
    let entityKey: String?
}

struct ExperienceEligibilityResponse: Codable, Sendable {
    let ok: Bool
    /// Single-use, client-held. The server stores only its sha256.
    let eligibilityToken: String
    /// Epoch milliseconds.
    let expiresAt: Int
}

/// Moderation preflight lanes (contract `CheckLane`).
enum CheckLane: String, Codable, Sendable {
    case publish
    case nudge
    case cooldown
    case editRequired = "edit_required"
    case blockedSerious = "blocked_serious"
    case outOfScope = "out_of_scope"
    case failedClosed = "failed_closed"
}

struct CheckExperienceRequest: Encodable, Sendable {
    /// Exactly one of lessonId / entityKey (same target the eligibility is for).
    let lessonId: String?
    let entityKey: String?
    let body: String
    let rating: Int?
    /// Present only when re-checking after a cooldown lane result.
    let cooldownTicket: String?
}

struct CheckCooldown: Codable, Sendable, Equatable {
    let ticket: String
    /// Epoch milliseconds.
    let retryAt: Int
}

struct CheckExperienceResponse: Codable, Sendable {
    let lane: CheckLane
    let reasons: [String]
    let policyVersion: Int
    /// Opaque short-lived content-bound publication pass. Present for lanes
    /// `publish` and `nudge` — a nudge STILL requires the user's explicit
    /// choice; the server never publishes on its own.
    let pass: String?
    /// Present for lane `cooldown`: re-check with this ticket after retryAt.
    let cooldown: CheckCooldown?
}

struct PublishExperienceRequest: Encodable, Sendable {
    let eligibilityToken: String
    let pass: String
    let body: String
    let rating: Int?
}

struct PublishExperienceResponse: Codable, Sendable {
    let ok: Bool
    let experienceId: String
    /// Client-held; the server keeps only a hash. Shown once — store it.
    let ownershipKey: String
}

// MARK: - Publication-flow error codes (contract unions)
//
// The backend sends non-2xx responses as `{ "error": "<code>" }`. Codes are
// matched as raw strings (see `HOneyAPIError.apiErrorCode`) so an unknown
// addition degrades to generic copy instead of failing to parse.

enum ExperienceEligibilityErrorCode: String, Sendable, CaseIterable {
    case publicationsDisabled = "publications_disabled"
    case temporarilySuspended = "temporarily_suspended"
    case targetRequired = "target_required"
    case lessonNotYours = "lesson_not_yours"
    case entityUnknown = "entity_unknown"
    case entityFrozen = "entity_frozen"
    case standaloneClosed = "standalone_closed"
    case notInvited = "not_invited"
    case noVerifiedExposure = "no_verified_exposure"
    case alreadyReviewed = "already_reviewed"
}

/// `CheckExperienceError` minus the eligibility codes it re-exports.
enum CheckExperienceErrorCode: String, Sendable, CaseIterable {
    case bodyInvalid = "body_invalid"
    case ratingInvalid = "rating_invalid"
    case ratingNotAllowed = "rating_not_allowed"
    case cooldownTicketInvalid = "cooldown_ticket_invalid"
}

enum PublishExperienceErrorCode: String, Sendable, CaseIterable {
    case publicationsDisabled = "publications_disabled"
    case passInvalid = "pass_invalid"
    case passContentMismatch = "pass_content_mismatch"
    case passScopeMismatch = "pass_scope_mismatch"
    case eligibilityInvalid = "eligibility_invalid"
    case eligibilityExpired = "eligibility_expired"
    case eligibilityUsed = "eligibility_used"
    case alreadyReviewed = "already_reviewed"
    case entityFrozen = "entity_frozen"
    case ratingNotAllowed = "rating_not_allowed"
}

// MARK: - Reports (category-only; free text is never accepted)

enum ReportCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case seriousAllegation = "serious_allegation"
    case doxxing
    case slur
    case targetsStudent = "targets_student"
    case notExperience = "not_experience"
    case otherRule = "other_rule"

    var id: String { rawValue }

    /// Option labels, identical to the web report dialog.
    var label: String {
        switch self {
        case .seriousAllegation: return "Serious allegation — needs investigation, not a feed"
        case .doxxing: return "Reveals private or identifying information"
        case .slur: return "Slur or dehumanizing language"
        case .targetsStudent: return "Targets a student"
        case .notExperience: return "Not an experience — rumor, secondhand story or spam"
        case .otherRule: return "Another community-rule problem"
        }
    }
}

struct ReportExperienceRequest: Encodable, Sendable {
    let category: ReportCategory
}

// MARK: - Small request/response helpers

struct MineRequest: Codable, Sendable {
    let keys: [String]
}

struct OwnershipKeyRequest: Codable, Sendable {
    let ownershipKey: String
}

struct ReactRequest: Codable, Sendable {
    let value: Int
}

struct SyncResponse: Codable, Sendable {
    /// "ok" | "portal_reconnect_required" | "no_consent" (contract `SyncStatus`).
    let status: String
    let lessons: Int
    let teachers: Int
    let courses: Int
    let rooms: Int
}

/// Experience browse sort order.
enum ExperienceSort: String, Sendable, CaseIterable, Identifiable {
    case newest
    case oldest
    var id: String { rawValue }
    var label: String { self == .newest ? "Newest" : "Oldest" }
}
