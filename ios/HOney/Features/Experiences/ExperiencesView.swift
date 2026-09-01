//
//  ExperiencesView.swift
//  HOney — the community hub: the "from your classes" feed by default
//  (chronological, never ranked) plus a filtered browse. Ordering is always the
//  server's; nothing is re-ranked client-side. Built in the legacy grammar —
//  AppCard rows, chip filters, quiet copy.
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
                    AppLoadingState(title: "Loading experiences")
                }
            }
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
                            .foregroundStyle(Palette.navy.opacity(0.62))
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
            VStack(alignment: .leading, spacing: 14) {
                filterBar(vm)
                if vm.isLoading {
                    AppLoadingState(title: "Loading experiences")
                } else if let error = vm.errorMessage {
                    AppBanner(text: error, style: .error)
                } else if vm.experiences.isEmpty {
                    AppCard(background: .white.opacity(0.82)) {
                        VStack(alignment: .leading, spacing: 6) {
                            AppEmptyState(
                                title: vm.showingFromMyClasses ? "Nothing from your classes yet" : "No experiences yet",
                                systemImage: "bubble.left.and.bubble.right"
                            )
                            Text(vm.showingFromMyClasses
                                 ? "Import your timetable, or be the first to share one."
                                 : "Be the first to share what a lesson, teacher, place or dish was really like.")
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Palette.navy.opacity(0.48))
                                .padding(.horizontal, AppTheme.Spacing.medium)
                        }
                    }
                } else {
                    if vm.showingFromMyClasses {
                        Text("From your classes — experiences involving your own teachers and courses, newest first. Chronological, never ranked.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.navy.opacity(0.48))
                    }
                    ForEach(vm.experiences) { experience in
                        AppCard { InteractiveExperienceRow(experience: experience, services: model.services) }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .searchable(text: $vm.query, prompt: "Search experiences")
        .onSubmit(of: .search) { Task { await vm.reload() } }
    }

    @ViewBuilder
    private func filterBar(_ viewModel: ExperiencesViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: AppTheme.Spacing.small) {
            Picker("Sort", selection: $vm.sort) {
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
}

/// Filter chip in the legacy chip/tag grammar: active = ocean chip
/// (caption2Bold on ocean@0.10), inactive = tag (navy@0.54 on mist@0.72).
struct FilterChip: View {
    let title: String
    var isActive: Bool = false
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down").font(AppTheme.Typography.caption2Bold)
        }
        .font(isActive ? AppTheme.Typography.caption2Bold : AppTheme.Typography.caption2Medium)
        .foregroundStyle(isActive ? Palette.ocean : Palette.navy.opacity(0.54))
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(isActive ? Palette.ocean.opacity(0.10) : Palette.mist.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(isActive ? Palette.ocean.opacity(0.24) : Palette.line, lineWidth: 1))
    }
}
