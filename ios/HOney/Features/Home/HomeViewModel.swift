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

    init(services: AppServices) {
        self.services = services
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let next = try? services.honeyAPI.nextLesson()
        // "Recent from your classes" is the backend domain query (audit §4.2):
        // posts relevant to my verified exposure, chronological, never ranked.
        async let recent = try? services.honeyAPI.fromMyClasses(limit: 20)

        let nextResult = await next
        nextLesson = nextResult?.nextLesson
        nextLessonSummary = NextLessonPresentation.summary(for: nextLesson)

        recentExperiences = Array((await recent)?.experiences.prefix(3) ?? [])
    }
}
