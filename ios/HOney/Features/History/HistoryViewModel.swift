//
//  HistoryViewModel.swift
//  HOney — course history state (Band 1). Shared by browse + selection modes.
//

import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    private let services: AppServices
    private var loadGeneration = 0

    var lessons: [Lesson] = []
    var teachers: [DirectoryEntry] = []
    var courses: [DirectoryEntry] = []

    var query = ""
    var selectedTeacherId: String?
    var selectedCourseId: String?
    var order: String = "desc"

    var isLoading = false
    var errorMessage: String?
    var filterErrorMessage: String?

    init(services: AppServices) {
        self.services = services
    }

    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM"; return f
    }()
    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    struct MonthGroup: Identifiable {
        let id: String
        let label: String
        let lessons: [Lesson]
    }

    /// Lessons grouped by month, newest month first.
    var groupedByMonth: [MonthGroup] {
        let groups = Dictionary(grouping: lessons) { Self.monthKeyFormatter.string(from: $0.startsAt) }
        return groups.keys.sorted(by: >).map { key in
            let items = (groups[key] ?? []).sorted { $0.startsAt > $1.startsAt }
            let label = items.first.map { Self.monthLabelFormatter.string(from: $0.startsAt) } ?? key
            return MonthGroup(id: key, label: label, lessons: items)
        }
    }

    func loadFilters(forceRefresh: Bool = false) async {
        filterErrorMessage = nil
        if forceRefresh { await services.experienceTargetRepository.invalidate() }
        let metadata = await services.experienceTargetRepository.load()
        guard let directory = metadata.directory else {
            filterErrorMessage = "Teacher and course choices could not be loaded."
            return
        }
        teachers = directory.teachers
        courses = directory.courses
    }

    func reload(forceRefresh: Bool = false) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        do {
            let key = HistoryCacheKey(
                query: query,
                teacherId: selectedTeacherId,
                courseId: selectedCourseId,
                order: order
            )
            let response = try await services.historyRepository.load(
                key: key,
                policy: forceRefresh ? .reload : .cacheFirst
            )
            guard generation == loadGeneration else { return }
            lessons = response.lessons
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = lessons.isEmpty
                ? "Could not load past lessons."
                : "Past lessons remain visible, but they could not be refreshed."
        }
        if generation == loadGeneration { isLoading = false }
    }
}
