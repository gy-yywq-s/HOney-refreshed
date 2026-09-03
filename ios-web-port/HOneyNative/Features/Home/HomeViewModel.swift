// Home's data (spec §3.4 HomeRepository, §10.8): next lesson, 1–3
// previews from the student's classes, Portal entry prewarm — three
// independent regions; a failure in one never blanks the others.
//
// v2: the previews come from Community for the viewer's canonical exposure
// (no identity crosses); names are joined from Core's directory here.

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

    private(set) var previews: [PublicExperienceV2] = []
    private(set) var previewsLoading = true
    private(set) var previewsError: String?
    private(set) var names = NameMaps()

    init(env: AppEnvironment) {
        self.env = env
    }

    var name: NameResolver { names.resolver }

    func load(reload: Bool = false) async {
        async let lesson: Void = loadLesson(reload: reload)
        async let voices: Void = loadPreviews(reload: reload)
        async let portal: Void = prewarmPortal()
        _ = await (lesson, voices, portal)
    }

    private func prewarmPortal() async {
        await env.portal.prewarm()
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

    private func loadPreviews(reload: Bool) async {
        do {
            if !names.loaded || reload, let maps = try? await NameMaps.load(env, reload: reload) { names = maps }
            let exposure = try await env.publish.exposure()
            let response = try await env.community.fromMyClasses(FromMyClassesRequestV2(exposure: exposure, limit: 10))
            previews = response.experiences.filter { ($0.body ?? "").isEmpty == false }
            previewsError = nil
        } catch {
            if previews.isEmpty { previewsError = APIErrorCopy.describe(error) }
        }
        previewsLoading = false
    }
}
