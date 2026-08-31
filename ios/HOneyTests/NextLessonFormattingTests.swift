//
//  NextLessonFormattingTests.swift
//  HOneyTests — Home "Next Lesson" temporal formatting.
//

import XCTest
@testable import HOney

final class NextLessonFormattingTests: XCTestCase {

    private func lesson(minutes: Int?, state: LessonTemporalState = .upcoming) -> NextLesson {
        NextLesson(
            id: "l1",
            subjectName: "Maths",
            topicName: nil,
            teacherName: nil,
            courseName: nil,
            roomName: nil,
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            temporalState: state,
            minutesUntilStart: minutes
        )
    }

    func testNoLessonReturnsNoMoreLessons() {
        XCTAssertEqual(NextLessonPresentation.summary(for: nil), "No more lessons today")
    }

    func testZeroMinutesIsNow() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: 0)), "Now")
    }

    func testNegativeMinutesIsNow() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: -3)), "Now")
    }

    func testMinutesUnderAnHour() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: 25)), "in 25 min")
    }

    func testExactHour() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: 60)), "in 1 hr")
    }

    func testHoursAndMinutes() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: 95)), "in 1 hr 35 min")
    }

    func testFallsBackToTemporalStateWhenMinutesMissing() {
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: nil, state: .now)), "Now")
        XCTAssertEqual(NextLessonPresentation.summary(for: lesson(minutes: nil, state: .upcoming)), "Upcoming")
    }
}
