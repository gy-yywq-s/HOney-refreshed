//
//  ExperiencesView.swift
//  HOney — a feed-first student space with a separate, complete Explore list.
//

import SwiftUI

struct ExperiencesView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: ExperiencesViewModel?
    @State private var showLessonPicker = false
    @State private var pendingLesson: Lesson?
    @State private var composingLesson: Lesson?
    @State private var showMine = false
    @State private var showExplore = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                if let viewModel {
                    content(viewModel)
                } else {
                    AppLoadingState(title: "Loading student experiences")
                }
            }
            .navigationTitle("Experiences")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showExplore = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Explore teachers, courses, places and food")

                    Button { showLessonPicker = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Choose a lesson to share")

                    Button("Yours") { showMine = true }
                        .accessibilityLabel("Your posts and private notes")
                }
            }
            .task {
                if viewModel == nil { viewModel = ExperiencesViewModel(services: model.services) }
                guard let viewModel else { return }
                async let targets: Void = viewModel.loadFilters()
                async let feed: Void = viewModel.reload()
                _ = await (targets, feed)
            }
            .sheet(isPresented: $showLessonPicker, onDismiss: beginPendingComposition) {
                NavigationStack {
                    HistoryView { lesson in pendingLesson = lesson }
                        .environment(model)
                }
            }
            .sheet(item: $composingLesson) { lesson in
                ComposeExperienceView(context: .lesson(lesson)).environment(model)
            }
            .sheet(isPresented: $showMine) {
                MySubmissionsView().environment(model)
            }
            .sheet(isPresented: $showExplore) {
                if let viewModel {
                    NavigationStack {
                        ExperiencesExploreView(viewModel: viewModel)
                        .environment(model)
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                CommunityMeaningView()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ExperiencesViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                communityIdentity
                    .padding(.bottom, 14)

                Picker("Feed", selection: $vm.scope) {
                    Text("Your classes").tag(ExperienceFeedScope.myClasses)
                    Text("Around school").tag(ExperienceFeedScope.school)
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.scope) { Task { await vm.reload() } }
                .padding(.bottom, 10)

                feedContent(vm)
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .refreshable { await vm.reload(forceRefresh: true) }
    }

    private var communityIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("For students, between students — not a teacher feedback channel.")
                .font(AppTheme.Typography.footnoteMedium)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Why this space exists") { showAbout = true }
                .font(AppTheme.Typography.footnoteMedium)
                .foregroundStyle(Palette.accent)
                .frame(minHeight: 44, alignment: .leading)
        }
    }

    @ViewBuilder
    private func feedContent(_ vm: ExperiencesViewModel) -> some View {
        if vm.isLoading && vm.experiences.isEmpty {
            AppLoadingState(title: "Loading student experiences")
                .padding(.vertical, 28)
        } else if let error = vm.errorMessage, vm.experiences.isEmpty {
            AppBanner(text: error, style: .error)
                .padding(.top, 10)
        } else if vm.experiences.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(vm.showingFromMyClasses ? "Nothing from your classes yet" : "No experiences around school yet")
                    .font(AppTheme.Typography.headlineSemibold)
                    .foregroundStyle(Palette.ink)
                Text(vm.showingFromMyClasses
                     ? "Your imported lesson history connects this feed to classes you have taken."
                     : "Share something from a past lesson, place or school item to begin.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                Button("Share an experience") { showLessonPicker = true }
                    .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(.vertical, 24)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(vm.experiences) { experience in
                    InteractiveExperienceRow(
                        experience: experience,
                        services: model.services,
                        targetLabel: vm.targetLabel(for: experience)
                    )
                    .padding(.vertical, 17)

                    if experience.id != vm.experiences.last?.id {
                        Divider().overlay(Palette.line)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anything from school you want to put into words?")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.ink)
                    Button("Share an experience") { showLessonPicker = true }
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
            }

            if let error = vm.errorMessage {
                AppBanner(text: error, style: .warning)
                    .padding(.top, 14)
            }
        }
    }

    private func beginPendingComposition() {
        guard let pendingLesson else { return }
        composingLesson = pendingLesson
        self.pendingLesson = nil
    }
}

