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

/// Experience "object" kinds. Standalone entities are lesson / teacher / course /
/// room / dish.
enum EntityType: String, Codable, Sendable, CaseIterable {
    case teacher
    case course
    case room
    case dish

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? "course"
        self = EntityType(rawValue: raw) ?? .course
    }
}

struct Entity: Codable, Sendable, Identifiable, Hashable {
    let entityKey: String
    let type: EntityType
    let name: String

    var id: String { entityKey }
}

struct EntitiesResponse: Codable, Sendable {
    let entities: [Entity]
}

// MARK: - Experiences

struct ExperienceReactions: Codable, Sendable, Equatable {
    let likes: Int
    let dislikes: Int
}

/// A published community experience. Storage carries no author identity; the
/// `ctx_*` context fields are best-effort labels used for display only.
struct Experience: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let entityKey: String
    // Filter-time association context (ids, not names). Names are resolved at
    // the view layer via the directory when available.
    let ctxTeacherId: String?
    let ctxCourseId: String?
    let ctxRoomId: String?
    /// Nullable: rejected/failed/revoked rows carry no body (see /experiences/mine).
    let body: String?
    let rating: Int?
    let provenance: String?
    let status: String?
    /// Coarse public date bucket (days since the Unix epoch); no exact timestamp exists.
    let publishedDay: Int?
    let reactions: ExperienceReactions?

    /// Display body, empty when the server withheld it.
    var bodyText: String { body ?? "" }

    /// True when this record is a client-side private note (visually distinct from public).
    var isPrivate: Bool { status?.lowercased() == "private" }

    /// Human provenance label.
    var provenanceLabel: String? {
        switch provenance {
        case "verified_lesson": return "Verified lesson experience"
        case "verified_retrospective": return "Verified retrospective"
        case "verified_member": return "Verified school member"
        default: return provenance
        }
    }

    /// Coarse published date from the day bucket (midnight UTC of that day).
    var publishedDate: Date? {
        guard let d = publishedDay else { return nil }
        return Date(timeIntervalSince1970: Double(d) * 86_400)
    }
}

struct ExperiencesResponse: Codable, Sendable {
    let experiences: [Experience]
}

struct CreateExperienceRequest: Codable, Sendable {
    let lessonId: String?
    let entityKey: String?
    let body: String
    let rating: Int?
}

struct CreateExperienceResponse: Codable, Sendable {
    let ok: Bool
    let experienceId: String
    let ownershipKey: String
    let status: String
}

struct MineRequest: Codable, Sendable {
    let keys: [String]
}

struct OwnershipKeyRequest: Codable, Sendable {
    let ownershipKey: String
}

struct ReactRequest: Codable, Sendable {
    let value: Int
}

struct ReportRequest: Codable, Sendable {
    let category: String
    let note: String
}

struct SyncResponse: Codable, Sendable {
    let status: String
    let lessons: [Lesson]?
}

/// Experience browse sort order.
enum ExperienceSort: String, Sendable, CaseIterable, Identifiable {
    case newest
    case oldest
    var id: String { rawValue }
    var label: String { self == .newest ? "Newest" : "Oldest" }
}
