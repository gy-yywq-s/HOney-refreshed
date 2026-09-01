//
//  TimetableViewModelTests.swift
//  HOneyTests — cache, cancellation, prefetch and stale-response protection.
//

import XCTest
@testable import HOney

private actor DelayedTimetableProvider: TimetableProviding {
    var delays: [String: UInt64] = [:]
    var ignoresCancellation: Set<String> = []
    private var counts: [String: Int] = [:]

    func configure(date: String, delayNanos: UInt64, ignoreCancellation: Bool = false) {
        delays[date] = delayNanos
        if ignoreCancellation { ignoresCancellation.insert(date) }
    }

    func timetable(date: String) async throws -> TimetableResponse {
        counts[date, default: 0] += 1
        if let delay = delays[date], delay > 0 {
            if ignoresCancellation.contains(date) {
                try? await Task.sleep(nanoseconds: delay)
            } else {
                try await Task.sleep(nanoseconds: delay)
            }
        }
        return TimetableResponse(
            date: date,
            lessons: [Self.lesson(id: date)],
            lastSyncedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func callCount(for date: String) -> Int { counts[date, default: 0] }

    private static func lesson(id: String) -> Lesson {
        Lesson(
            id: id,
            subjectName: id,
            topicName: nil,
            teacherId: nil,
            teacherName: "Teacher",
            courseId: nil,
            courseName: nil,
            roomId: nil,
            roomName: "Room",
            startsAt: Date(timeIntervalSince1970: 1_700_000_000),
            endsAt: Date(timeIntervalSince1970: 1_700_003_600)
        )
    }
}

@MainActor
final class TimetableViewModelTests: XCTestCase {
    func testRapidNavigationNeverAppliesAnOlderResponse() async throws {
        let provider = DelayedTimetableProvider()
        let dayOne = try XCTUnwrap(Self.date("2026-09-01"))
        let dayTwo = try XCTUnwrap(Self.date("2026-09-02"))
        await provider.configure(date: "2026-09-01", delayNanos: 220_000_000, ignoreCancellation: true)
        await provider.configure(date: "2026-09-02", delayNanos: 20_000_000)
        let model = TimetableViewModel(repository: TimetableRepository(provider: provider))

        model.selectDate(dayOne)
        try await waitUntil { await provider.callCount(for: "2026-09-01") == 1 }
        model.selectDate(dayTwo)

        try await waitUntil { !model.isLoading && model.lessons.first?.id == "2026-09-02" }
        try await Task.sleep(nanoseconds: 260_000_000)

        XCTAssertEqual(model.dateString, "2026-09-02")
        XCTAssertEqual(model.lessons.first?.id, "2026-09-02")
    }

    func testFreshCacheSurvivesViewModelRecreationWithoutAnotherRequest() async throws {
        let provider = DelayedTimetableProvider()
        let repository = TimetableRepository(provider: provider)
        let date = try XCTUnwrap(Self.date("2026-09-03"))
        let first = TimetableViewModel(repository: repository)

        first.selectDate(date)
        try await waitUntil { !first.isLoading && first.lessons.first?.id == "2026-09-03" }
        let second = TimetableViewModel(repository: repository)
        second.selectDate(date)
        try await waitUntil { !second.isLoading && second.lessons.first?.id == "2026-09-03" }

        let calls = await provider.callCount(for: "2026-09-03")
        XCTAssertEqual(calls, 1)
    }

    func testABASequenceCoalescesTheSameDateAndRejectsIntermediateState() async throws {
        let provider = ABATimetableProvider()
        let repository = TimetableRepository(provider: provider)
        let dayA = try XCTUnwrap(Self.date("2026-09-07"))
        let dayB = try XCTUnwrap(Self.date("2026-09-08"))
        let model = TimetableViewModel(repository: repository)

        model.selectDate(dayA)
        try await waitUntil { await provider.callCount(for: "2026-09-07") == 1 }
        model.selectDate(dayB)
        try await waitUntil { await provider.callCount(for: "2026-09-08") == 1 }
        model.selectDate(dayA)

        try await waitUntil { model.lessons.first?.id == "A-1" }
        try await Task.sleep(nanoseconds: 260_000_000)

        XCTAssertEqual(model.dateString, "2026-09-07")
        XCTAssertEqual(model.lessons.first?.id, "A-1")
    }

    func testAdjacentDayIsPrefetchedAndOpensWithoutASecondRequest() async throws {
        let provider = DelayedTimetableProvider()
        let repository = TimetableRepository(provider: provider)
        let firstDate = try XCTUnwrap(Self.date("2026-09-04"))
        let nextDate = try XCTUnwrap(Self.date("2026-09-05"))
        let model = TimetableViewModel(repository: repository)

        model.selectDate(firstDate)
        try await waitUntil { !model.isLoading && model.lessons.first?.id == "2026-09-04" }
        try await waitUntil { await provider.callCount(for: "2026-09-05") == 1 }

        model.selectDate(nextDate)
        try await waitUntil { !model.isLoading && model.lessons.first?.id == "2026-09-05" }

        let calls = await provider.callCount(for: "2026-09-05")
        XCTAssertEqual(calls, 1)
    }

    func testEmptyDayIsCached() async throws {
        let provider = EmptyTimetableProvider()
        let repository = TimetableRepository(provider: provider)
        let date = try XCTUnwrap(Self.date("2026-09-06"))
        let first = TimetableViewModel(repository: repository)
        first.selectDate(date)
        try await waitUntil { await provider.callCount(for: "2026-09-06") == 1 && !first.isLoading }

        let second = TimetableViewModel(repository: repository)
        second.selectDate(date)
        try await waitUntil { !second.isLoading }

        XCTAssertTrue(second.lessons.isEmpty)
        let calls = await provider.callCount(for: "2026-09-06")
        XCTAssertEqual(calls, 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met before timeout")
    }

    private static func date(_ string: String) -> Date? {
        TimetableViewModel.apiDateFormatter.date(from: string)
    }
}

private actor EmptyTimetableProvider: TimetableProviding {
    private var counts: [String: Int] = [:]

    func timetable(date: String) async throws -> TimetableResponse {
        counts[date, default: 0] += 1
        return TimetableResponse(date: date, lessons: [], lastSyncedAt: nil)
    }

    func callCount(for date: String) -> Int { counts[date, default: 0] }
}

private actor ABATimetableProvider: TimetableProviding {
    private var aCalls = 0
    private var bCalls = 0

    func timetable(date: String) async throws -> TimetableResponse {
        let id: String
        if date == "2026-09-07" {
            aCalls += 1
            let call = aCalls
            if call == 1 {
                try? await Task.sleep(nanoseconds: 220_000_000)
            } else {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            id = "A-" + String(call)
        } else {
            bCalls += 1
            try? await Task.sleep(nanoseconds: 80_000_000)
            id = "B"
        }
        return TimetableResponse(
            date: date,
            lessons: [Lesson(
                id: id,
                subjectName: id,
                topicName: nil,
                teacherId: nil,
                teacherName: nil,
                courseId: nil,
                courseName: nil,
                roomId: nil,
                roomName: nil,
                startsAt: Date(timeIntervalSince1970: 1_700_000_000),
                endsAt: Date(timeIntervalSince1970: 1_700_003_600)
            )],
            lastSyncedAt: nil
        )
    }

    func callCount(for date: String) -> Int {
        date == "2026-09-07" ? aCalls : bCalls
    }
}
