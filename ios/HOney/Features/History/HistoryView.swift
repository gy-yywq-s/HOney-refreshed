//
//  HistoryView.swift
//  HOney — past lessons grouped by month, with search and filters.
//  Two modes: browse (tap → lesson detail) and selection (tap → returns lessonId
//  to the composer via `onSelect`, then dismisses).
//

import SwiftUI

struct HistoryView: View {
    /// When set, the view is in selection mode and returns the chosen lesson.
    var onSelect: ((Lesson) -> Void)? = nil

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: HistoryViewModel?
    @State private var selectedLesson: Lesson?

    private var isSelecting: Bool { onSelect != nil }

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                AppLoadingState(title: "Loading past lessons")
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(isSelecting ? "Choose a lesson" : "Past lessons")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel?.reload(forceRefresh: true) }
                } label: {
                    if viewModel?.isLoading == true && viewModel?.lessons.isEmpty == false {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel?.isLoading == true)
                .accessibilityLabel("Refresh past lessons")
            }
        }
        .task {
            if viewModel == nil { viewModel = HistoryViewModel(services: model.services) }
            await viewModel?.loadFilters()
            await viewModel?.reload()
        }
        .sheet(item: $selectedLesson) { lesson in
            LessonDetailView(lesson: lesson).environment(model)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HistoryViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                filters(vm)

                if let filterError = vm.filterErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        AppBanner(text: filterError, style: .warning)
                        Button("Try loading filter choices again") {
                            Task { await vm.loadFilters(forceRefresh: true) }
                        }
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .frame(minHeight: 44)
                    }
                }

                if vm.isLoading && vm.lessons.isEmpty {
                    AppLoadingState(title: "Loading past lessons")
                } else if let error = vm.errorMessage, vm.lessons.isEmpty {
                    AppBanner(text: error, style: .error)
                } else if vm.lessons.isEmpty {
                    AppEmptyState(title: "No past lessons", systemImage: "clock.arrow.circlepath")
                } else {
                    ForEach(vm.groupedByMonth) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            AppSectionHeader(title: group.label)

                            AppCard(padding: AppTheme.Spacing.medium) {
                                VStack(spacing: AppTheme.Spacing.small) {
                                    ForEach(group.lessons) { lesson in
                                        Button {
                                            if let onSelect {
                                                onSelect(lesson)
                                                dismiss()
                                            } else {
                                                selectedLesson = lesson
                                            }
                                        } label: {
                                            HistoryRow(lesson: lesson, selecting: isSelecting)
                                        }
                                        .buttonStyle(.plain)

                                        if lesson.id != group.lessons.last?.id {
                                            Divider().overlay(Palette.line.opacity(0.7))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let error = vm.errorMessage {
                        AppBanner(text: error, style: .warning)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .searchable(text: $vm.query, prompt: "Search lessons")
        .onSubmit(of: .search) { Task { await vm.reload() } }
    }

    @ViewBuilder
    private func filters(_ viewModel: HistoryViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.small) {
                Menu {
                    Button("All teachers") { vm.selectedTeacherId = nil; Task { await vm.reload() } }
                    ForEach(vm.teachers) { t in
                        Button(t.name) { vm.selectedTeacherId = t.id; Task { await vm.reload() } }
                    }
                } label: {
                    FilterChip(title: vm.teachers.first { $0.id == vm.selectedTeacherId }?.name ?? "Teacher",
                               isActive: vm.selectedTeacherId != nil)
                }
                Menu {
                    Button("All courses") { vm.selectedCourseId = nil; Task { await vm.reload() } }
                    ForEach(vm.courses) { c in
                        Button(c.name) { vm.selectedCourseId = c.id; Task { await vm.reload() } }
                    }
                } label: {
                    FilterChip(title: vm.courses.first { $0.id == vm.selectedCourseId }?.name ?? "Course",
                               isActive: vm.selectedCourseId != nil)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let lesson: Lesson
    var selecting: Bool = false

    var body: some View {
        AppListRow {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.subjectName)
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.navy)
                HStack(spacing: AppTheme.Spacing.xSmall) {
                    Text(lesson.startsAt, format: .dateTime.month().day())
                    if let teacher = lesson.teacherName { Text("· \(teacher)") }
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
            }
        } trailing: {
            Image(systemName: selecting ? "plus.circle" : "chevron.right")
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(selecting ? Palette.ocean : Palette.inkSecondary)
        }
        .contentShape(Rectangle())
    }
}
