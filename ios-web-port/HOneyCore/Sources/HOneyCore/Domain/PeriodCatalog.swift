// The school day, defined ONCE (Web: lib/periodCatalog.ts): P1–P6 and the two
// named breaks. The Day timeline positions by these minutes; the Week
// matrix uses them as rows. Neither view carries its own copy.

import Foundation

public struct TimelineBand: Sendable, Equatable, Hashable, Identifiable {
    public enum Kind: Sendable, Equatable, Hashable {
        case period(Int)
        case breakTime(label: String)
    }

    public let id: String
    /// Minutes from midnight, local school time.
    public let start: Int
    public let end: Int
    public let kind: Kind

    public var isPeriod: Bool {
        if case .period = kind { return true }
        return false
    }

    public var periodNumber: Int? {
        if case .period(let n) = kind { return n }
        return nil
    }

    public var breakLabel: String? {
        if case .breakTime(let label) = kind { return label }
        return nil
    }
}

public enum PeriodCatalog {
    public static let bands: [TimelineBand] = [
        TimelineBand(id: "p1", start: 9 * 60, end: 10 * 60 + 30, kind: .period(1)),
        TimelineBand(id: "p2", start: 10 * 60 + 30, end: 12 * 60, kind: .period(2)),
        TimelineBand(id: "lunch", start: 12 * 60, end: 13 * 60 + 30, kind: .breakTime(label: "Lunch Break")),
        TimelineBand(id: "p3", start: 13 * 60 + 30, end: 15 * 60, kind: .period(3)),
        TimelineBand(id: "p4", start: 15 * 60, end: 16 * 60 + 30, kind: .period(4)),
        TimelineBand(id: "p5", start: 16 * 60 + 30, end: 18 * 60, kind: .period(5)),
        TimelineBand(id: "dinner", start: 18 * 60, end: 18 * 60 + 30, kind: .breakTime(label: "Dinner Break")),
        TimelineBand(id: "p6", start: 18 * 60 + 30, end: 20 * 60, kind: .period(6)),
    ]

    public static let periods: [TimelineBand] = bands.filter { $0.isPeriod }
    public static let breaks: [TimelineBand] = bands.filter { !$0.isPeriod }

    /// Minute of the (school-local) day for an epoch-ms instant.
    public static func minuteOfDay(_ epochMillis: Int64, calendar: Calendar = .schoolLocal) -> Int {
        let date = Date(epochMillis: epochMillis)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    public static func overlaps(_ slot: TimelineBand, start: Int, end: Int) -> Bool {
        start < slot.end && end > slot.start
    }

    /// "P3" for the FIRST period the lesson overlaps, nil outside the periods.
    public static func periodLabel(start: Int, end: Int) -> String? {
        periodOf(start: start, end: end).flatMap { $0.periodNumber }.map { "P\($0)" }
    }

    public static func periodOf(start: Int, end: Int) -> TimelineBand? {
        periods.first { overlaps($0, start: start, end: end) }
    }

    /// Minutes → "13:30".
    public static func minuteLabel(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        return String(format: "%02d:%02d", h, m)
    }
}

public extension Calendar {
    /// The calendar every domain computation uses: Gregorian in the
    /// device's local zone (the student is at the school; the Web does the
    /// same with `new Date(...)`). Tests override the zone explicitly.
    static var schoolLocal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = HOneyClock.timeZone
        c.locale = Locale(identifier: "en_GB")
        return c
    }
}

/// Process-wide clock/zone override point: production leaves it alone
/// (TimeZone.current, Date()); tests pin Asia/Shanghai and a fixed instant.
public enum HOneyClock {
    nonisolated(unsafe) public static var timeZone: TimeZone = .current
    nonisolated(unsafe) public static var now: @Sendable () -> Date = { Date() }
}