// MARK: - Explore: every available choice is rendered, never search-gated

private enum ExperienceExploreTarget: Hashable, Identifiable {
    case teacher(DirectoryEntry, EntityRef?)
    case course(DirectoryEntry)
    case entity(EntityRef)

    var id: String {
        switch self {
        case .teacher(let item, _): return "teacher:" + item.id
        case .course(let item): return "course:" + item.id
        case .entity(let item): return item.entityKey
        }
    }

    var title: String {
        switch self {
        case .teacher(let item, _), .course(let item): return item.name
        case .entity(let item): return item.name
        }
    }

    var kindLabel: String {
        switch self {
        case .teacher: return "Teacher"
        case .course: return "Course"
        case .entity(let item): return item.type == .dish ? "Food" : "Place"
        }
    }

    var composeEntity: EntityRef? {
        switch self {
        case .teacher(_, let entity): return entity
        case .entity(let entity): return entity
        case .course: return nil
        }
    }
}

private struct ExperiencesExploreView: View {
    let viewModel: ExperiencesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            Section {
                if viewModel.isLoadingTargets {
                    AppLoadingState(title: teacherTargets.isEmpty && courseTargets.isEmpty && placeTargets.isEmpty && foodTargets.isEmpty
                                    ? "Loading every available choice"
                                    : "Refreshing available choices")
                    if !teacherTargets.isEmpty || !courseTargets.isEmpty || !placeTargets.isEmpty || !foodTargets.isEmpty {
                        Text("Previously loaded choices remain visible below while the complete list refreshes.")
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                } else {
                    if let message = viewModel.targetLoadMessage {
                        AppBanner(text: message, style: viewModel.directoryAvailable || viewModel.entitiesAvailable ? .warning : .error)
                        Button("Try loading choices again") {
                            Task { await viewModel.retryFilters() }
                        }
                        .frame(minHeight: 44)
                    } else {
                        Text("Every available option is listed below. Search only filters this complete list.")
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            .listRowBackground(Palette.surface)

            targetSection("Teachers", targets: filtered(teacherTargets), sourceAvailable: viewModel.directoryAvailable)
            targetSection("Courses", targets: filtered(courseTargets), sourceAvailable: viewModel.directoryAvailable)
            targetSection("Places", targets: filtered(placeTargets), sourceAvailable: viewModel.entitiesAvailable)
            targetSection("Food", targets: filtered(foodTargets), sourceAvailable: viewModel.entitiesAvailable)
        }
        .scrollContentBackground(.hidden)
        .background(PageBackground())
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Filter the choices shown below")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
        }
        .navigationDestination(for: ExperienceExploreTarget.self) { target in
            ExperienceExploreResultsView(target: target)
        }
    }

    @ViewBuilder
    private func targetSection(
        _ title: String,
        targets: [ExperienceExploreTarget],
        sourceAvailable: Bool
    ) -> some View {
        Section(title) {
            if !sourceAvailable {
                Text("\(title) could not be loaded.")
                    .foregroundStyle(Palette.inkSecondary)
            } else if targets.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No shown choices match this filter.")
                    .foregroundStyle(Palette.inkSecondary)
            } else if targets.isEmpty {
                Text("No \(title.lowercased()) are available yet.")
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                ForEach(targets) { target in
                    NavigationLink(value: target) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.title)
                                .foregroundStyle(Palette.ink)
                            Text(target.kindLabel)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
            }
        }
        .listRowBackground(Palette.surface)
    }

    private var teacherTargets: [ExperienceExploreTarget] {
        viewModel.teachers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { teacher in
            let direct = viewModel.entities.first { $0.entityKey == "teacher:" + teacher.id }
                ?? viewModel.entities.first { $0.type == .teacher && $0.name.caseInsensitiveCompare(teacher.name) == .orderedSame }
            return .teacher(teacher, direct)
        }
    }

    private var courseTargets: [ExperienceExploreTarget] {
        viewModel.courses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map(ExperienceExploreTarget.course)
    }

