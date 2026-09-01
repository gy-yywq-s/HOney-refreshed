//
//  ExperiencesViewModel.swift
//  HOney — feed-first community state (Band 1).
//
//  The default is the backend "from your classes" domain query. Around school
//  is a separate chronological scope. Intentional teacher/course/entity lookup
//  lives in Explore and never blocks the feed behind controls.
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
    var entities: [EntityRef] = []
    var targetNames: [String: String] = [:]

    var scope: ExperienceFeedScope = .myClasses

    var isLoading = false
    var errorMessage: String?

    var showingFromMyClasses: Bool { scope == .myClasses }

    init(services: AppServices) {
        self.services = services
    }

    func loadFilters() async {
        let metadata = await services.experienceTargetRepository.load()
        if let directory = metadata.directory {
            teachers = directory.teachers
            courses = directory.courses
        }
        entities = metadata.entities
        targetNames = metadata.names
    }

    func targetLabel(for experience: PublicExperience) -> String {
        ExperienceTargetNaming.label(for: experience, names: targetNames)
    }

    func reload(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await services.experienceFeedRepository.load(
                scope,
                policy: forceRefresh ? .reload : .cacheFirst
            )
            experiences = response.experiences
        } catch {
            errorMessage = showingFromMyClasses
                ? "Could not load experiences from your classes."
                : "Could not load experiences from around school."
        }
    }
}
