//
//  HomeViewModel.swift
//  HOney — Home screen state (Band 1).
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let services: AppServices
    private var loadGeneration = 0

    var nextLesson: NextLesson?
    var recentExperiences: [PublicExperience] = []
    var isLoadingLesson = false
    var isLoadingExperiences = false
    var errorMessage: String?
    var targetNames: [String: String] = [:]
    var nextLessonAvailable = true
    var recentExperiencesAvailable = true

    init(services: AppServices) {
        self.services = services
    }

    var isLoading: Bool { isLoadingLesson || isLoadingExperiences }

    func load(forceRefresh: Bool = false) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoadingLesson = true
        isLoadingExperiences = true
        errorMessage = nil

        async let recent = try? services.experienceFeedRepository.load(
            .myClasses,
            policy: forceRefresh ? .reload : .cacheFirst
        )

        // Do not hold the primary school-day answer behind the secondary feed.
        let nextResult = try? await services.nextLessonRepository.load(
            forceRefresh ? .reload : .cacheFirst
        )
        guard generation == loadGeneration else { return }
        if let nextResult {
            nextLesson = nextResult.nextLesson
        }
        nextLessonAvailable = nextResult != nil
        isLoadingLesson = false

        let recentResult = await recent
        guard generation == loadGeneration else { return }
        if let recentResult {
            recentExperiences = Array(recentResult.experiences.prefix(2))
        }
        recentExperiencesAvailable = recentResult != nil
        isLoadingExperiences = false

        if nextResult == nil && recentResult == nil {
            errorMessage = "Home could not update. Use Refresh Home to try again."
        } else if nextResult == nil || recentResult == nil {
            errorMessage = "Some Home information is temporarily unavailable."
        }
        // Target names are secondary metadata. The app-scoped repository
        // coalesces this with Experiences/My Posts instead of refetching.
        let names = await services.experienceTargetRepository.load().names
        guard generation == loadGeneration else { return }
        targetNames = names
    }

    func targetLabel(for experience: PublicExperience) -> String {
        ExperienceTargetNaming.label(for: experience, names: targetNames)
    }
}
