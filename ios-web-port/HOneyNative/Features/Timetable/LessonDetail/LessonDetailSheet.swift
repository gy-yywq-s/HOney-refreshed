// Lesson detail (TimetablePage.tsx `LessonDetail` + features.css
// `.lesson-facts`, `.kv`): the Web modal as a sheet — the subject as the
// title, the facts (date · time in ink, teacher · room in ink-2), the
// stacked actions (Open this day, Share what this was like as the primary,
// the teacher's and the course's Experiences), and More lesson details folded.

import SwiftUI
import HOneyCore

enum LessonDetailAction {
    case openDay(String)
    case compose(ComposeTarget)
    case entity(EntityType, String)
}

struct LessonDetailSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    let showsOpenDay: Bool
    let act: (LessonDetailAction) -> Void

    private var course: CourseDisplay? {
        lesson.courseName.map { DisplayNames.parseCourseName($0, teacherName: lesson.teacherName) }
    }

    private var isoDate: String { Formatters.toIsoDate(Date(epochMillis: lesson.startsAt)) }

    var body: some View {
        let extra = course.flatMap { $0.meta.isEmpty ? nil : $0.meta }
        let topic = lesson.topicName.flatMap { $0.isEmpty || $0 == lesson.subjectName ? nil : $0 }
        WebSheet(title: lesson.subjectName, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: HSpace.x1) {
                Text("\(Formatters.shortDate(lesson.startsAt)) · \(Formatters.timeRange(lesson.startsAt, lesson.endsAt))")
                    .font(ramp.font(.bodySemibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                let who = [lesson.teacherName, DisplayNames.roomLabel(lesson.roomName)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !who.isEmpty {
                    Text(who).font(ramp.font(.body)).foregroundStyle(theme.ink2)
                }
            }
            .padding(.bottom, HSpace.x2)
            .accessibilityElement(children: .combine)
            SheetActions {
                if showsOpenDay {
                    Button(L10n.t("Open this day")) { act(.openDay(isoDate)) }.buttonStyle(.webBlockGhost)
                }
                Button(L10n.t("Share what this was like")) { act(.compose(.lesson(id: lesson.id, date: isoDate))) }
                    .buttonStyle(.webBlockPrimary)
                if let teacherId = lesson.teacherId {
                    Button("\(L10n.t("Experiences with")) \(lesson.teacherName ?? "this teacher")") { act(.entity(.teacher, teacherId)) }.buttonStyle(.webBlockGhost)
                }
                if let courseId = lesson.courseId {
                    Button(L10n.t("Experiences from this course")) { act(.entity(.course, courseId)) }.buttonStyle(.webBlockGhost)
                }
            }
            if extra != nil || topic != nil {
                DisclosureRow(summary: L10n.t("More lesson details")) {
                    Grid(alignment: .leading, horizontalSpacing: HSpace.x4, verticalSpacing: HSpace.x2) {
                        if let topic {
                            GridRow {
                                Text("Topic").font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                Text(topic).font(ramp.font(.body)).foregroundStyle(theme.ink)
                            }
                        }
                        if let extra {
                            GridRow {
                                Text("Course").font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                Text(extra).font(ramp.font(.body)).foregroundStyle(theme.ink)
                            }
                        }
                    }
                }
                .padding(.top, HSpace.x3)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
