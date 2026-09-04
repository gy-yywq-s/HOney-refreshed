import XCTest
@testable import HOneyCore

final class PeriodCatalogTests: XCTestCase {
    func testBandsCoverTheSchoolDayOnce() {
        let bands = PeriodCatalog.bands
        XCTAssertEqual(bands.first?.start, 9 * 60)
        XCTAssertEqual(bands.last?.end, 20 * 60)
        for (a, b) in zip(bands, bands.dropFirst()) { XCTAssertEqual(a.end, b.start, "bands must be contiguous") }
        XCTAssertEqual(PeriodCatalog.periods.compactMap(\.periodNumber), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(PeriodCatalog.breaks.compactMap(\.breakLabel), ["Lunch Break", "Dinner Break"])
    }

    func testPeriodLabelIsTheFirstOverlappingPeriod() {
        XCTAssertEqual(PeriodCatalog.periodLabel(start: 13 * 60 + 30, end: 15 * 60), "P3")
        XCTAssertEqual(PeriodCatalog.periodLabel(start: 8 * 60 + 30, end: 10 * 60), "P1")
        XCTAssertNil(PeriodCatalog.periodLabel(start: 8 * 60, end: 8 * 60 + 40))
        XCTAssertEqual(PeriodCatalog.minuteLabel(13 * 60 + 5), "13:05")
    }

    func testMinuteOfDayUsesTheSchoolZone() {
        PinnedClock.at("2026-09-02T00:00:00Z") {
            XCTAssertEqual(PeriodCatalog.minuteOfDay(PinnedClock.ms("2026-09-02 16:30")), 16 * 60 + 30)
        }
    }
}

final class DisplayNamesTests: XCTestCase {
    func testLessonTitlesMatchTheWeb() {
        // The canonical Course is the title; an unresolved label falls back to the Subject.
        XCTAssertEqual(DisplayNames.lessonTitle(courseName: "AL ECON U4", subjectName: "Economics"), "AL ECON U4")
        XCTAssertEqual(DisplayNames.lessonTitle(courseName: nil, subjectName: "Public Speaking"), "Public Speaking")
        // Week cells drop the level from a course code; subjects compact.
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: "AL ECON U4", subjectName: "Economics"), "ECON U4")
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: "AL CHIN", subjectName: "Chinese"), "CHIN")
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: "IELTS Speaking", subjectName: "IELTS"), "IELTS Speaking")
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: "IELTS Speaking", subjectName: "IELTS", phone: true), "IELTS Speaking", "no curated short form → the code stays (same as the Web)")
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: nil, subjectName: "CIE Chinese Language & Literature"), "Chinese")
        XCTAssertEqual(DisplayNames.compactLessonTitle(courseName: nil, subjectName: "Edexcel Economics-U4", phone: true), "Econ")
    }

    func testRoomLabel() {
        XCTAssertEqual(DisplayNames.roomLabel("309"), "Room 309")
        XCTAssertEqual(DisplayNames.roomLabel("A203"), "A203")
        XCTAssertEqual(DisplayNames.roomLabel("Library"), "Library")
        XCTAssertEqual(DisplayNames.roomLabel(nil), "")
    }

    func testCompactSubjectName() {
        XCTAssertEqual(DisplayNames.compactSubjectName("Edexcel Economics-U4"), "Economics")
        XCTAssertEqual(DisplayNames.compactSubjectName("CIE Chinese Language & Literature"), "Chinese")
        XCTAssertEqual(DisplayNames.compactSubjectName("IELTS-Speaking"), "IELTS")
        XCTAssertEqual(DisplayNames.compactSubjectName("CIE Physics-A2"), "Physics")
        XCTAssertEqual(DisplayNames.compactSubjectName("Activity"), "Activity")
        XCTAssertEqual(DisplayNames.compactSubjectName("Public Speaking"), "Public Speaking")
        XCTAssertEqual(DisplayNames.compactSubjectName("TMUA"), "TMUA")
    }

    func testShortSubjectName() {
        XCTAssertEqual(DisplayNames.shortSubjectName("Edexcel Economics-U4"), "Econ")
        XCTAssertEqual(DisplayNames.shortSubjectName("CIE Physics-A2"), "Physics")
        XCTAssertEqual(DisplayNames.shortSubjectName("Activity"), "Activity")
        XCTAssertEqual(DisplayNames.shortSubjectName("Public Speaking"), "Public Speaking")
    }
}

