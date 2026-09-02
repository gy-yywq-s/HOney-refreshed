// Timetable state (spec §18): Day first after cold launch, Week kept while
// the app lives, one date, cached day/week reads through the repository,
// adjacent prefetch, and the explicit school sync — separate from ordinary
// refresh.
//
// Keyed snapshots (review 11d42e3 §3.4): what is on screen is always the
// data for the selected date/week or a placeholder — never the previous
// day's lessons under a new header. One load path: `setDate`/`setView`
// schedule the load; callers never double-load.

import Foundation
import Observation
import HOneyCore

struct DaySnapshot: Equatable {
    let date: String
    let response: TimetableResponse
}

struct WeekSnapshot: Equatable {
    let monday: String
    let response: TimetableRangeResponse

    var days: [String: [Lesson]] {
        Dictionary(uniqueKeysWithValues: response.days.map { ($0.date, $0.lessons) })
    }
}

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
    private(set) var view: TimetableViewMode = .day

    private var daySnapshot: DaySnapshot?
    private var weekSnapshot: WeekSnapshot?
    private(set) var dayError: String?
    private(set) var weekError: String?
    private(set) var loading = false
    /// Dates whose cold landing scroll completed.
    private(set) var landedDates: Set<String> = []

    var selectedLesson: Lesson?
    private(set) var syncBusy = false
    var syncFeedback: SyncFeedback?
    private var loadTask: Task<Void, Never>?
    private var generation = 0

    init(env: AppEnvironment, date: String = Formatters.todayIsoDate()) {
        self.env = env
        self.date = date
    }

    var monday: String { Formatters.mondayOf(date) }
    var isToday: Bool { date == Formatters.todayIsoDate() }
    var isThisWeek: Bool { monday == Formatters.mondayOf(Formatters.todayIsoDate()) }

    /// The day on screen — only when it is the selected date's.
    var day: TimetableResponse? {
        guard let daySnapshot, daySnapshot.date == date else { return nil }
        return daySnapshot.response
    }

    /// The week on screen — only when it is the selected week's.
    var weekDays: [String: [Lesson]]? {
        guard let weekSnapshot, weekSnapshot.monday == monday else { return nil }
        return weekSnapshot.days
    }

    func setDate(_ iso: String) {
        guard Formatters.isValidIsoDate(iso), iso != date else { return }
        date = iso
        dayError = nil
        weekError = nil
        scheduleLoad()
    }

    func setView(_ mode: TimetableViewMode) {
        guard mode != view else { return }
        view = mode
        scheduleLoad()
    }

    func step(_ direction: Int) {
        setDate(Formatters.shiftIsoDate(date, days: direction * (view == .week ? 7 : 1)))
    }

    func goToday() { setDate(Formatters.todayIsoDate()) }

    /// First appearance and pull-to-refresh.
    func load(reload: Bool = false) async {
        loadTask?.cancel()
        let task = Task { await perform(reload: reload) }
        loadTask = task
        await task.value
    }

    private func scheduleLoad() {
        loadTask?.cancel()
        loadTask = Task { await perform(reload: false) }
    }

    private func perform(reload: Bool) async {
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
            daySnapshot = DaySnapshot(date: target, response: cached)
        }
        loading = day == nil
        do {
            let response = try await env.timetable.day(target, reload: reload)
            guard gen == generation, !Task.isCancelled else { return }
            daySnapshot = DaySnapshot(date: target, response: response)
            dayError = nil
        } catch is CancellationError {
            return
        } catch {
            guard gen == generation else { return }
            if day == nil { dayError = APIErrorCopy.describe(error) }
        }
        loading = false
        // Adjacent days, quietly, through the same coalescing cache.
        let repo = env.timetable
        Task.detached(priority: .utility) {
            _ = try? await repo.day(Formatters.shiftIsoDate(target, days: 1))
            _ = try? await repo.day(Formatters.shiftIsoDate(target, days: -1))
        }
    }

    private func loadWeek(reload: Bool, generation gen: Int) async {
        let target = monday
        if !reload, let cached = await env.timetable.cachedWeek(target) {
            weekSnapshot = WeekSnapshot(monday: target, response: cached)
        }
        loading = weekDays == nil
        do {
            let response = try await env.timetable.week(monday: target, reload: reload)
            guard gen == generation, !Task.isCancelled else { return }
            weekSnapshot = WeekSnapshot(monday: target, response: response)
            weekError = nil
        } catch is CancellationError {
            return
        } catch {
            guard gen == generation else { return }
            if weekDays == nil { weekError = APIErrorCopy.describe(error) }
        }
        loading = false
    }

    /// Called by the Day screen once the landing scroll actually happened.
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
                daySnapshot = nil
                weekSnapshot = nil
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
