// Home's data (spec §3.4 HomeRepository, §10.8): next lesson, 1–3
// previews from the student's classes, Portal entry prewarm — three
// independent regions; a failure in one never blanks the others.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class HomeViewModel {
    private let env: AppEnvironment

    private(set) var nextLesson: NextLessonResponse?
    private(set) var lessonLoading = true
    private(set) var lessonError: String?

    private(set) var previews: [PublicExperience] = []
    private(set) var previewsLoading = true
    private(set) var previewsError: String?

    init(env: AppEnvironment) {
        self.env = env
    }

    func load(reload: Bool = false) async {
        async let lesson: Void = loadLesson(reload: reload)
        async let voices: Void = loadPreviews()
        async let portal: Void = env.portal.prewarm()
        _ = await (lesson, voices, portal)
    }

    private func loadLesson(reload: Bool) async {
        if !reload, let cached = await env.timetable.cachedNextLesson() {
            nextLesson = cached
            lessonLoading = false
        }
        do {
            nextLesson = try await env.timetable.next(reload: true)
            lessonError = nil
        } catch {
            if nextLesson == nil { lessonError = APIErrorCopy.describe(error) }
        }
        lessonLoading = false
    }

    private func loadPreviews() async {
        do {
            let response = try await env.api.fromMyClasses(limit: 10)
            previews = response.experiences.filter { ($0.body ?? "").isEmpty == false }
            previewsError = nil
        } catch {
            if previews.isEmpty { previewsError = APIErrorCopy.describe(error) }
        }
        previewsLoading = false
    }
}
