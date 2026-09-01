//
//  MainTabView.swift
//  HOney — four direct student tasks with cross-tab navigation owned here.
//

import SwiftUI

private enum AppTab: Hashable {
    case home
    case experiences
    case timetable
    case access
}

struct MainTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(
                openExperiences: { selection = .experiences },
                openAccess: { selection = .access }
            )
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            ExperiencesView()
                .tabItem { Label("Experiences", systemImage: "text.bubble") }
                .tag(AppTab.experiences)

            TimetableView()
                .tabItem { Label("Timetable", systemImage: "calendar") }
                .tag(AppTab.timetable)

            AccessView()
                .tabItem { Label("Access", systemImage: "door.left.hand.open") }
                .tag(AppTab.access)
        }
        .tint(Palette.accent)
    }
}
