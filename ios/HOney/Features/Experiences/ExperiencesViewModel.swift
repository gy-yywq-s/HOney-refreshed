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
    private var feedGeneration = 0

    var experiences: [PublicExperience] = []
    var teachers: [DirectoryEntry] = []
    var courses: [DirectoryEntry] = []
    var entities: [EntityRef] = []
    var targetNames: [String: String] = [:]
    var isLoadingTargets = false
    var directoryAvailable = false
    var entitiesAvailable = false
    var targetLoadMessage: String?

    var scope: ExperienceFeedScope = .myClasses

    var isLoading = false
    var errorMessage: String?

    var showingFromMyClasses: Bool { scope == .myClasses }

    init(services: AppServices) {
        self.services = services
    }

    func loadFilters() async {
        isLoadingTargets = true
        targetLoadMessage = nil
        defer { isLoadingTargets = false }
        let metadata = await services.experienceTargetRepository.load()
        directoryAvailable = metadata.directoryRequestSucceeded
        entitiesAvailable = metadata.entitiesRequestSucceeded
        if let directory = metadata.directory {
            teachers = directory.teachers
            courses = directory.courses
        }
        entities = metadata.entities
        targetNames = metadata.names
        if !directoryAvailable && !entitiesAvailable {
            targetLoadMessage = "Choices could not be loaded. Nothing is being shown as an empty complete list."
        } else if !metadata.isComplete {
            targetLoadMessage = "Some choices could not be loaded. The available sections below may be incomplete."
        }
    }

    func retryFilters() async {
        await services.experienceTargetRepository.invalidate()
        await loadFilters()
    }

    func targetLabel(for experience: PublicExperience) -> String {
        ExperienceTargetNaming.label(for: experience, names: targetNames)
    }

    func reload(forceRefresh: Bool = false) async {
        feedGeneration += 1
        let generation = feedGeneration
        let requestedScope = scope
        isLoading = true
        errorMessage = nil
        do {
            let response = try await services.experienceFeedRepository.load(
                requestedScope,
                policy: forceRefresh ? .reload : .cacheFirst
            )
            guard generation == feedGeneration, scope == requestedScope else { return }
            experiences = response.experiences
        } catch {
            guard generation == feedGeneration, scope == requestedScope else { return }
            errorMessage = showingFromMyClasses
                ? "Could not load experiences from your classes."
                : "Could not load experiences from around school."
        }
        if generation == feedGeneration { isLoading = false }
    }
}
