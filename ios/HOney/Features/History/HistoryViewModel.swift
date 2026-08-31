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

    var lessons: [Lesson] = []
    var teachers: [DirectoryEntry] = []
    var courses: [DirectoryEntry] = []

    var query = ""
    var selectedTeacherId: String?
    var selectedCourseId: String?
    var order: String = "desc"

    var isLoading = false
    var errorMessage: String?

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

    func loadFilters() async {
        if let directory = try? await services.honeyAPI.directory() {
            teachers = directory.teachers
            courses = directory.courses
        }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await services.honeyAPI.history(
                query: query,
                teacherId: selectedTeacherId,
                courseId: selectedCourseId,
                order: order
            )
            lessons = response.lessons
        } catch {
            errorMessage = "Could not load history."
        }
    }
}
