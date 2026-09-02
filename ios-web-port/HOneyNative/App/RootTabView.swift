// The native tab bar (spec §6.3): Home · Experiences · Timetable · Access ·
// Settings, simple line symbols, accent tint, labels visible. Every tab
// owns an independent NavigationStack; switching tabs preserves each.

import SwiftUI
import HOneyCore

struct RootTabView: View {
    @Environment(Navigator.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.selected) {
            tab(.home) { HomeView() }
            tab(.experiences) { ExperiencesFeedView() }
            tab(.timetable) { TimetableRootView() }
            tab(.access) { AccessView() }
            tab(.settings) { SettingsRootView() }
        }
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: nav.path(for: tab)) {
            root()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                }
        }
        .tabItem { Label(tab.title, systemImage: tab.symbol) }
        .tag(tab)
    }
}

/// One place that turns a route into a screen, for every stack.
struct RouteView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .home:
            HomeView()
        case .timetable:
            TimetableRootView()
        case .history(let select):
            HistoryView(selectMode: select)
        case .experiences:
            ExperiencesFeedView()
        case .explore:
            ExploreView()
        case .why:
            WhyView()
        case .mine:
            NotesAndPostsView()
        case .compose(let target):
            if let target {
                ComposerView(target: target)
            } else {
                TargetPickerView()
            }
        case .entity(let type, let id):
            EntityExperiencesView(type: type, id: id)
        case .settings:
            SettingsRootView()
        case .settingsConnection:
            SchoolConnectionView()
        case .settingsPrivacy:
            HowAnonymityWorksView()
        case .settingsAccount:
            AccountView()
        case .settingsAppearance:
            AppearanceView()
        }
    }
}
