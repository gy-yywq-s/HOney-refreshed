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

    var nextLesson: NextLesson?
    var nextLessonSummary: String = ""
    var recentExperiences: [PublicExperience] = []
    var isLoading = false
    var errorMessage: String?
    var nextLessonAvailable = true
    var recentExperiencesAvailable = true

    init(services: AppServices) {
        self.services = services
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let next = try? services.honeyAPI.nextLesson()
        // "Recent from your classes" is the backend domain query (audit §4.2):
        // posts relevant to my verified exposure, chronological, never ranked.
        async let recent = try? services.honeyAPI.fromMyClasses(limit: 20)

        let nextResult = await next
        let recentResult = await recent
        nextLesson = nextResult?.nextLesson
        nextLessonAvailable = nextResult != nil
        nextLessonSummary = NextLessonPresentation.summary(for: nextLesson)
        recentExperiences = Array(recentResult?.experiences.prefix(3) ?? [])
        recentExperiencesAvailable = recentResult != nil

        if nextResult == nil && recentResult == nil {
            errorMessage = "Home could not update. Pull to try again."
        } else if nextResult == nil || recentResult == nil {
            errorMessage = "Some Home information is temporarily unavailable."
        }
    }
}
