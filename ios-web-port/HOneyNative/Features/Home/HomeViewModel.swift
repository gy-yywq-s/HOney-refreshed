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

    /// What the school published (Web: Home "From school"); a failure here
    /// simply leaves the zone out — Home never blanks for a notice.
    private(set) var notices: [SchoolNotice] = []
    private(set) var portalOrigin = ""
    /// Bumped when this device reads a notice, so the rows re-render.
    private(set) var readVersion = 0

    /// Re-entering Home within the window shows what is already there
    /// instead of reloading it (Gary 2026-09-04); pull to refresh and any
    /// explicit reload ignore the gate.
    private let gate = LoadGate(maxAge: 90)

    init(env: AppEnvironment) {
        self.env = env
    }

    var name: NameResolver { names.resolver }

    func load(reload: Bool = false) async {
        if !reload, gate.isFresh, nextLesson != nil { return }
        gate.markLoaded()
        async let lesson: Void = loadLesson(reload: reload)
        async let voices: Void = loadPreviews(reload: reload)
        async let school: Void = loadNotices()
        async let portal: Void = prewarmPortal()
        _ = await (lesson, voices, school, portal)
    }

    /// The unread ones, newest first — at most two, a glimpse and not a feed.
    /// With nothing unread the newest notice still shows, quietly, so Home
    /// never hides that the school has said something.
    var homeNotices: [SchoolNotice] {
        _ = readVersion
        let read = env.prefs.readNotices()
        let unread = notices.filter { !read.contains($0.id) }
        return unread.isEmpty ? Array(notices.prefix(1)) : Array(unread.prefix(2))
    }

    func isUnread(_ notice: SchoolNotice) -> Bool {
        _ = readVersion
        return !env.prefs.readNotices().contains(notice.id)
    }

    func markRead(_ notice: SchoolNotice) {
        env.prefs.markNoticesRead([notice.id])
        readVersion += 1
    }

    func isMine(_ exp: PublicExperienceV2) -> Bool { env.prefs.isMyPost(exp.id) }

    private func loadNotices() async {
        guard let response = try? await env.api.notices(limit: 20) else { return }
        notices = response.notices
        portalOrigin = response.portalOrigin
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
