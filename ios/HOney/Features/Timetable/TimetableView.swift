//
//  TimetableView.swift
//  HOney — Day view only: date header (prev/next/Today + swipe), lesson blocks.
//

import SwiftUI

struct TimetableView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: TimetableViewModel?
    @State private var selectedLesson: Lesson?

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
            .navigationTitle("Timetable")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Text("History")
                    }
                }
            }
            .task {
                if viewModel == nil { viewModel = TimetableViewModel(services: model.services) }
                await viewModel?.load()
            }
            .sheet(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson).environment(model)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TimetableViewModel) -> some View {
        VStack(spacing: 0) {
            dateHeader(viewModel)
            Divider().overlay(Theme.Palette.line)
            ScrollView {
                if viewModel.isLoading {
                    LoadingView().frame(height: 240)
                } else if let error = viewModel.errorMessage {
                    Banner(kind: .warning, message: error).padding(Theme.Spacing.lg)
                } else if viewModel.lessons.isEmpty {
                    EmptyStateView(
                        systemImage: "calendar",
                        title: "No lessons",
                        message: "There is nothing scheduled for this day."
                    )
                    .padding(.top, Theme.Spacing.xxxl)
                } else {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.lessons) { lesson in
                            Button {
                                selectedLesson = lesson
                            } label: {
                                LessonBlock(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        if value.translation.width < 0 { viewModel.goToNextDay() }
                        else if value.translation.width > 0 { viewModel.goToPreviousDay() }
                    }
            )
        }
    }

    @ViewBuilder
    private func dateHeader(_ viewModel: TimetableViewModel) -> some View {
        HStack {
            Button { viewModel.goToPreviousDay() } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(viewModel.selectedDate, format: .dateTime.month().day())
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Button { viewModel.goToNextDay() } label: {
                Image(systemName: "chevron.right")
            }
        }
        .overlay(alignment: .trailing) {
            if !viewModel.isToday {
                Button("Today") { viewModel.goToToday() }
                    .font(Theme.Typography.caption)
                    .padding(.trailing, 40)
            }
        }
        .padding(Theme.Spacing.lg)
    }
}

struct LessonBlock: View {
    let lesson: Lesson

    var body: some View {
        Card(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.startsAt, style: .time)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.accent)
                    Text(lesson.endsAt, style: .time)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .frame(width: 64, alignment: .leading)

                Rectangle()
                    .fill(Theme.Palette.accent)
                    .frame(width: 3)
                    .clipShape(Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.subjectName)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let teacher = lesson.teacherName {
                        Text(teacher)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    if let room = lesson.roomName {
                        Text(room)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }
}
