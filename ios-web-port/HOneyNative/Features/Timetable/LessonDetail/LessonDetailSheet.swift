// Lesson detail (spec §18.6): a native sheet with detents — when, who,
// where, the course line — and the ways onward: this day, share what it
// was like, the teacher's / course's Experiences.

import SwiftUI
import HOneyCore

enum LessonDetailAction {
    case openDay(String)
    case compose(ComposeTarget)
    case entity(EntityType, String)
}

struct LessonDetailSheet: View {
    let lesson: Lesson
    let showsOpenDay: Bool
    let act: (LessonDetailAction) -> Void
    @Environment(\.dismiss) private var dismiss

    private var course: CourseDisplay? {
        lesson.courseName.map { DisplayNames.parseCourseName($0, teacherName: lesson.teacherName) }
    }

    private var isoDate: String { Formatters.toIsoDate(Date(epochMillis: lesson.startsAt)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        Text(lesson.subjectName).font(HType.pageTitle).foregroundStyle(Color.honeyInk)
                        let period = PeriodCatalog.periodLabel(start: PeriodCatalog.minuteOfDay(lesson.startsAt), end: PeriodCatalog.minuteOfDay(lesson.endsAt))
                        Text([Formatters.shortDate(lesson.startsAt), period].compactMap { $0 }.joined(separator: " · "))
                            .font(HType.secondary).foregroundStyle(Color.honeySecondary)
                        Text(Formatters.timeRange(lesson.startsAt, lesson.endsAt))
                            .font(HType.body.monospacedDigit()).foregroundStyle(Color.honeyInk)
                    }
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        if let teacher = lesson.teacherName, !teacher.isEmpty {
                            Label(teacher, systemImage: "person")
                        }
                        let room = DisplayNames.roomLabel(lesson.roomName)
                        if !room.isEmpty {
                            Label(room, systemImage: "mappin.and.ellipse")
                        }
                        if let topic = lesson.topicName, !topic.isEmpty, topic != lesson.subjectName {
                            Label(topic, systemImage: "text.book.closed")
                        }
                        if let course, !course.meta.isEmpty {
                            Label(course.meta, systemImage: "books.vertical")
                        }
                    }
                    .font(HType.body)
                    .foregroundStyle(Color.honeyInk)

                    VStack(spacing: HSpace.x2) {
                        if showsOpenDay {
                            Button(L10n.t("Open this day")) { act(.openDay(isoDate)) }.buttonStyle(.bordered)
                        }
                        Button(L10n.t("Share what this was like")) { act(.compose(.lesson(id: lesson.id, date: isoDate))) }
                            .buttonStyle(.borderedProminent)
                        if let teacherId = lesson.teacherId {
                            Button("\(L10n.t("Experiences with")) \(lesson.teacherName ?? "this teacher")") { act(.entity(.teacher, teacherId)) }.buttonStyle(.bordered)
                        }
                        if let courseId = lesson.courseId {
                            Button(L10n.t("Experiences from this course")) { act(.entity(.course, courseId)) }.buttonStyle(.bordered)
                        }
                    }
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HSpace.x2)
                }
                .pageInset()
                .padding(.vertical, HSpace.x4)
            }
            .background(Color.honeyCanvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Done")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
