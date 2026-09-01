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

    @MainActor
    func testHomeRefreshFailureKeepsPreviouslyLoadedLessonAndExperiences() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-cache-tests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: tempDir)
            StubURLProtocol.responses = [:]
        }
        let services = AppServices.stub(tempDir: tempDir)
        try await services.sessionStore.save(HOneySession(
            accessToken: "access",
            accessExpiresAt: Date().addingTimeInterval(3600),
            refreshToken: "refresh",
            refreshExpiresAt: Date().addingTimeInterval(7200)
        ))
        StubURLProtocol.responses["/api/next-lesson"] = (200, Data("""
        {
          "nextLesson": {
            "id": "next-1", "subjectName": "Maths", "topicName": null,
            "teacherName": "Ms Lin", "courseName": "Maths", "roomName": "201",
            "startsAt": 1788300000000, "endsAt": 1788303600000,
            "temporalState": "upcoming", "minutesUntilStart": 20
          },
          "lastSyncedAt": null
        }
        """.utf8))
        StubURLProtocol.responses["/api/experiences/from-my-classes"] = (200, Data("""
        {"experiences":[{
          "id":"e1", "entity_key":"teacher:t1", "ctx_teacher_id":"t1",
          "ctx_course_id":null, "ctx_room_id":null, "body":"Clear explanations.",
          "rating":null, "provenance":"verified_lesson", "publishedDay":null,
          "reactions":null
        }]}
        """.utf8))
        StubURLProtocol.responses["/api/directory"] = (200, Data("""
        {"teachers":[{"id":"t1","name":"Ms Lin"}],"courses":[],"rooms":[]}
        """.utf8))
        StubURLProtocol.responses["/api/entities"] = (200, Data("{\"entities\":[]}".utf8))

        let viewModel = HomeViewModel(services: services)
        await viewModel.load()
        XCTAssertEqual(viewModel.nextLesson?.id, "next-1")
        XCTAssertEqual(viewModel.recentExperiences.map(\.id), ["e1"])

        StubURLProtocol.responses["/api/next-lesson"] = (503, Data("unavailable".utf8))
        StubURLProtocol.responses["/api/experiences/from-my-classes"] = (503, Data("unavailable".utf8))
        await viewModel.load(forceRefresh: true)

        XCTAssertEqual(viewModel.nextLesson?.id, "next-1")
        XCTAssertEqual(viewModel.recentExperiences.map(\.id), ["e1"])
        XCTAssertFalse(viewModel.nextLessonAvailable)
        XCTAssertFalse(viewModel.recentExperiencesAvailable)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
