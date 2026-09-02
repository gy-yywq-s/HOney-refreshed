// The target is chosen before composing (spec §14): recent lessons one tap
// away, full History in selection mode, Explore for teachers / courses /
// places / food. Plain rows, no hero buttons.

import SwiftUI
import HOneyCore

struct TargetPickerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @State private var lessons: [Lesson] = []
    @State private var loading = true
    @State private var error: String?

    private var visibleCount: Int { UIScreen.main.bounds.height >= 800 ? 6 : 4 }

    var body: some View {
        List {
            Section {
                Text(L10n.t("One of your own lessons, or a teacher, course, place or dish."))
                    .font(HType.secondary)
                    .foregroundStyle(Color.honeySecondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                if loading {
                    LoadingPlaceholder(lines: 4).listRowBackground(Color.clear)
                } else if let error {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } })).listRowBackground(Color.clear)
                } else if lessons.isEmpty {
                    Text(L10n.t("No lessons in your history yet.")).font(HType.meta).foregroundStyle(Color.honeySecondary).listRowBackground(Color.clear)
                } else {
                    ForEach(lessons.prefix(visibleCount)) { lesson in
                        Button { nav.push(.compose(.lesson(id: lesson.id, date: Formatters.toIsoDate(Date(epochMillis: lesson.startsAt))))) } label: {
                            LessonRow(lesson: lesson, leading: Formatters.relativeDay(lesson.startsAt), trailingTime: false)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
                Button { nav.push(.history(select: true)) } label: {
                    EntityRow(title: L10n.t("See full History"))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            } header: {
                Text(L10n.t("Recent lessons")).eyebrow()
            }
            Section {
                Button { nav.push(.explore) } label: {
                    EntityRow(title: L10n.t("Teachers, courses, places and food"))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            } header: {
                Text(L10n.t("Other school context")).eyebrow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("What is this about?"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = lessons.isEmpty
        error = nil
        do {
            lessons = try await env.timetable.history(HistoryParams(limit: 6, order: .desc)).lessons
        } catch {
            self.error = APIErrorCopy.describe(error)
        }
        loading = false
    }
}