final class FormattersTests: XCTestCase {
    func testEnGBOutputMatchesTheWeb() {
        PinnedClock.at("2026-09-02T06:00:00Z") {
            XCTAssertEqual(Formatters.todayIsoDate(), "2026-09-02")
            XCTAssertEqual(Formatters.dayTitle("2026-09-02"), "Wednesday, 2 September")
            XCTAssertEqual(Formatters.shortDate(PinnedClock.ms("2026-09-01 15:00")), "Tue 1 Sept")
            XCTAssertEqual(Formatters.time(PinnedClock.ms("2026-09-02 13:30")), "13:30")
            XCTAssertEqual(Formatters.timeRange(PinnedClock.ms("2026-09-02 16:30"), PinnedClock.ms("2026-09-02 18:00")), "16:30–18:00")
            XCTAssertEqual(Formatters.mondayOf("2026-09-02"), "2026-08-31")
            XCTAssertEqual(Formatters.mondayOf("2026-09-06"), "2026-08-31")
            XCTAssertEqual(Formatters.shiftIsoDate("2026-08-31", days: 6), "2026-09-06")
            XCTAssertEqual(Formatters.weekRange(monday: "2026-08-31"), "31 Aug – 4 Sept")
            XCTAssertEqual(Formatters.weekRange(monday: "2026-09-07"), "7 – 11 Sept")
            XCTAssertEqual(Formatters.remaining(3 * 3_600_000 + 12 * 60_000), "3 h 12 min")
            XCTAssertEqual(Formatters.remaining(45 * 60_000), "45 min")
            XCTAssertEqual(Formatters.remaining(2 * 3_600_000), "2 h")
            XCTAssertEqual(Formatters.remaining(10), "1 min")
            XCTAssertEqual(Formatters.dayBucket(20698), "2 Sept 2026")
            XCTAssertEqual(Formatters.relativeDay(PinnedClock.ms("2026-09-02 08:30")), "Today")
            XCTAssertEqual(Formatters.relativeDay(PinnedClock.ms("2026-09-01 08:30")), "Yesterday")
            XCTAssertEqual(Formatters.relativeDay(PinnedClock.ms("2026-08-28 08:30")), "Fri 28 Aug")
            XCTAssertEqual(Formatters.timeAgo("2026-09-02T05:30:00.000Z"), "30 min ago")
            XCTAssertEqual(Formatters.timeAgo("2026-09-02T02:00:00.000Z"), "4 h ago")
            XCTAssertTrue(Formatters.isValidIsoDate("2026-09-02"))
            XCTAssertFalse(Formatters.isValidIsoDate("2026-13-45"))
            XCTAssertFalse(Formatters.isValidIsoDate("2026-02-30"))
        }
    }
}

final class HomeLessonTests: XCTestCase {
    func testNowCardCountsDownAndFills() throws {
        try PinnedClock.at("2026-09-02T09:15:00Z") { // 17:15 Shanghai, Activity 16:30–18:00
            let next = try Fixtures.decode(NextLessonResponse.self, "next-lesson-now").nextLesson!
            let p = HomeLessonPresentation(next)
            XCTAssertEqual(p.state, .now)
            XCTAssertEqual(p.when, "45 min left")
            XCTAssertEqual(p.progress!, 0.5, accuracy: 0.001)
            XCTAssertEqual(p.timeRange, "16:30–18:00")
            XCTAssertNil(p.room)
            XCTAssertEqual(p.teacher, "活动课老师")
            XCTAssertEqual(p.isoDate, "2026-09-02")
            XCTAssertFalse(p.soon)
        }
    }

