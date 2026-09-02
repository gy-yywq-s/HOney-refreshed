// The shell (fidelity spec v2 §5): Home · Experiences · Timetable · Access ·
// Settings. Every tab owns an independent NavigationStack; switching tabs
// preserves each. The system tab bar is hidden and the Web's floating
// five-slot bar (TabBarView.swift) sits in the bottom safe-area inset.

import SwiftUI
import HOneyCore

struct RootTabView: View {
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.selected) {
            tab(.home) { HomeView() }
            tab(.experiences) { ExperiencesFeedView() }
            tab(.timetable) { TimetableRootView() }
            tab(.access) { AccessView() }
            tab(.settings) { SettingsRootView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HOneyTabBar(selected: $nav.selected)
        }
        .background(theme.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: nav.path(for: tab)) {
            root()
                .toolbar(.hidden, for: .tabBar)
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                        .toolbar(.hidden, for: .tabBar)
                }
        }
        .toolbar(.hidden, for: .tabBar)
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
