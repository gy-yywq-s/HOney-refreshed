//
//  TimetableViewModel.swift
//  HOney — responsive, cached and race-safe day-view state.
//

import Foundation
import Observation
import os.signpost

@MainActor
@Observable
final class TimetableViewModel {
    private let repository: TimetableRepository
    private let signpostLog = OSLog(subsystem: "com.gaelisus.honey", category: "Timetable")
    private var loadTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var requestGeneration = 0

    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var lessons: [Lesson] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?

    init(services: AppServices) {
        self.repository = services.timetableRepository
    }

    init(repository: TimetableRepository) {
        self.repository = repository
    }

    static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dateString: String { Self.dateString(for: selectedDate) }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    func load() async {
        requestGeneration += 1
        await loadDay(selectedDate, forceRefresh: false, generation: requestGeneration)
    }

    func refresh() async {
        requestGeneration += 1
        await loadDay(selectedDate, forceRefresh: true, generation: requestGeneration)
    }

    func selectDate(_ date: Date) {
        let normalized = Calendar.current.startOfDay(for: date)
        loadTask?.cancel()

        selectedDate = normalized
        requestGeneration += 1
        let generation = requestGeneration
        errorMessage = nil
        os_signpost(.event, log: signpostLog, name: "TimetableInput", "%{public}s", dateString)

        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadDay(normalized, forceRefresh: false, generation: generation)
        }
    }

    func goToPreviousDay() {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectDate(date)
    }

    func goToNextDay() {
        guard let date = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectDate(date)
    }

    func goToToday() { selectDate(.now) }

    private func loadDay(_ requestedDate: Date, forceRefresh: Bool, generation: Int) async {
        let key = Self.dateString(for: requestedDate)
        defer {
            if generation == requestGeneration, isSelected(key) {
                isLoading = false
                isRefreshing = false
            }
        }

        let cached = await repository.cached(date: key)
        guard !Task.isCancelled, generation == requestGeneration else { return }

        if let cached {
            apply(cached.response, for: key)
            os_signpost(.event, log: signpostLog, name: "TimetableCacheHit", "%{public}s", key)
            if cached.isFresh && !forceRefresh {
                scheduleAdjacentPrefetch(around: requestedDate)
                return
            }
            isRefreshing = true
            isLoading = false
        } else if isSelected(key) {
            // Debounce cache misses so rapid next-next input never emits one
            // network request per intermediate date.
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled, generation == requestGeneration, isSelected(key) else { return }
            // Never show the previous date's lessons under the new date header.
            lessons = []
            isLoading = true
            isRefreshing = false
        }

        os_signpost(.begin, log: signpostLog, name: "TimetableRequest", "%{public}s", key)
        do {
            let response = try await repository.load(
                date: key,
                policy: forceRefresh ? .reload : .cacheFirst
            )
            guard !Task.isCancelled, generation == requestGeneration, isSelected(key) else {
                os_signpost(.end, log: signpostLog, name: "TimetableRequest", "stale")
                return
            }
            apply(response, for: key)
            errorMessage = nil
            scheduleAdjacentPrefetch(around: requestedDate)
            os_signpost(.end, log: signpostLog, name: "TimetableRequest", "applied")
        } catch is CancellationError {
            os_signpost(.end, log: signpostLog, name: "TimetableRequest", "cancelled")
        } catch let error as URLError where error.code == .cancelled {
            os_signpost(.end, log: signpostLog, name: "TimetableRequest", "cancelled")
        } catch {
            guard generation == requestGeneration, isSelected(key) else { return }
            if cached == nil {
                lessons = []
                errorMessage = "Could not load your timetable."
            } else {
                errorMessage = "Showing saved timetable. Could not refresh it."
            }
            os_signpost(.end, log: signpostLog, name: "TimetableRequest", "failed")
        }

    }

    private func apply(_ response: TimetableResponse, for key: String) {
        guard isSelected(key) else { return }
        lessons = response.lessons.sorted { $0.startsAt < $1.startsAt }
        isLoading = false
        isRefreshing = false
    }

    private func scheduleAdjacentPrefetch(around date: Date) {
        prefetchTask?.cancel()
        let repository = self.repository
        let dates = [-1, 1].compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: date)
        }.map(Self.dateString(for:))

        prefetchTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            for key in dates {
                guard !Task.isCancelled else { return }
                _ = try? await repository.load(date: key, policy: .cacheFirst)
            }
        }
    }

    private func isSelected(_ key: String) -> Bool { dateString == key }

    private static func dateString(for date: Date) -> String {
        apiDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
