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
    var recentExperiences: [Experience] = []
    var isLoading = false

    init(services: AppServices) {
        self.services = services
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let next = try? services.honeyAPI.nextLesson()
        async let recent = try? services.honeyAPI.experiences(sort: .newest)

        let nextResult = await next
        nextLesson = nextResult?.nextLesson
        nextLessonSummary = NextLessonPresentation.summary(for: nextLesson)

        recentExperiences = Array((await recent)?.experiences.prefix(3) ?? [])
    }
}
