//
//  MainTabView.swift
//  HOney — primary tabs. School Portal is NOT a tab (it lives on Home).
//  Flat legacy tab shell: each tab draws over the shared gradient.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            ExperiencesView()
                .tabItem { Label("Experiences", systemImage: "bubble.left.and.bubble.right") }

            TimetableView()
                .tabItem { Label("Timetable", systemImage: "calendar") }

            AccessView()
                .tabItem { Label("Access", systemImage: "key.card") }
        }
        .tint(Palette.ocean)
    }
}
