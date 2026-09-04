// The school-facing additions to the Core contract since the locked snapshot
// (packages/shared/src/api/contract.ts, 2026-09-03/04): the school's own
// notices, the student's records read live (campus card, weekend stay,
// disciplinary record, lesson feedback), the product switches Dash owns, and
// the actions each surface offers. Field for field, as Wire.swift does.

import Foundation

// MARK: - Notices (GET /api/notices)

/// A notice the school published on the portal — its own words, verbatim,
/// never translated. "Read" is a fact of this device and never travels.
public struct SchoolNotice: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var title: String
    /// Plain text, newlines preserved.
    public var body: String
    public var postedAt: Int64
    /// Equals postedAt when never edited.
    public var updatedAt: Int64

    public init(id: String, title: String, body: String, postedAt: Int64, updatedAt: Int64) {
        self.id = id
        self.title = title
        self.body = body
        self.postedAt = postedAt
        self.updatedAt = updatedAt
    }
}

public struct NoticesResponse: Codable, Sendable, Equatable {
    public var notices: [SchoolNotice]
    public var fetchedAt: Int64?
    /// The portal's origin, so a site-relative attachment path can be opened.
    public var portalOrigin: String

    public init(notices: [SchoolNotice], fetchedAt: Int64?, portalOrigin: String) {
        self.notices = notices
        self.fetchedAt = fetchedAt
        self.portalOrigin = portalOrigin
    }
}

// MARK: - The student's records at the school (read live, stored nowhere)

public enum SchoolReadStatus: String, Codable, Sendable, Equatable {
    case ok
    case portalReconnectRequired = "portal_reconnect_required"
    case unavailable
}

public struct CampusCard: Codable, Sendable, Equatable {
    public var cardNo: String
    /// Yuan. `balance` is what the card can spend; the school splits it in two.
    public var balance: Double
    public var general: Double
    public var subsidy: Double
    public var usable: Bool
    public var validFrom: String
    public var validTo: String
}

public struct CardPurchase: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// The canteen or shop the school names on the record (wire: `where`).
    public var place: String
    public var amount: Double
    public var balanceAfter: Double
    public var at: Int64

    private enum CodingKeys: String, CodingKey {
        case id, place = "where", amount, balanceAfter, at
    }
}

public struct CardTopUp: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var amount: Double
    /// The school's own word for the state ("成功").
    public var state: String
    public var at: Int64
}

public struct CardResponse: Codable, Sendable, Equatable {
    public var status: SchoolReadStatus
    public var card: CampusCard?
    public var purchases: [CardPurchase]
    public var topUps: [CardTopUp]
}

public struct StudentWarning: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var kind: String
    public var rule: String
    public var reason: String
    public var on: String
    public var by: String
    public var recordedAt: String
}

public struct WarningsResponse: Codable, Sendable, Equatable {
    public var status: SchoolReadStatus
    public var warnings: [StudentWarning]
}

public struct WeekendStay: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var date: String
    public var label: String
    public var mentor: String
    public var campus: String
}

public struct WeekendResponse: Codable, Sendable, Equatable {
    public var status: SchoolReadStatus
    public var stays: [WeekendStay]
    /// The days the school currently allows to be chosen.
    public var selectableDays: [String]
}

/// A lesson the school is still waiting on this student's feedback for.
public struct LessonFeedbackItem: Codable, Sendable, Equatable, Identifiable {
    public var lessonId: Int
    public var teacher: String
    public var topic: String
    public var at: Int64
    public var week: Int
    public var id: Int { lessonId }
}

public struct FeedbackResponse: Codable, Sendable, Equatable {
    public var status: SchoolReadStatus
    public var pending: [LessonFeedbackItem]
}

/// The school's own form: a rating, its four issue flags, and a note.
public struct FeedbackSubmission: Encodable, Sendable, Equatable {
    public var lessonId: Int
    public var rating: Int
    public var comment: String
    public var wasLate: Bool
    public var usedMobile: Bool
    public var unprepared: Bool
    public var didNotUnderstand: Bool

    public init(lessonId: Int, rating: Int, comment: String, wasLate: Bool, usedMobile: Bool, unprepared: Bool, didNotUnderstand: Bool) {
        self.lessonId = lessonId
        self.rating = rating
        self.comment = comment
        self.wasLate = wasLate
        self.usedMobile = usedMobile
        self.unprepared = unprepared
        self.didNotUnderstand = didNotUnderstand
    }
}

/// Product switches Dash owns. `lessonFeedback` shows the school's 评教
/// screen (off by default); `schoolFeedback` shows the standalone entry to
/// the school's own feedback channel, which the composer offers in any case.
public struct FeatureFlags: Codable, Sendable, Equatable {
    public var lessonFeedback: Bool
    public var schoolFeedback: Bool

    public init(lessonFeedback: Bool, schoolFeedback: Bool) {
        self.lessonFeedback = lessonFeedback
        self.schoolFeedback = schoolFeedback
    }

    /// What the Web assumes until the server answers.
    public static let defaults = FeatureFlags(lessonFeedback: false, schoolFeedback: true)
}

/// An action taken at the school on the student's behalf.
public enum SchoolActionResponse: Sendable, Equatable, Decodable {
    case ok
    case portalReconnectRequired
    case refused(reason: String)
    case unavailable

    private enum CodingKeys: String, CodingKey { case status, reason }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .status) {
        case "ok": self = .ok
        case "portal_reconnect_required": self = .portalReconnectRequired
        case "refused": self = .refused(reason: try c.decodeIfPresent(String.self, forKey: .reason) ?? "")
        default: self = .unavailable
        }
    }
}

/// The amounts the school's own recharge form offers (2026-09-03).
public let cardTopUpAmounts: [Int] = [100, 200, 300, 500, 1000]

/// POST /api/school/card/topup — the school opens an order and says where to
/// pay it; paying happens afterwards in Alipay, on the school's own page.
public enum CardTopUpResponse: Sendable, Equatable, Decodable {
    case ok(payUrl: String?, formHtml: String?, message: String)
    case portalReconnectRequired
    case refused(reason: String)
    case unavailable

    private enum CodingKeys: String, CodingKey { case status, reason, payUrl, formHtml, message }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .status) {
        case "ok":
            self = .ok(
                payUrl: try c.decodeIfPresent(String.self, forKey: .payUrl),
                formHtml: try c.decodeIfPresent(String.self, forKey: .formHtml),
                message: try c.decodeIfPresent(String.self, forKey: .message) ?? ""
            )
        case "portal_reconnect_required": self = .portalReconnectRequired
        case "refused": self = .refused(reason: try c.decodeIfPresent(String.self, forKey: .reason) ?? "")
        default: self = .unavailable
        }
    }
}
