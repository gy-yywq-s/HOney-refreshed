//
//  HistoryView.swift
//  HOney — chronological history grouped by month, with search + filters.
//  Two modes: browse (tap → lesson detail) and selection (tap → returns lessonId
//  to the composer via `onSelect`, then dismisses).
//

import SwiftUI

struct HistoryView: View {
    /// When set, the view is in selection mode and returns a chosen lessonId.
    var onSelect: ((String) -> Void)? = nil

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
                LoadingView()
            }
        }
        .screenBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
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
        List {
            Section {
                filters(vm)
            }
            if vm.isLoading {
                LoadingView().frame(height: 160).listRowSeparator(.hidden)
            } else if let error = vm.errorMessage {
                Banner(kind: .error, message: error).listRowSeparator(.hidden)
            } else if vm.lessons.isEmpty {
                EmptyStateView(systemImage: "clock.arrow.circlepath", title: "No history")
                    .listRowSeparator(.hidden)
            } else {
                ForEach(vm.groupedByMonth) { group in
                    Section(group.label) {
                        ForEach(group.lessons) { lesson in
                            Button {
                                if let onSelect {
                                    onSelect(lesson.id)
                                    dismiss()
                                } else {
                                    selectedLesson = lesson
                                }
                            } label: {
                                HistoryRow(lesson: lesson, selecting: isSelecting)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $vm.query, prompt: "Search lessons")
        .onSubmit(of: .search) { Task { await vm.reload() } }
    }

    @ViewBuilder
    private func filters(_ viewModel: HistoryViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
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
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    }
}

struct HistoryRow: View {
    let lesson: Lesson
    var selecting: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.subjectName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(lesson.startsAt, format: .dateTime.month().day())
                    if let teacher = lesson.teacherName { Text("· \(teacher)") }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: selecting ? "plus.circle" : "chevron.right")
                .foregroundStyle(selecting ? Theme.Palette.accent : Theme.Palette.line)
                .font(.caption.weight(.semibold))
        }
        .contentShape(Rectangle())
    }
}
