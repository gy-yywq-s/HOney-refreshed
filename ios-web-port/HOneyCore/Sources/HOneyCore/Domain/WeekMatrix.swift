// The Week overview's data (Web: features/timetable/WeekView.tsx): a
// school-period MATRIX, not a shrunken calendar. Columns are Mon–Fri (plus a
// weekend day only when it has lessons), rows are the period catalog,
// breaks are one spanning separator, cells carry subject + room only.

import Foundation

public struct WeekMatrix: Sendable, Equatable {
    public struct Cell: Sendable, Equatable {
        public let date: String
        public let band: TimelineBand
        public let lessons: [Lesson]
        public var first: Lesson? { lessons.first }
        public var extraCount: Int { max(0, lessons.count - 1) }
    }

    public struct Unplaced: Sendable, Equatable, Identifiable {
        public let date: String
        public let lesson: Lesson
        public var id: String { lesson.id }
    }

    public let monday: String
    /// The ISO dates shown as columns, Monday first.
    public let dates: [String]
    public let unplaced: [Unplaced]
    private let grid: [String: [Lesson]]

    /// `days` maps ISO date → lessons (nil while loading builds an empty grid).
    public init(monday: String, days: [String: [Lesson]]?) {
        self.monday = monday
        let all = (0..<7).map { Formatters.shiftIsoDate(monday, days: $0) }
        let shown = all.enumerated().filter { i, d in i < 5 || !(days?[d] ?? []).isEmpty }.map(\.element)
        self.dates = shown
        var grid: [String: [Lesson]] = [:]
        var unplaced: [Unplaced] = []
        if let days {
            for date in shown {
                for l in days[date] ?? [] {
                    let s = PeriodCatalog.minuteOfDay(l.startsAt)
                    let e = PeriodCatalog.minuteOfDay(l.endsAt)
                    let hits = PeriodCatalog.periods.filter { PeriodCatalog.overlaps($0, start: s, end: e) }
                    if hits.isEmpty { unplaced.append(Unplaced(date: date, lesson: l)) }
                    for p in hits { grid["\(date)|\(p.id)", default: []].append(l) }
                }
            }
        }
        self.grid = grid
        self.unplaced = unplaced
    }

    public func cell(date: String, band: TimelineBand) -> Cell {
        Cell(date: date, band: band, lessons: grid["\(date)|\(band.id)"] ?? [])
    }

    /// The last weekday index the bar names: 4 (Fri), 5 (Sat) or 6 (Sun).
    public var endOffset: Int { max(4, dates.count - 1) }

    public static func isNow(_ lesson: Lesson, now: Int64) -> Bool {
        now >= lesson.startsAt && now < lesson.endsAt
    }
}