    private var placeTargets: [ExperienceExploreTarget] {
        viewModel.entities.filter { $0.type == .room }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(ExperienceExploreTarget.entity)
    }

    private var foodTargets: [ExperienceExploreTarget] {
        viewModel.entities.filter { $0.type == .dish }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(ExperienceExploreTarget.entity)
    }

    private func filtered(_ targets: [ExperienceExploreTarget]) -> [ExperienceExploreTarget] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return targets }
        return targets.filter { $0.title.localizedCaseInsensitiveContains(cleaned) }
    }
}

private struct ExperienceExploreResultsView: View {
    let target: ExperienceExploreTarget

    @Environment(AppModel.self) private var model
    @State private var experiences: [PublicExperience] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCompose = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(target.kindLabel.uppercased())
                    .font(AppTheme.Typography.captionBold)
                    .tracking(1)
                    .foregroundStyle(Palette.accent)
                Text(target.title)
                    .font(AppTheme.Typography.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 3)
                Text("No single Experience is the whole picture.")
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.top, 5)

                if target.composeEntity != nil {
                    Button("Share your experience") { showCompose = true }
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: 44, alignment: .leading)
                        .padding(.top, 8)
                }

                Divider().overlay(Palette.line).padding(.top, 8)

                if isLoading {
                    AppLoadingState(title: "Loading experiences")
                        .padding(.vertical, 28)
                } else if let errorMessage {
                    AppBanner(text: errorMessage, style: .error)
                        .padding(.top, 16)
                } else if experiences.isEmpty {
                    AppEmptyState(title: "No experiences yet", systemImage: "text.bubble")
                        .padding(.vertical, 28)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(experiences) { experience in
                            InteractiveExperienceRow(experience: experience, services: model.services)
                                .padding(.vertical, 17)
                            if experience.id != experiences.last?.id {
                                Divider().overlay(Palette.line)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(target.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCompose, onDismiss: { Task { await load() } }) {
            if let entity = target.composeEntity {
                ComposeExperienceView(context: .entity(entity)).environment(model)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response: ExperiencesFeedResponse
            switch target {
            case .teacher(let teacher, _):
                response = try await model.services.honeyAPI.experiences(teacherId: teacher.id)
            case .course(let course):
                response = try await model.services.honeyAPI.experiences(courseId: course.id)
            case .entity(let entity):
                response = try await model.services.honeyAPI.experiences(entityKey: entity.entityKey)
            }
            experiences = response.experiences
        } catch {
            errorMessage = "Experiences could not be loaded. Try again."
        }
    }
}

// MARK: - Community meaning

private struct CommunityMeaningView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(String, String)] = [
        ("Student to student", "Experiences is written for other students. Teachers can be an important subject here, but this is not a feedback inbox submitted to them."),
        ("Why sharing matters", "Something can be worth sharing because it may help another student, because it mattered to you, or both."),
        ("One experience is partial", "People are more than one experience. A post is not the whole truth about a person, and it can still be meaningful."),
        ("Mixed and negative experiences belong", "You do not have to make an experience positive or perfectly explained. Negative is allowed; cruelty and identifying another student are not."),
        ("More context, fewer verdicts", "Specific context can help someone understand, but a hard-to-explain feeling can still be your experience."),
        ("What verification means", "HOney verifies relevant school exposure where possible. It does not certify every interpretation as objective fact."),
        ("What this space does not carry", "Matters needing investigation, safeguarding, discipline or urgent action belong in the appropriate school channel, not the public feed."),
        ("How anonymity works", "Public posts are stored without an author field. Your words may still make you recognisable to people who know the situation, and a private device key controls a post later.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Why this space exists")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                    Text("A place to understand school through one another’s experiences.")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Palette.inkSecondary)

                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.0)
                                .font(AppTheme.Typography.headlineSemibold)
                                .foregroundStyle(Palette.ink)
                            Text(section.1)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(AppTheme.Spacing.pageHorizontal)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("About Experiences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        }
    }
}
