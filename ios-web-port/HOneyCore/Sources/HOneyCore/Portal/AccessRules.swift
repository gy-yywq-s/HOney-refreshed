// Access domain rules: which permit can open a gate, what a permit row says,
// and the quick-apply defaults. Pure and testable.
//
// The consumed-permit fix (Gary, 2026-09-02): a permit that was already used
// to open a gate — from this app OR from the official site — must not show
// as openable. Approval (`status`) and consumption (`flag`, the door flag
// that /api/exit/update_door_flag sets; the portal may also move status to
// 3 "opened") are different facts, so both are checked, and the list is
// re-read from the portal whenever the screen appears, returns to the
// foreground, is pulled, or after any open attempt.

import Foundation

public enum PermitStatus: Sendable, Equatable, Hashable {
    case pending, approved, rejected, opened
    case unknown(Int)

    public init(_ raw: Int) {
        switch raw {
        case 0: self = .pending
        case 1: self = .approved
        case 2: self = .rejected
        case 3: self = .opened
        default: self = .unknown(raw)
        }
    }
}

public struct ExitPermit: Sendable, Equatable, Hashable, Identifiable {
    public let recordId: Int
    public let status: PermitStatus
    public let statusName: String
    public let note: String
    public let flag: Int
    public let start: Date?
    public let end: Date?
    public let rawStart: String
    public let rawEnd: String
    public let createdAt: Date?

    public var id: Int { recordId }

    public init(_ wire: ExitPermitWire) {
        recordId = wire.recordId
        status = PermitStatus(wire.status)
        statusName = wire.statusName ?? ""
        note = wire.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        flag = wire.flag ?? 0
        rawStart = wire.startTime ?? ""
        rawEnd = wire.endTime ?? ""
        start = PortalTime.parse(wire.startTime)
        end = PortalTime.parse(wire.endTime)
        createdAt = PortalTime.parse(wire.createTime)
    }

    /// Already used at a gate (door flag set) or marked opened by the portal.
    public var isConsumed: Bool { status == .opened || flag != 0 }

    /// Approved, unused, and inside its time window right now.
    public func isOpenable(now: Date = HOneyClock.now()) -> Bool {
        guard status == .approved, !isConsumed, let start, let end else { return false }
        return start <= now && now <= end
    }

    public func isExpired(now: Date = HOneyClock.now()) -> Bool {
        guard let end else { return false }
        return end < now
    }

    /// "Exit" when the note is empty (the portal's default reason is 出门).
    public var displayReason: String { note.isEmpty ? "Exit" : note }

    /// The chip text: the portal's own status name when it has one, with the
    /// consumed state winning over a stale "approved".
    public var displayStatus: String {
        if isConsumed { return status == .opened && !statusName.isEmpty ? statusName : "Used" }
        if !statusName.isEmpty { return statusName }
        switch status {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .opened: return "Opened"
        case .unknown: return "Unknown"
        }
    }

    public enum Tone: Sendable, Equatable { case ok, muted, warning, danger }

    public func tone(now: Date = HOneyClock.now()) -> Tone {
        if isConsumed { return .muted }
        switch status {
        case .approved: return isExpired(now: now) ? .muted : .ok
        case .pending: return .warning
        case .rejected: return .danger
        case .opened, .unknown: return .muted
        }
    }

    /// "Wed 2 Sept · 16:30–18:30"
    public var displayWhen: String {
        guard let start, let end else { return [rawStart, rawEnd].filter { !$0.isEmpty }.joined(separator: " – ") }
        let day = Formatters.shortDate(start)
        return "\(day) · \(Formatters.time(start.epochMillis))–\(Formatters.time(end.epochMillis))"
    }

    /// The most recent openable permit first (legacy ordering).
    public static func openable(_ permits: [ExitPermit], now: Date = HOneyClock.now()) -> [ExitPermit] {
        permits.filter { $0.isOpenable(now: now) }.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
    }

    /// Newest first for the list.
    public static func sortedForList(_ permits: [ExitPermit]) -> [ExitPermit] {
        permits.sorted { ($0.start ?? $0.createdAt ?? .distantPast) > ($1.start ?? $1.createdAt ?? .distantPast) }
    }
}

/// Which route opens the gate.
public enum AccessRoute: Sendable, Equatable, Hashable {
    /// Day student — record_id == -2, no permit needed.
    case commuter
    case permit(recordId: Int)

    public var recordId: Int {
        switch self {
        case .commuter: return commuterRecordId
        case .permit(let id): return id
        }
    }

    public var title: String {
        switch self {
        case .commuter: return "Day student"
        case .permit: return "Exit permit"
        }
    }
}

/// The portal's timestamp format, in the school's local zone.
public enum PortalTime {
    private static var formatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = HOneyClock.timeZone
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }

    public static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return formatter.date(from: text)
    }

    public static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }
}

/// The apply-permit draft: start / end / reason with the quick defaults the
/// legacy app used (now → +2 h, reason 出门).
public struct PermitDraft: Sendable, Equatable {
    public var start: Date
    public var end: Date
    public var reason: String

    public static let defaultReason = "出门"

    public init(start: Date, end: Date, reason: String) {
        self.start = start
        self.end = end
        self.reason = reason
    }

    public static func quick(now: Date = HOneyClock.now()) -> PermitDraft {
        let end = Calendar.schoolLocal.date(byAdding: .hour, value: 2, to: now) ?? now
        return PermitDraft(start: now, end: end, reason: defaultReason)
    }

    /// The end falls on the next calendar day ("+1" badge).
    public var crossesMidnight: Bool {
        !Calendar.schoolLocal.isDate(start, inSameDayAs: end)
    }

    public var cleanedReason: String {
        let cleaned = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? Self.defaultReason : cleaned
    }

    /// Keeps end after start: moving start past end pushes end to +2 h;
    /// picking an end at/before start rolls it to the next day.
    public mutating func setStart(_ newStart: Date) {
        start = newStart
        if end <= newStart {
            end = Calendar.schoolLocal.date(byAdding: .hour, value: 2, to: newStart) ?? newStart
        }
    }

    public mutating func setEnd(_ newEnd: Date) {
        end = newEnd <= start ? (Calendar.schoolLocal.date(byAdding: .day, value: 1, to: newEnd) ?? newEnd) : newEnd
    }

    public var request: AddPermitRequest {
        AddPermitRequest(startTime: PortalTime.string(start), endTime: PortalTime.string(end), note: cleanedReason)
    }
}

/// Copy for Access outcomes, one place.
public enum AccessCopy {
    public static func describe(_ error: Error, fallback: String = "Access is temporarily unavailable.") -> String {
        guard let portalError = error as? PortalError else { return fallback }
        switch portalError {
        case .networkUnavailable: return "You appear to be offline."
        case .timeout(let unknown):
            return unknown
                ? "The request timed out. Check the gate physically before trying again."
                : "The school portal did not answer in time."
        case .serverUnavailable: return "The school portal is temporarily unavailable."
        case .sessionExpired: return "Your school session expired. Try again."
        case .credentialsRejected: return "Your school password may have changed. Update the school login in Settings."
        case .userActionRequired: return "The school portal needs a manual sign-in. Open the School Portal, then try again."
        case .noCredentials: return "Access needs your school login kept on this iPhone. Turn on Stay connected in Settings."
        case .identityMismatch: return "That school login belongs to a different student than this HOney account. Sign in to HOney with the matching school account."
        case .schemaIncompatible: return "The school portal changed and Access needs an update."
        case .operationRejected(_, _, let message):
            if let message, !message.isEmpty { return message }
            return "The school portal refused this action."
        }
    }
}
