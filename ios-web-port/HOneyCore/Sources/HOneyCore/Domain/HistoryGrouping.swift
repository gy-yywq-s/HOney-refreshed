// History rows grouped by school day (Web: HistoryPage.tsx): lessons arrive
// in order; "Today · Wednesday, 2 September", "Yesterday · …", else the title.

import Foundation

public struct HistoryDayGroup: Sendable, Equatable, Identifiable {
    public let date: String
    public let label: String
    public var lessons: [Lesson]
    public var id: String { date }
}

public enum HistoryGrouping {
    public static func groupByDay(_ lessons: [Lesson], now: Date = HOneyClock.now()) -> [HistoryDayGroup] {
        var groups: [HistoryDayGroup] = []
        let today = Formatters.todayIsoDate(now: now)
        let yesterday = Formatters.shiftIsoDate(today, days: -1)
        for lesson in lessons {
            let date = Formatters.toIsoDate(Date(epochMillis: lesson.startsAt))
            if var last = groups.last, last.date == date {
                last.lessons.append(lesson)
                groups[groups.count - 1] = last
                continue
            }
            let title = Formatters.dayTitle(date)
            let label = (date == today || date == yesterday)
                ? "\(Formatters.relativeDay(lesson.startsAt, now: now)) · \(title)"
                : title
            groups.append(HistoryDayGroup(date: date, label: label, lessons: [lesson]))
        }
        return groups
    }
}
