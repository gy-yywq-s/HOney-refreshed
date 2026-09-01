//
//  LessonDetailView.swift
//  HOney — lesson detail sheet with experience actions.
//

import SwiftUI

struct LessonDetailView: View {
    let lesson: Lesson

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(lesson.subjectName)
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            if let topic = lesson.topicName {
                                Text(topic)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "clock")
                                Text(lesson.startsAt, style: .time)
                                Text("–")
                                Text(lesson.endsAt, style: .time)
                            }
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            if let teacher = lesson.teacherName {
                                Label(teacher, systemImage: "person")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            if let room = lesson.roomName {
                                Label(room, systemImage: "mappin.and.ellipse")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }

                    VStack(spacing: Theme.Spacing.md) {
                        if let teacherId = lesson.teacherId, let teacherName = lesson.teacherName {
                            NavigationLink {
                                LessonExperiencesView(title: teacherName, teacherId: teacherId, courseId: nil)
                                    .environment(model)
                            } label: {
                                ListRow(title: "View teacher experiences", systemImage: "person.crop.circle", showsChevron: true)
                            }
                        }
                        if let courseId = lesson.courseId {
                            NavigationLink {
                                LessonExperiencesView(title: lesson.courseName ?? lesson.subjectName, teacherId: nil, courseId: courseId)
                                    .environment(model)
                            } label: {
                                ListRow(title: "View course experiences", systemImage: "book", showsChevron: true)
                            }
                        }
                        Button {
                            showCompose = true
                        } label: {
                            Label("Share experience", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(HOneyPrimaryButtonStyle())
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $showCompose) {
                ComposeExperienceView(context: .lesson(lesson)).environment(model)
            }
        }
    }
}

/// A read-only experiences list filtered by a teacher or a course.
struct LessonExperiencesView: View {
    let title: String
    let teacherId: String?
    let courseId: String?

    @Environment(AppModel.self) private var model
    @State private var experiences: [PublicExperience] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if isLoading {
                    LoadingView().frame(height: 160)
                } else if experiences.isEmpty {
                    EmptyStateView(systemImage: "bubble.left.and.bubble.right", title: "No experiences yet")
                } else {
                    ForEach(experiences) { experience in
                        Card { ExperienceRow(experience: experience) }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            let response = try? await model.services.honeyAPI.experiences(teacherId: teacherId, courseId: courseId)
            experiences = response?.experiences ?? []
            isLoading = false
        }
    }
}
