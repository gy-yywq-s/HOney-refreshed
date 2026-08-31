//
//  TimetableViewModel.swift
//  HOney — Day-view timetable state (Band 1).
//

import Foundation
import Observation

@MainActor
@Observable
final class TimetableViewModel {
    private let services: AppServices

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var lessons: [Lesson] = []
    var lastSyncedAt: Date?
    var isLoading = false
    var errorMessage: String?

    init(services: AppServices) {
        self.services = services
    }

    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dateString: String { Self.apiDateFormatter.string(from: selectedDate) }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await services.honeyAPI.timetable(date: dateString)
            lessons = response.lessons.sorted { $0.startsAt < $1.startsAt }
            lastSyncedAt = response.lastSyncedAt
        } catch {
            lessons = []
            errorMessage = "Could not load your timetable."
        }
    }

    func goToPreviousDay() { shiftDay(by: -1) }
    func goToNextDay() { shiftDay(by: 1) }
    func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: .now)
        Task { await load() }
    }

    private func shiftDay(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate
        Task { await load() }
    }
}