    func testUpcomingSameDayAndBeyond() throws {
        try PinnedClock.at("2026-09-02T04:45:00Z") { // 12:45, Econ at 13:30 today
            let econ = try Fixtures.decode(TimetableResponse.self, "timetable-day").lessons[1]
            let p = HomeLessonPresentation(NextLesson(lesson: econ, temporalState: .upcoming, minutesUntilStart: 45))
            XCTAssertEqual(p.stateLabel, "Next lesson")
            XCTAssertEqual(p.when, "In 45 min")
            XCTAssertEqual(p.room, "Room 309")
            XCTAssertNil(p.progress)
        }
        try PinnedClock.at("2026-09-02T05:25:00Z") { // 13:25, five minutes before → soon
            let econ = try Fixtures.decode(TimetableResponse.self, "timetable-day").lessons[1]
            let p = HomeLessonPresentation(NextLesson(lesson: econ, temporalState: .upcoming, minutesUntilStart: 5))
            XCTAssertTrue(p.soon)
        }
        try PinnedClock.at("2026-09-02T12:00:00Z") { // 20:00, Chinese tomorrow 10:30
            let next = try Fixtures.decode(NextLessonResponse.self, "next-lesson-upcoming").nextLesson!
            let p = HomeLessonPresentation(next)
            XCTAssertEqual(p.when, "Tomorrow · 10:30")
        }
        try PinnedClock.at("2026-09-01T12:00:00Z") { // Tuesday evening, Chinese on Thursday
            let next = try Fixtures.decode(NextLessonResponse.self, "next-lesson-upcoming").nextLesson!
            XCTAssertEqual(HomeLessonPresentation(next).when, "Thursday · 10:30")
        }
    }
}

final class DayAndWeekTests: XCTestCase {
    func testDayRangeWidensToTheHourForEarlyLessons() throws {
        try PinnedClock.at("2026-09-02T00:00:00Z") {
            let day = try Fixtures.decode(TimetableResponse.self, "timetable-day")
            let layout = DayLayout(lessons: day.lessons)
            XCTAssertEqual(layout.range.start, 8 * 60, "08:30 lesson widens the canvas to 08:00")
            XCTAssertEqual(layout.range.end, 20 * 60)
            XCTAssertEqual(layout.lessons.map(\.periodLabel), ["P1", "P3", "P5"])
            XCTAssertEqual(layout.freePeriods.compactMap(\.periodNumber), [2, 4, 6])
            XCTAssertEqual(layout.range.fraction(8 * 60), 0)
            XCTAssertEqual(layout.range.fraction(20 * 60), 1)
            XCTAssertEqual(layout.range.hourMarks.count, 13)
            let live = layout.lessons[1]
            XCTAssertTrue(layout.isLive(live, nowMinute: 14 * 60))
            XCTAssertEqual(layout.landingLesson(nowMinute: 14 * 60, isToday: true)?.id, live.id)
            XCTAssertEqual(layout.landingLesson(nowMinute: 15 * 60 + 10, isToday: true)?.id, layout.lessons[2].id)
            XCTAssertEqual(layout.landingLesson(nowMinute: 21 * 60, isToday: true)?.id, layout.lessons[0].id)
            XCTAssertEqual(layout.landingLesson(nowMinute: 14 * 60, isToday: false)?.id, layout.lessons[0].id)
        }
    }

    func testEmptyDayKeepsDefaultRange() {
        let layout = DayLayout(lessons: [])
        XCTAssertEqual(layout.range, DayRange(start: 9 * 60, end: 20 * 60))
        XCTAssertNil(layout.landingLesson(nowMinute: 600, isToday: true))
        XCTAssertEqual(layout.freePeriods.count, 6)
    }

    func testWeekMatrixPlacesLessonsAndShowsSaturdayOnlyWithLessons() throws {
        try PinnedClock.at("2026-09-02T00:00:00Z") {
            let range = try Fixtures.decode(TimetableRangeResponse.self, "timetable-range")
            let days = Dictionary(uniqueKeysWithValues: range.days.map { ($0.date, $0.lessons) })
            let matrix = WeekMatrix(monday: "2026-08-31", days: days)
            XCTAssertEqual(matrix.dates, ["2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05"], "Saturday has a lesson, Sunday does not")
            XCTAssertEqual(matrix.endOffset, 5)
            let p3 = PeriodCatalog.periods[2]
            XCTAssertEqual(matrix.cell(date: "2026-09-02", band: p3).first?.title, "AL ECON U4")
            XCTAssertEqual(matrix.cell(date: "2026-09-02", band: PeriodCatalog.periods[1]).lessons.count, 0)
            XCTAssertEqual(matrix.unplaced.map { $0.lesson.title }, ["Morning Reading"], "08:00–08:40 overlaps no period")
            XCTAssertEqual(matrix.cell(date: "2026-09-02", band: PeriodCatalog.periods[0]).first?.title, "IELTS Speaking", "08:30–10:00 overlaps P1")
            let loading = WeekMatrix(monday: "2026-08-31", days: nil)
            XCTAssertEqual(loading.dates.count, 5)
        }
    }

