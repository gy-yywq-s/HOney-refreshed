//
//  HomeView.swift
//  HOney — Home: welcome, Next Lesson, Experiences area, School Portal row.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: HomeViewModel?
    @State private var showPortal = false
    @State private var showSettings = false
    @State private var composeStandalone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    welcomeHeader
                    nextLessonCard
                    experiencesArea
                    portalRow
                }
                .padding(Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { HOneyWordmark(size: 22) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .task {
                if viewModel == nil { viewModel = HomeViewModel(services: model.services) }
                await viewModel?.load()
            }
            .refreshable { await viewModel?.load() }
            .sheet(isPresented: $showPortal) {
                PortalWebScreen(
                    portalURL: model.services.config.portalWebURL,
                    coordinator: model.services.portalCoordinator
                )
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $composeStandalone) {
                ComposeExperienceView(context: .standalone)
                    .environment(model)
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(greeting)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(model.profile?.displayName ?? "Welcome")
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    private var nextLessonCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Next lesson")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let lesson = viewModel?.nextLesson {
                    Text(lesson.subjectName)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    HStack(spacing: Theme.Spacing.sm) {
                        Label(viewModel?.nextLessonSummary ?? "", systemImage: "clock")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.accent)
                        if let room = lesson.roomName {
                            Text("· \(room)")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    if let teacher = lesson.teacherName {
                        Text(teacher)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                } else {
                    Text(viewModel?.nextLessonSummary.isEmpty == false
                         ? viewModel!.nextLessonSummary
                         : "No more lessons today")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        }
    }

    private var experiencesArea: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Experiences")
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    composeStandalone = true
                } label: {
                    Label("Share", systemImage: "square.and.pencil")
                }
                .buttonStyle(HOneyPrimaryButtonStyle())

                NavigationLink {
                    ExperiencesView()
                } label: {
                    Text("Browse")
                }
                .buttonStyle(HOneySecondaryButtonStyle())
            }

            if let recents = viewModel?.recentExperiences, !recents.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Recent from your classes")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        ForEach(recents) { experience in
                            ExperienceRow(experience: experience)
                            if experience.id != recents.last?.id {
                                Divider().overlay(Theme.Palette.line)
                            }
                        }
                    }
                }
            }
        }
    }

    private var portalRow: some View {
        Button {
            showPortal = true
        } label: {
            Card(padding: Theme.Spacing.md) {
                ListRow(
                    title: "School Portal",
                    subtitle: "Open OASIS in a secure in-app browser",
                    systemImage: "globe",
                    showsChevron: true
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
