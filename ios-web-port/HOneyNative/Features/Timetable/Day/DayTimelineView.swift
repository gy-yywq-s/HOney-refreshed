// The Day timeline (spec §18.4): a 09:00–20:00 continuous canvas that
// widens to the hour for early/late lessons, P1–P6 bands, Lunch/Dinner
// breaks, free-period labels, an hour grid, the now-line, and lesson blocks
// positioned by wall time. Geometry comes from HOneyCore.DayLayout; the
// band definitions are the shared PeriodCatalog.

import SwiftUI
import HOneyCore

struct DayTimelineView: View {
    let date: String
    let lessons: [Lesson]
    let onSelect: (Lesson) -> Void

    private let pointsPerMinute: CGFloat = 1.05
    private let gutter: CGFloat = 46

    private var layout: DayLayout { DayLayout(lessons: lessons) }
    private var isToday: Bool { date == Formatters.todayIsoDate() }

    var body: some View {
        let layout = layout
        let height = CGFloat(layout.range.minutes) * pointsPerMinute
        VStack(alignment: .leading, spacing: HSpace.x3) {
            if layout.lessons.isEmpty {
                HStack(spacing: HSpace.x2) {
                    Image(systemName: "calendar")
                    Text(isToday ? L10n.t("No lessons today") : "No lessons on \(Formatters.stepperDate(date))")
                }
                .font(HType.secondary)
                .foregroundStyle(Color.honeySecondary)
                .padding(.top, HSpace.x2)
                .accessibilityAddTraits(.updatesFrequently)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let nowMinute = PeriodCatalog.minuteOfDay(context.date.epochMillis)
                HStack(alignment: .top, spacing: 0) {
                    hourGutter(layout, height: height)
                    canvas(layout, height: height, nowMinute: nowMinute)
                }
                .frame(height: height + 12)
            }
        }
    }

    private func y(_ minute: Int, _ layout: DayLayout, _ height: CGFloat) -> CGFloat {
        CGFloat(layout.range.fraction(minute)) * height
    }

    private func hourGutter(_ layout: DayLayout, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(layout.range.hourMarks, id: \.self) { minute in
                Text(PeriodCatalog.minuteLabel(minute))
                    .font(HType.micro.monospacedDigit())
                    .foregroundStyle(Color.honeyTertiary)
                    .offset(y: y(minute, layout, height) - 7)
            }
        }
        .frame(width: gutter, height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func canvas(_ layout: DayLayout, height: CGFloat, nowMinute: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Bands
                ForEach(PeriodCatalog.bands) { band in
                    Rectangle()
                        .fill(band.isPeriod ? ((band.periodNumber ?? 0) % 2 == 0 ? Color.honeySoft : Color.clear) : Color.honeyBreak)
                        .frame(width: geo.size.width, height: CGFloat(layout.range.height(from: band.start, to: band.end)) * height)
                        .offset(y: y(band.start, layout, height))
                }
                // Hour grid
                ForEach(layout.range.hourMarks, id: \.self) { minute in
                    Rectangle().fill(Color.honeyLine).frame(width: geo.size.width, height: 1).offset(y: y(minute, layout, height))
                }
                // Free-period ghosts
                ForEach(layout.freePeriods) { slot in
                    HStack(spacing: 6) {
                        Text("P\(slot.periodNumber ?? 0)").fontWeight(.semibold)
                        Text(L10n.t("Free"))
                    }
                    .font(HType.micro)
                    .foregroundStyle(Color.honeyTertiary)
                    .padding(.leading, HSpace.x3)
                    .offset(y: y(slot.start, layout, height) + 7)
                }
                // Break labels
                ForEach(PeriodCatalog.breaks) { band in
                    HStack(spacing: 6) {
                        Image(systemName: "leaf").font(.caption2)
                        Text(band.breakLabel ?? "")
                    }
                    .font(HType.micro)
                    .foregroundStyle(Color.honeySuccess)
                    .padding(.leading, HSpace.x3)
                    .offset(y: y(band.start, layout, height) + 7)
                }
                // Lessons
                ForEach(layout.lessons) { placed in
                    let top = y(placed.startMinute, layout, height)
                    let blockHeight = max(30, CGFloat(layout.range.height(from: placed.startMinute, to: placed.endMinute)) * height - 3)
                    LessonBlock(placed: placed, live: isToday && layout.isLive(placed, nowMinute: nowMinute)) { onSelect(placed.lesson) }
                        .frame(width: geo.size.width - HSpace.x2, height: blockHeight)
                        .offset(x: HSpace.x1, y: top + 1.5)
                        .id("lesson-\(placed.id)")
                }
                // Now line
                if isToday, layout.showsNowLine(nowMinute: nowMinute) {
                    HStack(spacing: 0) {
                        Circle().fill(Color.honeyNow).frame(width: 7, height: 7)
                        Rectangle().fill(Color.honeyNow).frame(height: 1.5)
                    }
                    .frame(width: geo.size.width)
                    .offset(y: y(nowMinute, layout, height) - 3.5)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
}

struct LessonBlock: View {
    let placed: PlacedLesson
    let live: Bool
    let tap: () -> Void

    var body: some View {
        let lesson = placed.lesson
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lesson.subjectName)
                        .font(HType.secondary.weight(.semibold))
                        .foregroundStyle(Color.honeyInk)
                        .lineLimit(placed.compact ? 1 : 2)
                    Spacer(minLength: HSpace.x2)
                    if let room = lesson.roomName, !room.isEmpty {
                        Text(room).font(HType.meta.monospacedDigit()).foregroundStyle(Color.honeySecondary)
                    }
                }
                if !placed.compact {
                    Text(metaLine(lesson))
                        .font(HType.meta)
                        .foregroundStyle(Color.honeySecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, HSpace.x3)
            .padding(.vertical, placed.compact ? 4 : HSpace.x2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).stroke(live ? Color.honeyInk : Color.honeyFrame, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility(lesson))
    }

    private func metaLine(_ lesson: Lesson) -> String {
        var parts: [String] = []
        if let p = placed.periodLabel { parts.append(p) }
        parts.append(Formatters.timeRange(lesson.startsAt, lesson.endsAt))
        if let t = lesson.teacherName, !t.isEmpty { parts.append(t) }
        return parts.joined(separator: " · ")
    }

    private func accessibility(_ lesson: Lesson) -> String {
        [
            live ? L10n.t("Now") : nil,
            lesson.subjectName,
            "\(Formatters.time(lesson.startsAt)) to \(Formatters.time(lesson.endsAt))",
            lesson.teacherName,
            DisplayNames.roomLabel(lesson.roomName),
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
