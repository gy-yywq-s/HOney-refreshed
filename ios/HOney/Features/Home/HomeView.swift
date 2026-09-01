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
                    PageBackground()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            greeting(now: timeline.date)

                            if let notice = model.startupNotice {
                                AppBanner(text: notice, style: .warning)
                            }

                            if let notice = model.portalCredentialNotice {
                                AppBanner(text: notice, style: .warning)
                            }

                            if let error = viewModel?.errorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    AppBanner(text: error, style: .warning)
                                    Button("Try Home again") {
                                        Task { await viewModel?.load(forceRefresh: true) }
                                    }
                                    .font(AppTheme.Typography.subheadlineSemibold)
                                    .frame(minHeight: 44)
                                }
                            }

                            lessonFocus(now: timeline.date)
                            experiencesPreview
                            secondaryActions
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await model.retryStartupSyncIfNeeded()
                            await viewModel?.load(forceRefresh: true)
                        }
                    } label: {
                        if viewModel?.isLoading == true {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .disabled(viewModel?.isLoading == true)
                    .accessibilityLabel("Refresh Home")

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
            .task(id: viewModel?.nextLesson?.endsAt) {
                guard let end = viewModel?.nextLesson?.endsAt else { return }
                let delay = end.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                await viewModel?.load(forceRefresh: true)
            }
            .task {
                await Task.yield()
                guard !Task.isCancelled else { return }
                PortalWebController.shared.prepare(coordinator: model.services.portalCoordinator)
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
                .accessibilityAddTraits(.isHeader)

            Text(Self.fullDateFormatter.string(from: now))
                .font(AppTheme.Typography.subheadlineMedium)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lessonFocus(now: Date) -> some View {
        let lesson = viewModel?.nextLesson

        if viewModel?.isLoadingLesson == true && lesson == nil {
            AppLoadingState(title: "Checking your school day")
                .frame(minHeight: 150)
                .background(Palette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .stroke(Palette.line.opacity(0.72), lineWidth: 1)
                }
        } else if let lesson {
            let isCurrent = lesson.startsAt <= now && now < lesson.endsAt
            let isExpired = now >= lesson.endsAt
            let scheduleColor = Palette.scheduleMarker(for: lesson.subjectName)
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label(
                        isExpired ? "Last known lesson" : (isCurrent ? "Now" : "Next"),
                        systemImage: isExpired ? "clock.badge.exclamationmark" : (isCurrent ? "circle.fill" : "arrow.forward")
                    )
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(scheduleColor)

                    Spacer()

                    Text(
                        isExpired
                            ? "Ended · refresh unavailable"
                            : (isCurrent ? elapsedText(for: lesson, now: now) : startsText(for: lesson, now: now))
                    )
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

                if isCurrent && !isExpired {
                    ProgressView(value: progress(for: lesson, now: now))
                        .tint(scheduleColor)
                        .accessibilityLabel("Class progress")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(scheduleColor)
                    .frame(width: 3)
                    .padding(.vertical, 18)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(Palette.line.opacity(0.72), lineWidth: 1)
            }
        } else if viewModel?.nextLessonAvailable == false {
            AppBanner(text: "Your next lesson could not be loaded. Use Refresh Home above to try again.", style: .error)
                .frame(minHeight: 120)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your next lesson")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Nothing else is scheduled right now.")
                    .font(AppTheme.Typography.title3)
                    .foregroundStyle(Palette.ink)
                Text("Open Timetable for another day, or use Refresh Home if your school data changed.")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .stroke(Palette.line.opacity(0.72), lineWidth: 1)
            }
        }
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
                        ExperienceRow(
                            experience: experience,
                            targetLabel: viewModel?.targetLabel(for: experience)
                        )
                            .padding(.vertical, 14)
                        if experience.id != recents.last?.id {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            } else if viewModel?.isLoadingExperiences == true {
                AppLoadingState(title: "Loading class experiences")
            } else if viewModel?.recentExperiencesAvailable == false {
                AppBanner(text: "Class experiences could not be loaded. Use Refresh Home above to try again.", style: .error)
            } else {
                Text("No student experiences from your classes yet.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private var secondaryActions: some View {
        HStack(spacing: 0) {
            quietAction(title: "Share something", symbol: "square.and.pencil", color: Palette.communityMarker) {
                showLessonPicker = true
            }

            Rectangle()
                .fill(Palette.line)
                .frame(width: 1, height: 28)

            quietAction(title: "Open Access", symbol: "door.left.hand.open", color: Palette.accessMarker, action: openAccess)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .top) { Divider().overlay(Palette.line) }
        .overlay(alignment: .bottom) { Divider().overlay(Palette.line) }
    }

    private func quietAction(title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(title).foregroundStyle(Palette.ink)
            }
                .font(AppTheme.Typography.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var portalRow: some View {
        Button { showPortal = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .foregroundStyle(Palette.portalMarker)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("School Portal")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.ink)
                    Text("Open the school portal in the app")
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
            ("person", normalizedMetadata(lesson.teacherName) ?? "Teacher not listed"),
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
        if !Calendar.current.isDate(lesson.startsAt, inSameDayAs: now) {
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
               Calendar.current.isDate(lesson.startsAt, inSameDayAs: tomorrow) {
                return "Tomorrow · " + Self.timeFormatter.string(from: lesson.startsAt)
            }
            return Self.shortDateTimeFormatter.string(from: lesson.startsAt)
        }
        let minutes = lesson.minutesUntilStart ?? max(0, Int(lesson.startsAt.timeIntervalSince(now)) / 60)
        if minutes <= 0 { return "Starting now" }
        if minutes > 120 { return "At " + Self.timeFormatter.string(from: lesson.startsAt) }
        return "In " + String(minutes) + " min"
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE · HH:mm"
        return formatter
    }()
}
