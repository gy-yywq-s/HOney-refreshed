//
//  ExperiencesView.swift
//  HOney — chronological student experiences with a direct lesson picker.
//

import SwiftUI

struct ExperiencesView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: ExperiencesViewModel?
    @State private var showLessonPicker = false
    @State private var pendingLesson: Lesson?
    @State private var composingLesson: Lesson?
    @State private var showMine = false

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
                    Button { showLessonPicker = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Choose a lesson to share")

                    Button { showMine = true } label: {
                        Image(systemName: "person.text.rectangle")
                    }
                    .accessibilityLabel("My posts and private notes")
                }
            }
            .task {
                if viewModel == nil { viewModel = ExperiencesViewModel(services: model.services) }
                await viewModel?.loadFilters()
                await viewModel?.reload()
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
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ExperiencesViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What students experienced")
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundStyle(Palette.ink)
                    Text("Chronological, never ranked. Filters only narrow what you see.")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }

                filterBar(vm)

                if vm.isLoading {
                    AppLoadingState(title: "Loading student experiences")
                } else if let error = vm.errorMessage {
                    AppBanner(text: error, style: .error)
                } else if vm.experiences.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            vm.showingFromMyClasses ? "Nothing from your classes yet" : "No experiences yet",
                            systemImage: "text.bubble"
                        )
                        .font(AppTheme.Typography.headlineSemibold)
                        .foregroundStyle(Palette.ink)

                        Text(vm.showingFromMyClasses
                             ? "Import your timetable, or choose a past lesson and share your own experience."
                             : "Choose a past lesson to share your own experience.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.experiences) { experience in
                            InteractiveExperienceRow(experience: experience, services: model.services)
                                .padding(16)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                        .stroke(Palette.line, lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .searchable(text: $vm.query, prompt: "Search student experiences")
        .onSubmit(of: .search) { Task { await vm.reload() } }
        .refreshable { await vm.reload() }
    }

    private func filterBar(_ viewModel: ExperiencesViewModel) -> some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 12) {
            Picker("Order", selection: $vm.sort) {
                ForEach(ExperienceSort.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.sort) { Task { await vm.reload() } }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.small) {
                    Menu {
                        Button("All teachers") { vm.selectedTeacherId = nil; Task { await vm.reload() } }
                        ForEach(vm.teachers) { teacher in
                            Button(teacher.name) { vm.selectedTeacherId = teacher.id; Task { await vm.reload() } }
                        }
                    } label: {
                        FilterChip(title: teacherLabel(vm), isActive: vm.selectedTeacherId != nil)
                    }

                    Menu {
                        Button("All courses") { vm.selectedCourseId = nil; Task { await vm.reload() } }
                        ForEach(vm.courses) { course in
                            Button(course.name) { vm.selectedCourseId = course.id; Task { await vm.reload() } }
                        }
                    } label: {
                        FilterChip(title: courseLabel(vm), isActive: vm.selectedCourseId != nil)
                    }
                }
            }
        }
    }

    private func teacherLabel(_ vm: ExperiencesViewModel) -> String {
        vm.teachers.first { $0.id == vm.selectedTeacherId }?.name ?? "Teacher"
    }

    private func courseLabel(_ vm: ExperiencesViewModel) -> String {
        vm.courses.first { $0.id == vm.selectedCourseId }?.name ?? "Course"
    }

    private func beginPendingComposition() {
        guard let pendingLesson else { return }
        composingLesson = pendingLesson
        self.pendingLesson = nil
    }
}

struct FilterChip: View {
    let title: String
    var isActive = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(AppTheme.Typography.caption2Bold)
        }
        .font(AppTheme.Typography.captionSemibold)
        .foregroundStyle(isActive ? Palette.accent : Palette.inkSecondary)
        .padding(.horizontal, 13)
        .frame(minHeight: 44)
        .background(isActive ? Palette.accentSoft : Palette.surface, in: Capsule())
        .overlay(Capsule().stroke(isActive ? Palette.accent.opacity(0.45) : Palette.line, lineWidth: 1))
        .contentShape(Capsule())
    }
}
