// The target is chosen before composing (ComposePage.tsx `.picker`;
// fidelity spec v2 §10.1): the page title "What is this about?", one
// caption of guidance, Recent lessons as open entity rows, See full
// History, then Other school context → Explore. No hero buttons.

import SwiftUI
import HOneyCore

struct TargetPickerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @State private var lessons: [Lesson] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                PageTitle(text: L10n.t("What is this about?"))
                    .padding(.bottom, HSpace.x2)
                Text(L10n.t("One of your own lessons, or a teacher, course, place or dish."))
                    .hfont(.caption)
                    .foregroundStyle(theme.muted)
                    .padding(.bottom, HSpace.x3)
                Text(L10n.t("Recent lessons")).sectionLabel().padding(.top, HSpace.x3)
                if loading {
                    LoadingPlaceholder(lines: 4)
                } else if let error {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load() } }))
                } else if lessons.isEmpty {
                    Text(L10n.t("No lessons in your history yet.")).hfont(.caption).foregroundStyle(theme.muted)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(lessons.prefix(6).enumerated()), id: \.element.id) { index, lesson in
                            if index > 0 { HairlineDivider() }
                            Button { nav.push(.compose(.lesson(id: lesson.id, date: Formatters.toIsoDate(Date(epochMillis: lesson.startsAt))))) } label: {
                                EntityRow(
                                    title: lesson.subjectName,
                                    caption: [Formatters.relativeDay(lesson.startsAt), lesson.teacherName, DisplayNames.roomLabel(lesson.roomName)]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button { nav.push(.history(select: true)) } label: {
                    EntityRow(title: L10n.t("See full History"))
                }
                .buttonStyle(.plain)
                Text(L10n.t("Other school context")).sectionLabel().padding(.top, HSpace.x3)
                Button { nav.push(.explore) } label: {
                    EntityRow(title: L10n.t("Teachers, courses, places and food"))
                }
                .buttonStyle(.plain)
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("Share an experience"))
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
