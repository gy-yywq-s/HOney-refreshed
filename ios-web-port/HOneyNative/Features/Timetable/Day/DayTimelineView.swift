// The Day timeline (TimetablePage.tsx `DayTimeline` + features.css
// `.timeline*`, `.lesson-block*`; fidelity spec v2 §12.3): the hours gutter,
// a solid rounded canvas with alternating bands, the accent-tinted breaks,
// hairline hour grid, "P3 Free" ghosts on a solid ground, the danger
// now-line, and lesson blocks framed in ink at 28 % — the lesson in
// progress is the one ink-filled block. Geometry comes from HOneyCore.DayLayout.

import SwiftUI
import HOneyCore

struct DayTimelineView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let date: String
    let lessons: [Lesson]
    /// The canvas height: the frame's remaining height, floored at 560.
    var canvasHeight: CGFloat = 560
    let onSelect: (Lesson) -> Void

    private let gutter: CGFloat = 44

    private var layout: DayLayout { DayLayout(lessons: lessons) }
    private var isToday: Bool { date == Formatters.todayIsoDate() }

    var body: some View {
        let layout = layout
        let height = canvasHeight
        VStack(alignment: .leading, spacing: HSpace.x2) {
            if layout.lessons.isEmpty {
                // `.timeline__empty`: in flow, above the canvas.
                HStack(spacing: HSpace.x2) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(theme.accent)
                    Text(isToday ? L10n.t("No lessons today") : "No lessons on \(Formatters.stepperDate(date))")
                        .font(ramp.font(.secondarySemibold))
                        .foregroundStyle(theme.muted)
                }
                .accessibilityAddTraits(.updatesFrequently)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let nowMinute = PeriodCatalog.minuteOfDay(context.date.epochMillis)
                HStack(alignment: .top, spacing: HSpace.x3) {
                    hourGutter(layout, height: height)
                    canvas(layout, height: height, nowMinute: nowMinute)
                }
                .frame(height: height)
                .padding(.top, HSpace.x2) // the first hour label sits 6 pt above the canvas edge
            }
        }
    }

    private func y(_ minute: Int, _ layout: DayLayout, _ height: CGFloat) -> CGFloat {
        CGFloat(layout.range.fraction(minute)) * height
    }

    /// `.timeline__hours`: right-aligned micro labels, 600, muted, tabular.
    private func hourGutter(_ layout: DayLayout, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
            ForEach(layout.range.hourMarks, id: \.self) { minute in
                Text(PeriodCatalog.minuteLabel(minute))
                    .font(ramp.font(.microSemibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.muted)
                    .offset(y: y(minute, layout, height) - 6)
            }
        }
        .frame(width: gutter, height: height, alignment: .topTrailing)
        .accessibilityHidden(true)
    }

    private func canvas(_ layout: DayLayout, height: CGFloat, nowMinute: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Bands: even soft, odd transparent, breaks in the accent's quietest tint; each ruled above.
                ForEach(PeriodCatalog.bands) { band in
                    let fill: Color = band.isPeriod ? ((band.periodNumber ?? 0) % 2 == 0 ? theme.soft : .clear) : theme.breakBand
                    Rectangle()
                        .fill(fill)
                        .frame(width: geo.size.width, height: CGFloat(layout.range.height(from: band.start, to: band.end)) * height)
                        .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
                        .offset(y: y(band.start, layout, height))
                }
                // Hour grid at 55 % of the line.
                ForEach(layout.range.hourMarks, id: \.self) { minute in
                    Rectangle().fill(theme.gridline).frame(width: geo.size.width, height: 1).offset(y: y(minute, layout, height))
                }
                // Free-period ghosts (hidden entirely on an empty day, breaks stay as texture).
                if !layout.lessons.isEmpty {
                    ForEach(layout.freePeriods) { slot in
                        HStack(spacing: HSpace.x2) {
                            ghostLabel(Text("P\(slot.periodNumber ?? 0)").font(ramp.font(.microBold)).foregroundStyle(theme.accent))
                            ghostLabel(Text(L10n.t("Free")).font(ramp.font(TypeRole(size: 12, weight: 500, textStyle: .caption2, tracking: 0.03, lineHeight: 1))).foregroundStyle(theme.muted))
                        }
                        .padding(.leading, HSpace.x3)
                        .offset(y: y(slot.start, layout, height) + 7)
                        .accessibilityHidden(true)
                    }
                }
                // Break labels
                ForEach(PeriodCatalog.breaks) { band in
                    HStack(spacing: HSpace.x2) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                        ghostLabel(Text(band.breakLabel ?? "").font(ramp.font(.microSemibold)).foregroundStyle(theme.muted))
                    }
                    .padding(.leading, HSpace.x3)
                    .offset(y: y(band.start, layout, height) + 7)
                    .accessibilityHidden(true)
                }
                // Lessons: 10 pt from the left, 8 from the right.
                ForEach(layout.lessons) { placed in
                    let top = y(placed.startMinute, layout, height)
                    let blockHeight = max(20, CGFloat(layout.range.height(from: placed.startMinute, to: placed.endMinute)) * height)
                    LessonBlock(placed: placed, live: isToday && layout.isLive(placed, nowMinute: nowMinute)) { onSelect(placed.lesson) }
                        .frame(width: geo.size.width - 18, height: blockHeight)
                        .offset(x: 10, y: top)
                        .id("lesson-\(placed.id)")
                }
                // The now-line: a 7 pt dot and a 1.5 pt rule in the danger colour.
                if isToday, layout.showsNowLine(nowMinute: nowMinute) {
                    HStack(spacing: 0) {
                        Circle().fill(theme.danger).frame(width: 7, height: 7)
                        Rectangle().fill(theme.danger).frame(height: 1.5)
                    }
                    .frame(width: geo.size.width)
                    .offset(y: y(nowMinute, layout, height) - 4)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: height)
        .background(theme.surfaceSolid)
        .clipShape(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.hero, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
    }

    /// `.timeline__ghost > span`: a solid ground so the now-line passes behind.
    private func ghostLabel(_ text: Text) -> some View {
        text
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .padding(.horizontal, -4)
            .padding(.vertical, -2)
    }
}

