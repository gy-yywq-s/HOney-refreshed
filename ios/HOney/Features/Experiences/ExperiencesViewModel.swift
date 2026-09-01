//
//  ExperiencesViewModel.swift
//  HOney — browse feed state (Band 1).
//
//  Feed semantics mirror the web hub: the default surface is the backend
//  "from your classes" domain query — chronological, never ranked — and the
//  filtered browse preserves the server's order exactly (no client-side
//  reordering; the old raw-first sort predates the provenance contract).
//

import Foundation
import Observation

@MainActor
@Observable
final class ExperiencesViewModel {
    private let services: AppServices

    var experiences: [PublicExperience] = []
    var teachers: [DirectoryEntry] = []
    var courses: [DirectoryEntry] = []
    var targetNames: [String: String] = [:]

    var query = ""
    var sort: ExperienceSort = .newest
    var selectedTeacherId: String?
    var selectedCourseId: String?

    var isLoading = false
    var errorMessage: String?

    /// True while no filter is active and the list is the "from your classes"
    /// domain feed (audit §4.2) rather than a filtered browse.
    private(set) var showingFromMyClasses = false

    init(services: AppServices) {
        self.services = services
    }

    var hasActiveFilters: Bool {
        selectedTeacherId != nil || selectedCourseId != nil
            || !query.trimmingCharacters(in: .whitespaces).isEmpty
            || sort != .newest
    }

    func loadFilters() async {
        let metadata = await services.experienceTargetRepository.load()
        if let directory = metadata.directory {
            teachers = directory.teachers
            courses = directory.courses
        }
        targetNames = metadata.names
    }

    func targetLabel(for experience: PublicExperience) -> String {
        ExperienceTargetNaming.label(for: experience, names: targetNames)
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if hasActiveFilters {
                // Filtered browse: the server's order is kept as-is.
                let response = try await services.honeyAPI.experiences(
                    teacherId: selectedTeacherId,
                    courseId: selectedCourseId,
                    query: query,
                    sort: sort
                )
                experiences = response.experiences
                showingFromMyClasses = false
            } else {
                // Default surface: experiences involving my own teachers and
                // courses, newest first — chronological, never ranked.
                let response = try await services.honeyAPI.fromMyClasses(limit: 100)
                experiences = response.experiences
                showingFromMyClasses = true
            }
        } catch {
            errorMessage = "Could not load experiences."
        }
    }
}
