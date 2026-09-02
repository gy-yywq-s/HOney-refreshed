// The Day timeline's geometry (Web: TimetablePage.tsx DayTimeline). The
// canvas covers 09:00–20:00 and widens to the hour whenever a lesson falls
// outside it (08:30 lessons exist in real data; a clipped block is not an
// option). Positions are fractions of the canvas height, so the canvas may
// be any height.

import Foundation

public struct DayRange: Sendable, Equatable {
    public static let defaultStart = 9 * 60
    public static let defaultEnd = 20 * 60

    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public static func covering(_ lessons: [Lesson]) -> DayRange {
        var start = defaultStart
        var end = defaultEnd
        for l in lessons {
            start = min(start, (PeriodCatalog.minuteOfDay(l.startsAt) / 60) * 60)
            end = max(end, Int((Double(PeriodCatalog.minuteOfDay(l.endsAt)) / 60).rounded(.up)) * 60)
        }
        return DayRange(start: start, end: end)
    }

    public var minutes: Int { end - start }

    public func clamp(_ minute: Int) -> Int { min(max(minute, start), end) }

    public func fraction(_ minute: Int) -> Double {
        Double(clamp(minute) - start) / Double(max(1, end - start))
    }

    public func height(from startMinute: Int, to endMinute: Int) -> Double {
        max(0, fraction(endMinute) - fraction(startMinute))
    }

    public var hourMarks: [Int] {
        Array(stride(from: start, through: end, by: 60))
    }
}

public struct PlacedLesson: Sendable, Equatable, Identifiable {
    public let lesson: Lesson
    public let startMinute: Int
    public let endMinute: Int
    /// Under 45 minutes: the block shows subject only.
    public let compact: Bool
    public let periodLabel: String?
    public var id: String { lesson.id }
}

public struct DayLayout: Sendable, Equatable {
    public let range: DayRange
    public let lessons: [PlacedLesson]
    /// Periods no lesson overlaps → "P3 · Free" ghost labels.
    public let freePeriods: [TimelineBand]

    public init(lessons: [Lesson]) {
        let range = DayRange.covering(lessons)
        self.range = range
        self.lessons = lessons.compactMap { l in
            let s = PeriodCatalog.minuteOfDay(l.startsAt)
            let e = PeriodCatalog.minuteOfDay(l.endsAt)
            guard range.clamp(e) > range.clamp(s) else { return nil }
            return PlacedLesson(lesson: l, startMinute: s, endMinute: e, compact: e - s < 45, periodLabel: PeriodCatalog.periodLabel(start: s, end: e))
        }
        self.freePeriods = PeriodCatalog.periods.filter { slot in
            !lessons.contains { PeriodCatalog.overlaps(slot, start: PeriodCatalog.minuteOfDay($0.startsAt), end: PeriodCatalog.minuteOfDay($0.endsAt)) }
        }
    }

    public func isLive(_ placed: PlacedLesson, nowMinute: Int) -> Bool {
        nowMinute >= placed.startMinute && nowMinute < placed.endMinute
    }

    public func showsNowLine(nowMinute: Int) -> Bool {
        nowMinute >= range.start && nowMinute <= range.end
    }

    /// Where Day should land on cold entry: the running lesson, else the
    /// next one still ahead today, else the first lesson.
    public func landingLesson(nowMinute: Int, isToday: Bool) -> PlacedLesson? {
        guard !lessons.isEmpty else { return nil }
        if isToday {
            if let live = lessons.first(where: { isLive($0, nowMinute: nowMinute) }) { return live }
            if let upcoming = lessons.first(where: { $0.startMinute >= nowMinute }) { return upcoming }
        }
        return lessons.first
    }
}
