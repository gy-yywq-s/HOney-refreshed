//
//  MainTabView.swift
//  HOney — primary tabs. School Portal is NOT a tab (it lives on Home).
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
    }
}
