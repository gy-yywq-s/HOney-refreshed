// The Now/Next card's temporal logic (Web: HomePage.tsx). One temporal
// sentence across the card: the state on the left, the relative time on
// the right, humanized — "42 min left", "In 45 min" same-day, "Tomorrow ·
// 13:30" / "Thursday · 13:30" beyond — never "In 618 min". A running
// lesson fills the card proportionally to elapsed time.

import Foundation

public struct HomeLessonPresentation: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case now
        case next
    }

    public let state: State
    /// "Now" / "Next lesson" (English keys; views localize).
    public let stateLabel: String
    /// "42 min left" / "In 1 h 4 min" / "Tomorrow · 13:30"
    public let when: String
    /// Starts within ten minutes: the Web tints the time.
    public let soon: Bool
    /// Elapsed fraction 0…1 for a running lesson, nil otherwise.
    public let progress: Double?
    public let subject: String
    public let timeRange: String
    public let teacher: String?
    /// "Room 309" (already labelled), nil when the lesson has no room.
    public let room: String?
    /// The Timetable date this card opens.
    public let isoDate: String
    /// Everything, for VoiceOver: state, subject, time, teacher, room, relative time.
    public let accessibilityLabel: String

    public init(_ next: NextLesson, now: Date = HOneyClock.now()) {
        let lesson = next.lesson
        let nowMs = now.epochMillis
        let cal = Calendar.schoolLocal
        let start = Date(epochMillis: lesson.startsAt)
        let isNow = next.temporalState == .now
        let sameDay = cal.isDate(start, inSameDayAs: now)
        let whenText: String
        if isNow {
            whenText = "\(Formatters.remaining(lesson.endsAt - nowMs)) \(L10n.t("left"))"
        } else if sameDay {
            whenText = "\(L10n.t("In")) \(Formatters.remaining(lesson.startsAt - nowMs))"
        } else {
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now).map { cal.isDate(start, inSameDayAs: $0) } ?? false
            let day = tomorrow ? L10n.t("Tomorrow") : Formatters.weekdayName(lesson.startsAt)
            whenText = "\(day) · \(Formatters.time(lesson.startsAt))"
        }
        state = isNow ? .now : .next
        stateLabel = isNow ? L10n.t("Now") : L10n.t("Next lesson")
        when = whenText
        soon = !isNow && sameDay && (lesson.startsAt - nowMs) < 10 * 60_000
        progress = isNow
            ? min(1, max(0, Double(nowMs - lesson.startsAt) / Double(max(1, lesson.endsAt - lesson.startsAt))))
            : nil
        subject = lesson.subjectName
        timeRange = Formatters.timeRange(lesson.startsAt, lesson.endsAt)
        teacher = lesson.teacherName
        let roomText = DisplayNames.roomLabel(lesson.roomName)
        room = roomText.isEmpty ? nil : roomText
        isoDate = Formatters.toIsoDate(start)
        accessibilityLabel = [
            "\(stateLabel): \(lesson.subjectName)",
            "\(Formatters.time(lesson.startsAt)) to \(Formatters.time(lesson.endsAt))",
            lesson.teacherName,
            room,
            whenText,
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") + ". Open timetable"
    }
}
