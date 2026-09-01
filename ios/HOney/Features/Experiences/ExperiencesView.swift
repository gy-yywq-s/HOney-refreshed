//
//  ExperiencesView.swift
//  HOney — the community hub: the "from your classes" feed by default
//  (chronological, never ranked) plus a filtered browse. Ordering is always the
//  server's; nothing is re-ranked client-side.
//

import SwiftUI

struct ExperiencesView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: ExperiencesViewModel?
    @State private var showCompose = false
    @State private var showMine = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    LoadingView()
                }
            }
            .screenBackground()
            .navigationTitle("Experiences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCompose = true
                        } label: { Label("Share an experience", systemImage: "square.and.pencil") }
                        Button {
                            showMine = true
                        } label: { Label("My submissions", systemImage: "person.crop.circle") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                if viewModel == nil { viewModel = ExperiencesViewModel(services: model.services) }
                await viewModel?.loadFilters()
                await viewModel?.reload()
            }
            .sheet(isPresented: $showCompose) {
                ComposeExperienceView(context: .standalone).environment(model)
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
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                filterBar(vm)
                if vm.isLoading {
                    LoadingView().frame(height: 200)
                } else if let error = vm.errorMessage {
                    Banner(kind: .error, message: error)
                } else if vm.experiences.isEmpty {
                    EmptyStateView(
                        systemImage: "bubble.left.and.bubble.right",
                        title: vm.showingFromMyClasses ? "Nothing from your classes yet" : "No experiences yet",
                        message: vm.showingFromMyClasses
                            ? "Import your timetable, or be the first to share one."
                            : "Be the first to share what a lesson, teacher, place or dish was really like."
                    )
                } else {
                    if vm.showingFromMyClasses {
                        Text("From your classes — experiences involving your own teachers and courses, newest first. Chronological, never ranked.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    ForEach(vm.experiences) { experience in
                        Card { InteractiveExperienceRow(experience: experience, services: model.services) }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .searchable(text: $vm.query, prompt: "Search experiences")
        .onSubmit(of: .search) { Task { await vm.reload() } }
    }

    @ViewBuilder
    private func filterBar(_ viewModel: ExperiencesViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: Theme.Spacing.sm) {
            Picker("Sort", selection: $vm.sort) {
                ForEach(ExperienceSort.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.sort) { Task { await vm.reload() } }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
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
}

struct FilterChip: View {
    let title: String
    var isActive: Bool = false
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(Theme.Typography.caption)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(isActive ? Theme.Palette.accentSoft : Theme.Palette.surface)
        .foregroundStyle(isActive ? Theme.Palette.accent : Theme.Palette.textSecondary)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.line, lineWidth: 1))
    }
}
