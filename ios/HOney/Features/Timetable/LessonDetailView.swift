//
//  LessonDetailView.swift
//  HOney — lesson detail sheet with experience actions, in the legacy card
//  grammar.
//

import SwiftUI

struct LessonDetailView: View {
    let lesson: Lesson

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        AppCard {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                Text(lesson.subjectName)
                                    .font(AppTheme.Typography.cardTitle)
                                    .foregroundStyle(Palette.navy)
                                if let topic = lesson.topicName {
                                    Text(topic)
                                        .font(AppTheme.Typography.subheadline)
                                        .foregroundStyle(Palette.navy.opacity(0.62))
                                }
                                Label("\(lesson.periodLabel) · \(lesson.timeRange)", systemImage: "clock")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(Palette.navy.opacity(0.62))
                                if let teacher = lesson.teacherName {
                                    Label(teacher, systemImage: "person")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(Palette.navy.opacity(0.62))
                                }
                                if let room = lesson.roomName {
                                    Label(room, systemImage: "mappin.and.ellipse")
                                        .font(AppTheme.Typography.caption)
                                        .foregroundStyle(Palette.navy.opacity(0.62))
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            if let teacherId = lesson.teacherId, let teacherName = lesson.teacherName {
                                NavigationLink {
                                    LessonExperiencesView(title: teacherName, teacherId: teacherId, courseId: nil)
                                        .environment(model)
                                } label: {
                                    detailRow(title: "View teacher experiences", systemImage: "person.crop.circle")
                                }
                                .buttonStyle(.plain)
                            }
                            if let courseId = lesson.courseId {
                                NavigationLink {
                                    LessonExperiencesView(title: lesson.courseName ?? lesson.subjectName, teacherId: nil, courseId: courseId)
                                        .environment(model)
                                } label: {
                                    detailRow(title: "View course experiences", systemImage: "book")
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                showCompose = true
                            } label: {
                                Label("Share experience", systemImage: "square.and.pencil")
                                    .font(AppTheme.Typography.subheadlineSemibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Palette.ocean, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                    .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                    .padding(.vertical, 18)
                }
                .scrollIndicators(.hidden)
            }
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

    private func detailRow(title: String, systemImage: String) -> some View {
        AppCard(padding: 14) {
            AppListRow {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.ocean)
                    .frame(width: 28, height: 28)
                    .background(Palette.mist, in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
            } content: {
                Text(title)
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.navy)
            } trailing: {
                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundStyle(Palette.navy.opacity(0.28))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
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
            VStack(spacing: 10) {
                if isLoading {
                    AppLoadingState(title: "Loading experiences")
                } else if experiences.isEmpty {
                    AppEmptyState(title: "No experiences yet", systemImage: "bubble.left.and.bubble.right")
                } else {
                    ForEach(experiences) { experience in
                        AppCard { ExperienceRow(experience: experience) }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background.ignoresSafeArea())
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
