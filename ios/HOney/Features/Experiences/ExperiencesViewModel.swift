//
//  ExperiencesViewModel.swift
//  HOney — browse feed state (Band 1).
//

import Foundation
import Observation

@MainActor
@Observable
final class ExperiencesViewModel {
    private let services: AppServices

    var experiences: [Experience] = []
    var teachers: [DirectoryEntry] = []
    var courses: [DirectoryEntry] = []

    var query = ""
    var sort: ExperienceSort = .newest
    var selectedTeacherId: String?
    var selectedCourseId: String?

    var isLoading = false
    var errorMessage: String?

    init(services: AppServices) {
        self.services = services
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
            let response = try await services.honeyAPI.experiences(
                teacherId: selectedTeacherId,
                courseId: selectedCourseId,
                query: query,
                sort: sort
            )
            experiences = rawFirst(response.experiences)
        } catch {
            errorMessage = "Could not load experiences."
        }
    }

    func react(_ experience: Experience, value: Int) async {
        try? await services.honeyAPI.react(experienceId: experience.id, value: value)
    }

    func report(_ experience: Experience, category: String, note: String) async {
        try? await services.honeyAPI.report(experienceId: experience.id, category: category, note: note)
    }

    /// Raw provenance is surfaced first, preserving the server's per-group order.
    private func rawFirst(_ items: [Experience]) -> [Experience] {
        let raw = items.filter { $0.provenance?.lowercased() == "raw" }
        let rest = items.filter { $0.provenance?.lowercased() != "raw" }
        return raw + rest
    }
}