/// `.lesson-block`: cell ground, 1.5 pt ink-28 % frame, 10 pt radius; the
/// subject at 15/600 with the room (13/700, muted) at the right, then
/// period · time · teacher in micro; compact blocks (< 45 min) drop to micro.
struct LessonBlock: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let placed: PlacedLesson
    let live: Bool
    let tap: () -> Void

    var body: some View {
        let lesson = placed.lesson
        let ink = live ? theme.surface : theme.ink
        let quiet = live ? theme.surface.opacity(0.8) : theme.ink2
        Button(action: tap) {
            VStack(alignment: .leading, spacing: placed.compact ? 0 : HSpace.x1) {
                HStack(alignment: .firstTextBaseline, spacing: HSpace.x2) {
                    Text(lesson.subjectName)
                        .font(ramp.font(placed.compact ? .microSemibold : .secondarySemibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Spacer(minLength: HSpace.x2)
                    if let room = lesson.roomName, !room.isEmpty {
                        Text(room)
                            .font(ramp.font(placed.compact ? .microBold : .captionBold))
                            .foregroundStyle(live ? theme.surface.opacity(0.8) : theme.muted)
                            .lineLimit(1)
                    }
                }
                metaLine(lesson)
                    .font(ramp.font(.micro))
                    .monospacedDigit()
                    .foregroundStyle(quiet)
                    .lineLimit(1)
            }
            .padding(.horizontal, HSpace.x3)
            .padding(.vertical, placed.compact ? HSpace.x1 : HSpace.x2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(live ? theme.ink : theme.cell, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(live ? theme.ink : theme.frame, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility(lesson))
    }

    private func metaLine(_ lesson: Lesson) -> Text {
        var text = Text("")
        if let p = placed.periodLabel { text = text + Text("\(p) · ").fontWeight(.semibold) }
        text = text + Text(Formatters.timeRange(lesson.startsAt, lesson.endsAt))
        if let t = lesson.teacherName, !t.isEmpty { text = text + Text(" · \(t)").fontWeight(.semibold) }
        return text
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