    func testHistoryGroupsByDayWithRelativeLabels() throws {
        try PinnedClock.at("2026-09-02T06:00:00Z") {
            let history = try Fixtures.decode(HistoryResponse.self, "history")
            let groups = HistoryGrouping.groupByDay(history.lessons)
            XCTAssertEqual(groups.map(\.date), ["2026-09-02", "2026-09-01"])
            XCTAssertEqual(groups[0].label, "Today · Wednesday, 2 September")
            XCTAssertEqual(groups[1].label, "Yesterday · Tuesday, 1 September")
            XCTAssertEqual(groups[0].lessons.count, 3)
        }
    }
}

final class ExperienceDisplayTests: XCTestCase {
    func testContextPartsReadCourseTeacherRoom() throws {
        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        // Names are joined client-side from Core's directory (the wire carries ids only).
        let directory = try Fixtures.decode(DirectoryResponse.self, "directory")
        let names: NameResolver = { ref in
            switch ref.type {
            case .course: return directory.courses.first { $0.id == ref.id }?.name
            case .teacher: return directory.teachers.first { $0.id == ref.id }?.name
            case .room: return directory.rooms.first { $0.id == ref.id }?.name
            default: return nil
            }
        }
        let parts = ExperienceDisplay.contextParts(page.items[0], name: names)
        XCTAssertEqual(parts.map(\.ref.type), [.course, .teacher, .room])
        XCTAssertEqual(parts.map(\.name), ["AL ECON U4", "朱昂明", "309"])
        XCTAssertEqual(ExperienceDisplay.contextParts(page.items[1], name: names).map(\.name), ["Jennifer Anne Whitcombe-Rasmussen"])
        XCTAssertEqual(ExperienceDisplay.contextParts(page.items[2], name: { _ in nil }).count, 0, "an unnamed primary is not shown")
        XCTAssertEqual(ExperienceDisplay.provenanceText(page.items[0]), "from a class you’ve taken · 2 Sept 2026")
        XCTAssertTrue(ExperienceDisplay.isFeature(page.items[0].body!))
        XCTAssertFalse(ExperienceDisplay.isFeature(page.items[1].body!))
        let clamped = ExperienceDisplay.clampedBody(page.items[1].body!, expanded: false)
        XCTAssertTrue(clamped.clamped)
        XCTAssertTrue(clamped.text.hasSuffix("…"))
        XCTAssertLessThanOrEqual(clamped.text.count, ExperienceDisplay.clampChars + 1)
        XCTAssertFalse(ExperienceDisplay.clampedBody(page.items[1].body!, expanded: true).clamped)
        XCTAssertEqual(ExperienceDisplay.previewCaption(page.items[0], name: names), "AL ECON U4 · 朱昂明 · 2 Sept 2026")
        XCTAssertEqual(ExperienceDisplay.route(for: page.items[0].primary), nil, "lessons have no public page")
        XCTAssertEqual(ExperienceDisplay.route(for: page.items[1].primary), .entity(.teacher, "t_23348879d1b4"))
        XCTAssertEqual(ExperienceDisplay.route(for: EntityRef(entityKey: "dish:d_001", type: .dish, name: "x", source: "admin")), .entity(.dish, "d_001"))
    }

    func testReasonCopyHidesUnknownCodes() {
        XCTAssertEqual(ModerationCopy.describeReasons(["timing:high_arousal", "internal:x"]).count, 1)
        XCTAssertEqual(SubmitErrorCopy.describe(APIError(status: 422, code: "already_posted")), SubmitErrorCopy.byCode["already_posted"])
        XCTAssertEqual(SubmitErrorCopy.describe(APIError(status: 422, code: "token_used")), SubmitErrorCopy.byCode["token_used"])
        XCTAssertEqual(SubmitErrorCopy.describe(APIError.networkError), "Could not reach the HOney server. Check your connection and try again.")
    }

    func testLocalization() {
        L10n.language = .zh
        XCTAssertEqual(L10n.t("Keep private"), "保留为私密")
        XCTAssertEqual(L10n.t("Written by students, for students."), "Written by students, for students.", "kept English by decision")
        XCTAssertEqual(L10n.greeting("沈高远"), "你好，沈高远")
        L10n.language = .en
        XCTAssertEqual(L10n.t("Keep private"), "Keep private")
        XCTAssertEqual(L10n.greeting("Alex"), "Hi, Alex")
        L10n.language = .system
    }
}
