//
//  HomeView.swift
//  HOney — lesson-first Home with secondary Experiences and Access actions.
//

import SwiftUI

struct HomeView: View {
    let openExperiences: () -> Void
    let openAccess: () -> Void

    @Environment(AppModel.self) private var model
    @State private var viewModel: HomeViewModel?
    @State private var showPortal = false
    @State private var showSettings = false
    @State private var showLessonPicker = false
    @State private var pendingLesson: Lesson?
    @State private var composingLesson: Lesson?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                ZStack {
                    PageBackground(includesHomeAtmosphere: true)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            greeting(now: timeline.date)

                            if let notice = model.startupNotice {
                                AppBanner(text: notice, style: .warning)
                            }

                            if let error = viewModel?.errorMessage {
                                AppBanner(text: error, style: .warning)
                            }

                            lessonFocus(now: timeline.date)
                            quickActions
                            experiencesPreview
                            portalRow
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityLabel("Settings")
                }
            }
            .task {
                if viewModel == nil { viewModel = HomeViewModel(services: model.services) }
                await viewModel?.load()
            }
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                PortalWebController.shared.prepare(coordinator: model.services.portalCoordinator)
            }
            .refreshable {
                await model.retryStartupSyncIfNeeded()
                await viewModel?.load()
            }
            .sheet(isPresented: $showPortal) {
                PortalWebScreen(
                    portalURL: model.services.config.portalWebURL,
                    coordinator: model.services.portalCoordinator
                )
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLessonPicker, onDismiss: beginPendingComposition) {
                NavigationStack {
                    HistoryView { lesson in
                        pendingLesson = lesson
                    }
                    .environment(model)
                }
            }
            .sheet(item: $composingLesson) { lesson in
                ComposeExperienceView(context: .lesson(lesson))
                    .environment(model)
            }
        }
    }

    private func greeting(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi, " + (model.profile?.displayName ?? "Student"))
                .font(AppTheme.Typography.screenTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.fullDateFormatter.string(from: now))
                .font(AppTheme.Typography.subheadlineMedium)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lessonFocus(now: Date) -> some View {
        let lesson = viewModel?.nextLesson

        if viewModel?.isLoading == true && lesson == nil {
            AppLoadingState(title: "Checking your school day")
                .frame(minHeight: 190)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        } else if viewModel?.nextLessonAvailable == false {
            AppBanner(text: "Your next lesson could not be loaded. Pull to try again.", style: .error)
                .frame(minHeight: 120)
        } else if let lesson {
            let isCurrent = lesson.temporalState == .now
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(isCurrent ? "NOW" : "NEXT")
                        .font(AppTheme.Typography.captionBold)
                        .tracking(1.2)
                        .foregroundStyle(Palette.accent)

                    Spacer()

                    Text(isCurrent ? elapsedText(for: lesson, now: now) : startsText(for: lesson, now: now))
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(Palette.inkSecondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(lesson.subjectName)
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if let topic = distinctTopic(for: lesson) {
                        Text(topic)
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }

                lessonMetadata(lesson)

                if isCurrent {
                    ProgressView(value: progress(for: lesson, now: now))
                        .tint(Palette.accent)
                        .accessibilityLabel("Class progress")
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(Palette.line, lineWidth: 1)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your next lesson")
                    .font(AppTheme.Typography.captionBold)
                    .tracking(0.8)
                    .foregroundStyle(Palette.accent)
                Text("Nothing else is scheduled right now.")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(Palette.ink)
                Text("Open Timetable for another day, or pull to refresh if your school data changed.")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(.vertical, 8)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(title: "What do you need?")

            HStack(spacing: 12) {
                compactAction(
                    title: "Share a lesson",
                    subtitle: "Choose from past lessons",
                    symbol: "square.and.pencil",
                    action: { showLessonPicker = true }
                )

                compactAction(
                    title: "Open Access",
                    subtitle: "Permits and school gates",
                    symbol: "door.left.hand.open",
                    action: openAccess
                )
            }
        }
    }

    private func compactAction(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.line, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }

    private var experiencesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                AppSectionHeader(title: "From your classes")
                Button("See all", action: openExperiences)
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .frame(minHeight: 44)
            }

            if let recents = viewModel?.recentExperiences, !recents.isEmpty {
                VStack(spacing: 0) {
                    ForEach(recents) { experience in
                        ExperienceRow(experience: experience)
                            .padding(.vertical, 14)
                        if experience.id != recents.last?.id {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            } else if viewModel?.isLoading == true {
                AppLoadingState(title: "Loading class experiences")
            } else if viewModel?.recentExperiencesAvailable == false {
                AppBanner(text: "Class experiences could not be loaded. Pull to try again.", style: .error)
            } else {
                Text("No student experiences from your classes yet.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private var portalRow: some View {
        Button { showPortal = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .foregroundStyle(Palette.accent)
                    .frame(width: 34, height: 34)
                    .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 3) {
                    Text("School Portal")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.ink)
                    Text("Open OASIS in the app")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func metadata(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(AppTheme.Typography.subheadlineMedium)
            .foregroundStyle(Palette.inkSecondary)
    }

    @ViewBuilder
    private func lessonMetadata(_ lesson: NextLesson) -> some View {
        let items: [(String, String)] = [
            ("clock", SchoolDayGrid.timeRange(start: lesson.startsAt, end: lesson.endsAt)),
            ("person", normalizedMetadata(lesson.teacherName) ?? ""),
            ("mappin", normalizedMetadata(lesson.roomName) ?? "")
        ].filter { !$0.1.isEmpty }

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    metadata(icon: item.0, text: item.1)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    metadata(icon: item.0, text: item.1)
                }
            }
        }
    }

    private func distinctTopic(for lesson: NextLesson) -> String? {
        guard let topic = lesson.topicName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !topic.isEmpty else { return nil }
        let topicKey = comparisonKey(topic)
        let subjectKey = comparisonKey(lesson.subjectName)
        let courseKey = comparisonKey(lesson.courseName ?? "")
        guard topicKey != subjectKey, topicKey != courseKey else { return nil }
        return topic
    }

    private func normalizedMetadata(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    private func comparisonKey(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -—·:"))
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func beginPendingComposition() {
        guard let pendingLesson else { return }
        composingLesson = pendingLesson
        self.pendingLesson = nil
    }

    private func elapsedText(for lesson: NextLesson, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(lesson.startsAt)) / 60)
        let total = max(1, Int(lesson.endsAt.timeIntervalSince(lesson.startsAt)) / 60)
        return String(elapsed) + " min · " + String(total - min(elapsed, total)) + " left"
    }

    private func progress(for lesson: NextLesson, now: Date) -> Double {
        let total = max(1, lesson.endsAt.timeIntervalSince(lesson.startsAt))
        let elapsed = min(max(0, now.timeIntervalSince(lesson.startsAt)), total)
        return elapsed / total
    }

    private func startsText(for lesson: NextLesson, now: Date) -> String {
        let minutes = lesson.minutesUntilStart ?? max(0, Int(lesson.startsAt.timeIntervalSince(now)) / 60)
        if minutes <= 0 { return "Starting now" }
        return "In " + String(minutes) + " min"
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}
