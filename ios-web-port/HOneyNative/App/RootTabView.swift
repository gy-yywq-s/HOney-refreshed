// The shell: Home · Experiences · Timetable · Access · Settings on the
// system tab bar (Gary 2026-09-02: navigation 用 iOS 原生的), themed through
// UITabBarAppearance to the chosen surface and accent. Every tab owns an
// independent NavigationStack; switching tabs preserves each.

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
        .tint(theme.accent)
        .background(theme.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func tab<Root: View>(_ tab: AppTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: nav.path(for: tab)) {
            root()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                }
        }
        .tabItem {
            Image(systemName: tab.symbol)
                .accessibilityLabel(tab.title)
        }
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
        case .settingsPostControls:
            PostControlsView()
        case .settingsRecoveryWords:
            RecoveryWordsView()
        case .settingsPairDevice:
            PairDeviceView()
        case .settingsReplaceRoot:
            ReplaceRootView()
        }
    }
}
