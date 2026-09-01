//
//  HomeView.swift
//  HOney — Home: greeting header card, Current/Next class cards (legacy
//  lesson overview with the ocean progress wash), Experiences area, and the
//  School Portal row as a legacy card row.
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
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header(now: timeline.date)
                        lessonOverview(now: timeline.date)
                        experiencesArea
                        portalRow
                    }
                    .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Palette.navy.opacity(0.62))
                    }
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

    // MARK: - Greeting header (legacy header card)

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Hi, \(model.profile?.displayName ?? "Student")")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(Palette.navy)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Self.fullDateFormatter.string(from: now))
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.navy.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            LinearGradient(
                colors: [Palette.ocean.opacity(0.18), Palette.mist.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.large)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .stroke(Palette.ocean.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Current / Next class (legacy lesson overview)

    private func lessonOverview(now: Date) -> some View {
        let lesson = viewModel?.nextLesson
        let currentLesson = lesson?.temporalState == .now ? lesson : nil
        let nextLesson = (lesson != nil && currentLesson == nil && lesson?.temporalState != LessonTemporalState.none) ? lesson : nil

        return VStack(spacing: 10) {
            HomeLessonSummaryCard(
                title: "Current Class",
                systemImage: "play.circle.fill",
                lesson: currentLesson,
                detail: currentLesson.map { elapsedText(for: $0, now: now) } ?? "No class in progress",
                progress: currentLesson.map { progress(for: $0, now: now) }
            )

            HomeLessonSummaryCard(
                title: "Next Class",
                systemImage: "forward.circle.fill",
                lesson: nextLesson,
                detail: nextLesson.map { startsText(for: $0, now: now) } ?? "No upcoming classes",
                progress: nil
            )
        }
    }

    private func elapsedText(for lesson: NextLesson, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(lesson.startsAt)) / 60)
        let total = max(1, Int(lesson.endsAt.timeIntervalSince(lesson.startsAt)) / 60)
        return "\(elapsed) min elapsed · \(total - min(elapsed, total)) min left"
    }

    private func progress(for lesson: NextLesson, now: Date) -> Double {
        let total = max(1, lesson.endsAt.timeIntervalSince(lesson.startsAt))
        let elapsed = min(max(0, now.timeIntervalSince(lesson.startsAt)), total)
        return elapsed / total
    }

    private func startsText(for lesson: NextLesson, now: Date) -> String {
        let minutes = lesson.minutesUntilStart ?? max(0, Int(lesson.startsAt.timeIntervalSince(now)) / 60)
        let range = SchoolDayGrid.timeRange(start: lesson.startsAt, end: lesson.endsAt)
        if minutes <= 0 {
            return "Starting now · \(range)"
        }
        return "Starts in \(minutes) min · \(range)"
    }

    // MARK: - Experiences area

    private var experiencesArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionHeader(title: "Experiences")

            HStack(spacing: 10) {
                Button {
                    composeStandalone = true
                } label: {
                    Label("Share", systemImage: "square.and.pencil")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.ocean, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                NavigationLink {
                    ExperiencesView()
                } label: {
                    Text("Browse")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.ocean.opacity(0.14), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ocean)
            }

            if let recents = viewModel?.recentExperiences, !recents.isEmpty {
                AppCard(padding: 14) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Recent from your classes")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(Palette.ocean)
                        ForEach(recents) { experience in
                            ExperienceRow(experience: experience)
                            if experience.id != recents.last?.id {
                                Divider().overlay(Palette.line)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - School Portal row

    private var portalRow: some View {
        Button {
            showPortal = true
        } label: {
            AppCard(padding: 14) {
                AppListRow {
                    Image(systemName: "globe")
                        .foregroundStyle(Palette.ocean)
                        .frame(width: 28, height: 28)
                        .background(Palette.mist, in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                } content: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("School Portal")
                            .font(AppTheme.Typography.subheadlineSemibold)
                            .foregroundStyle(Palette.navy)
                        Text("open OASIS in a secure in-app browser")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.navy.opacity(0.62))
                    }
                } trailing: {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(Palette.navy.opacity(0.28))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(.plain)
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}

/// Ported legacy Home lesson summary card — the Current Class card carries the
/// signature ocean progress wash. Takes plain display inputs (view-layer only).
private struct HomeLessonSummaryCard: View {
    let title: String
    let systemImage: String
    let lesson: NextLesson?
    let detail: String
    let progress: Double?

    var body: some View {
        AppCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(Palette.ocean)

                if let lesson {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.subjectName)
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundStyle(Palette.navy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            Text("\(SchoolDayGrid.periodLabel(start: lesson.startsAt, end: lesson.endsAt)) · \(detail)")
                                .font(AppTheme.Typography.subheadlineMedium)
                                .foregroundStyle(Palette.navy.opacity(0.62))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Text(lesson.roomName ?? "")
                            .font(AppTheme.Typography.headlineSemibold)
                            .foregroundStyle(Palette.navy.opacity(0.82))
                    }
                } else {
                    Text(detail)
                        .font(AppTheme.Typography.headlineSemibold)
                        .foregroundStyle(Palette.navy.opacity(0.58))
                }
            }
        }
        .background(alignment: .leading) {
            if let progress {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Palette.ocean.opacity(0.67))
                        .frame(width: max(0, proxy.size.width * min(max(progress, 0), 1)))
                        .frame(maxHeight: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .allowsHitTesting(false)
            }
        }
    }
}
