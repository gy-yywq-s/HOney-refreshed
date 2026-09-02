// Timetable state (spec §18): Day first after cold launch, Week kept for
// the scene session, one date, cached day/week reads through the
// repository, adjacent prefetch, and the explicit school sync — separate
// from ordinary refresh.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class TimetableViewModel {
    enum SyncFeedback: Equatable {
        case synced(Int)
        case reconnectRequired
        case failed(String)
    }

    private let env: AppEnvironment
    private(set) var date: String
    var view: TimetableViewMode = .day

    private(set) var day: TimetableResponse?
    private(set) var dayLoading = true
    private(set) var dayError: String?
    /// True once this date's lessons are on screen for the first time (landing).
    private(set) var landedDates: Set<String> = []

    private(set) var weekDays: [String: [Lesson]]?
    private(set) var weekLoading = false
    private(set) var weekError: String?

    var selectedLesson: Lesson?
    private(set) var syncBusy = false
    var syncFeedback: SyncFeedback?
    private var generation = 0

    init(env: AppEnvironment, date: String = Formatters.todayIsoDate()) {
        self.env = env
        self.date = date
    }

    var monday: String { Formatters.mondayOf(date) }
    var isToday: Bool { date == Formatters.todayIsoDate() }
    var isThisWeek: Bool { monday == Formatters.mondayOf(Formatters.todayIsoDate()) }

    func setDate(_ iso: String) {
        guard Formatters.isValidIsoDate(iso), iso != date else { return }
        date = iso
        Task { await load() }
    }

    func step(_ direction: Int) {
        setDate(Formatters.shiftIsoDate(date, days: direction * (view == .week ? 7 : 1)))
    }

    func goToday() { setDate(Formatters.todayIsoDate()) }

    func load(reload: Bool = false) async {
        generation += 1
        let gen = generation
        if view == .week {
            await loadWeek(reload: reload, generation: gen)
        } else {
            await loadDay(reload: reload, generation: gen)
        }
    }

    private func loadDay(reload: Bool, generation gen: Int) async {
        let target = date
        if !reload, let cached = await env.timetable.cachedDay(target) {
            day = cached
            dayLoading = false
        } else if day?.date != target {
            dayLoading = true
        }
        do {
            let response = try await env.timetable.day(target, reload: reload)
            guard gen == generation else { return }
            day = response
            dayError = nil
        } catch {
            guard gen == generation else { return }
            if day?.date != target { day = nil; dayError = APIErrorCopy.describe(error) }
        }
        dayLoading = false
        // Adjacent days, quietly.
        let repo = env.timetable
        Task.detached(priority: .utility) {
            _ = try? await repo.day(Formatters.shiftIsoDate(target, days: 1))
            _ = try? await repo.day(Formatters.shiftIsoDate(target, days: -1))
        }
    }

    private func loadWeek(reload: Bool, generation gen: Int) async {
        let target = monday
        if !reload, let cached = await env.timetable.cachedWeek(target) {
            weekDays = Dictionary(uniqueKeysWithValues: cached.days.map { ($0.date, $0.lessons) })
            weekLoading = false
        } else {
            weekLoading = true
        }
        do {
            let response = try await env.timetable.week(monday: target, reload: reload)
            guard gen == generation else { return }
            weekDays = Dictionary(uniqueKeysWithValues: response.days.map { ($0.date, $0.lessons) })
            weekError = nil
        } catch {
            guard gen == generation else { return }
            if weekDays == nil { weekError = APIErrorCopy.describe(error) }
        }
        weekLoading = false
    }

    func markLanded(_ iso: String) { landedDates.insert(iso) }

    /// Upstream school sync — explicit, never a pull stage (spec §24).
    func syncWithSchool() async {
        guard !syncBusy else { return }
        syncBusy = true
        syncFeedback = nil
        do {
            let (result, _) = try await env.syncWithSchool()
            switch result.status {
            case .ok:
                syncFeedback = .synced(result.lessons)
                await load(reload: true)
            case .portalReconnectRequired:
                syncFeedback = .reconnectRequired
            default:
                syncFeedback = .failed("Could not sync right now.")
            }
        } catch {
            syncFeedback = .failed(APIErrorCopy.describe(error))
        }
        syncBusy = false
    }
}
