// Five stable destinations, each with its own NavigationStack (spec §6.2),
// and the honey:// deep-link router (§6.5). No manual route-stack array is
// recreated: SwiftUI owns each stack; this object only holds the paths and
// the selected tab so deep links and cross-tab jumps have one place to go.

import Foundation
import Observation
import SwiftUI
import HOneyCore

enum AppTab: String, CaseIterable, Identifiable {
    case home, experiences, timetable, access, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .experiences: return "Experiences"
        case .timetable: return "Timetable"
        case .access: return "Access"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .experiences: return "bubble.left"
        case .timetable: return "calendar"
        case .access: return "door.left.hand.open"
        case .settings: return "gearshape"
        }
    }
}

/// Where the Timetable tab should land when a deep link names a date/view.
struct TimetableIntent: Equatable {
    var date: String?
    var view: TimetableViewMode?
}

/// Where the Experiences stream should land: a scope and, if feasible,
/// the post a Home preview was tapped on (spec §10.5, review §4.8).
struct ExperiencesIntent: Equatable {
    var scope: FeedScope?
    var anchorId: String?
}

@MainActor
@Observable
final class Navigator {
    var selected: AppTab = .home
    var homePath: [AppRoute] = []
    var experiencesPath: [AppRoute] = []
    var timetablePath: [AppRoute] = []
    var accessPath: [AppRoute] = []
    var settingsPath: [AppRoute] = []
    /// Consumed by TimetableRootView when set.
    var timetableIntent: TimetableIntent?
    /// Consumed by ExperiencesFeedView when set.
    var experiencesIntent: ExperiencesIntent?

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { [self] in
                switch tab {
                case .home: return homePath
                case .experiences: return experiencesPath
                case .timetable: return timetablePath
                case .access: return accessPath
                case .settings: return settingsPath
                }
            },
            set: { [self] value in
                switch tab {
                case .home: homePath = value
                case .experiences: experiencesPath = value
                case .timetable: timetablePath = value
                case .access: accessPath = value
                case .settings: settingsPath = value
                }
            }
        )
    }

    /// Push onto the currently selected tab's stack.
    func push(_ route: AppRoute) {
        path(for: selected).wrappedValue.append(route)
    }

    func pop() {
        var p = path(for: selected).wrappedValue
        if !p.isEmpty { p.removeLast() }
        path(for: selected).wrappedValue = p
    }

    var currentPath: [AppRoute] { path(for: selected).wrappedValue }

    /// Jump to a tab and replace its stack (deep links, cross-tab actions).
    func go(_ tab: AppTab, _ routes: [AppRoute] = []) {
        selected = tab
        path(for: tab).wrappedValue = routes
    }

    func reset() {
        selected = .home
        homePath = []
        experiencesPath = []
        timetablePath = []
        accessPath = []
        settingsPath = []
        timetableIntent = nil
        experiencesIntent = nil
    }

    /// honey://… (spec §6.5) → tab + stack. Mirrors the Web paths.
    func open(_ url: URL) {
        guard url.scheme == "honey" else { return }
        let host = url.host ?? ""
        let segments = url.pathComponents.filter { $0 != "/" }
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        switch host {
        case "home":
            go(.home)
        case "timetable":
            let date = query["date"].flatMap { Formatters.isValidIsoDate($0) ? $0 : nil }
            let view = query["view"].flatMap { TimetableViewMode(rawValue: $0) }
            timetableIntent = TimetableIntent(date: date, view: view ?? (date != nil ? .day : nil))
            go(.timetable)
        case "history":
            go(.timetable, [.history(select: query["select"] == "1")])
        case "access":
            go(.access)
        case "experiences":
            switch segments.first {
            case nil: go(.experiences)
            case "explore": go(.experiences, [.explore])
            case "why": go(.experiences, [.why])
            case "mine": go(.experiences, [.mine])
            case "compose":
                if let lessonId = query["lessonId"] {
                    go(.experiences, [.compose(.lesson(id: lessonId, date: query["date"]))])
                } else if let entityKey = query["entityKey"] {
                    go(.experiences, [.compose(.entity(key: entityKey))])
                } else if let noteId = query["noteId"] {
                    go(.experiences, [.compose(.note(id: noteId))])
                } else {
                    go(.experiences, [.compose(nil)])
                }
            case "teacher", "course", "room", "dish", "place", "food":
                guard segments.count >= 2 else { go(.experiences); return }
                let kind = segments[0]
                let type: EntityType = kind == "place" ? .room : kind == "food" ? .dish : EntityType(rawValue: kind)
                go(.experiences, [.entity(type, segments[1])])
            default:
                go(.experiences)
            }
        case "settings":
            switch segments.first {
            case "connection": go(.settings, [.settingsConnection])
            case "privacy": go(.settings, [.settingsPrivacy])
            case "account": go(.settings, [.settingsAccount])
            case "appearance": go(.settings, [.settingsAppearance])
            case "post-controls":
                switch segments.dropFirst().first {
                case "recovery-words": go(.settings, [.settingsPostControls, .settingsRecoveryWords])
                case "pair": go(.settings, [.settingsPostControls, .settingsPairDevice])
                case "replace-root": go(.settings, [.settingsPostControls, .settingsReplaceRoot])
                default: go(.settings, [.settingsPostControls])
                }
            default: go(.settings)
            }
        default:
            break
        }
    }
}
