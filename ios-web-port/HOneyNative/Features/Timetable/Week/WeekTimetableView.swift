// The Week overview (WeekView.tsx + features.css `.week*`; fidelity spec v2
// §12.4): a period matrix — Mon–Fri (plus a weekend day only when it has
// lessons, then it scrolls sideways), rows P1–P6 with Lunch/Dinner as
// spanning separators, subject + room per cell, today's column in the
// scheme's tint, the running lesson ink-filled, unplaced lessons listed
// beneath. At accessibility sizes the matrix becomes a day-by-day list.

import SwiftUI
import HOneyCore

struct WeekTimetableView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.dynamicTypeSize) private var typeSize
    let model: TimetableViewModel
    let onOpenDay: (String) -> Void

    private let columnWidth: CGFloat = 66
    private let gutterWidth: CGFloat = 32
    /// The matrix fills the visible height (Gary 2026-09-03: 周课表稍微填满一点
    /// 屏幕): the period rows share what the region leaves below the day
    /// header, clamped so a small phone keeps readable cells and a tall one
    /// does not balloon. Measured on this device, never a per-model guess.
    private static let cellMin: CGFloat = 56
    private static let cellMax: CGFloat = 104
    @State private var cellHeight: CGFloat = 66

    var body: some View {
        let matrix = WeekMatrix(monday: model.monday, days: model.weekDays)
        GeometryReader { geo in
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                if let error = model.weekError, model.weekDays == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } })).pageInset()
                }
                // The selected week's data or a loading matrix — never another week's.
                if typeSize.isAccessibilitySize {
                    accessibleList(matrix)
                } else if matrix.dates.count > 5 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        grid(matrix, fixedColumns: true).padding(.horizontal, 10)
                    }
                } else {
                    grid(matrix, fixedColumns: false).padding(.horizontal, 10)
                }
                if !matrix.unplaced.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Outside the school periods").sectionLabel().padding(.bottom, HSpace.x2)
                        ForEach(Array(matrix.unplaced.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { HairlineDivider() }
                            Button { model.selectedLesson = item.lesson } label: {
                                EntityRow(
                                    title: item.lesson.title,
                                    caption: [Formatters.dayTitle(item.date), Formatters.timeRange(item.lesson.startsAt, item.lesson.endsAt), DisplayNames.roomLabel(item.lesson.roomName)]
                                        .filter { !$0.isEmpty }.joined(separator: " · "),
                                    showsDisclosure: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .pageInset()
                }
            }
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model.load(reload: true) }
        .onAppear { fit(geo.size.height) }
        .onChange(of: geo.size.height) { _, height in fit(height) }
        }
    }

    /// (available − day header − break rows − 4 pt rounding margin) / periods.
    private func fit(_ available: CGFloat) {
        let header: CGFloat = HSize.control + HSpace.x1
        let breaks = CGFloat(PeriodCatalog.bands.filter { !$0.isPeriod }.count) * 26
        let periods = CGFloat(max(1, PeriodCatalog.bands.filter(\.isPeriod).count))
        let next = floor((available - header - breaks - HSpace.x4 - 4) / periods)
        let clamped = min(Self.cellMax, max(Self.cellMin, next))
        if clamped != cellHeight { cellHeight = clamped }
    }

    /// `.week__table`: 2 pt column spacing, no row spacing; the gutter stays.
    private func grid(_ matrix: WeekMatrix, fixedColumns: Bool) -> some View {
        let today = Formatters.todayIsoDate()
        let now = HOneyClock.now().epochMillis
        return Grid(alignment: .topLeading, horizontalSpacing: 2, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: gutterWidth, height: 1)
                ForEach(matrix.dates, id: \.self) { date in
                    Button { onOpenDay(date) } label: {
                        VStack(spacing: 1) {
                            Text(Formatters.weekdayShort(date))
                                .font(ramp.font(.microSemibold))
                                .foregroundStyle(date == today ? theme.accent : theme.ink2)
                            Text("\(Formatters.dayNumber(date))")
                                .font(ramp.font(TypeRole(size: 16, weight: 650, textStyle: .body, tracking: 0, lineHeight: 1)))
                                .monospacedDigit()
                                .foregroundStyle(date == today ? theme.accent : theme.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: HSize.control)
                        .background(date == today ? theme.accentTint : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(Formatters.dayTitle(date))")
                    .padding(.bottom, HSpace.x1)
                    .gridCellUnsizedAxes(fixedColumns ? [] : .horizontal)
                    .frame(width: fixedColumns ? columnWidth : nil)
                }
            }
            ForEach(PeriodCatalog.bands) { band in
                if band.isPeriod {
                    GridRow {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("P\(band.periodNumber ?? 0)").font(ramp.font(.captionBold)).foregroundStyle(theme.accent)
                            Text(PeriodCatalog.minuteLabel(band.start))
                                .font(ramp.font(TypeRole(size: 11, weight: 400, textStyle: .caption2, tracking: 0, lineHeight: 1)))
                                .monospacedDigit()
                                .foregroundStyle(theme.muted)
                        }
                        .padding(.top, HSpace.x2)
                        .frame(width: gutterWidth, height: cellHeight, alignment: .topLeading)
                        .accessibilityHidden(true)
                        ForEach(matrix.dates, id: \.self) { date in
                            let cell = matrix.cell(date: date, band: band)
                            WeekCell(cell: cell, isToday: date == today, isNow: cell.first.map { WeekMatrix.isNow($0, now: now) } ?? false, loading: model.weekDays == nil && model.loading, height: cellHeight) {
                                if let first = cell.first { model.selectedLesson = first }
                            }
                            .frame(width: fixedColumns ? columnWidth : nil)
                        }
                    }
                } else {
                    GridRow {
                        Text("\(band.breakLabel?.replacingOccurrences(of: " Break", with: "") ?? "") · \(PeriodCatalog.minuteLabel(band.start))–\(PeriodCatalog.minuteLabel(band.end))")
                            .font(ramp.font(.microSemibold))
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 26, alignment: .center)
                            .background(theme.tint(theme.palette.accent, 0.06))
                            .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
                            .gridCellColumns(matrix.dates.count + 1)
                    }
                }
            }
        }
    }

    /// A semantically complete alternative when five columns cannot be read.
    private func accessibleList(_ matrix: WeekMatrix) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            ForEach(matrix.dates, id: \.self) { date in
                VStack(alignment: .leading, spacing: 0) {
                    Button { onOpenDay(date) } label: {
                        HStack {
                            Text(Formatters.dayTitle(date)).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                            Spacer()
                            ChevronGlyph()
                        }
                        .frame(minHeight: HSize.control)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ForEach(PeriodCatalog.periods) { band in
                        let cell = matrix.cell(date: date, band: band)
                        if let first = cell.first {
                            Button { model.selectedLesson = first } label: {
                                LessonRow(lesson: first, leading: "P\(band.periodNumber ?? 0)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HairlineDivider()
                }
            }
        }
        .pageInset()
    }
}

/// `.week__cell` + `.week__lesson`: a ruled cell, today's column tinted; a
/// lesson is a bordered cell-ground box (subject 13/600, room micro), the
/// running one ink-filled.
struct WeekCell: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let cell: WeekMatrix.Cell
    let isToday: Bool
    let isNow: Bool
    let loading: Bool
    var height: CGFloat = 66
    let tap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(isToday ? theme.todayColumn : Color.clear)
                .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
            if let first = cell.first {
                Button(action: tap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DisplayNames.compactLessonTitle(first, phone: true))
                            .font(ramp.font(.captionSemibold))
                            .foregroundStyle(isNow ? theme.surface : theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if let room = first.roomName, !room.isEmpty {
                            Text(room)
                                .font(ramp.font(.micro))
                                .monospacedDigit()
                                .foregroundStyle(isNow ? theme.surface.opacity(0.8) : theme.muted)
                                .lineLimit(1)
                        }
                        if cell.extraCount > 0 {
                            Text("+\(cell.extraCount)").font(ramp.font(.microBold)).foregroundStyle(isNow ? theme.surface : theme.accent)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, HSpace.x2)
                    .frame(maxWidth: .infinity, minHeight: height - 4, alignment: .topLeading)
                    .background(isNow ? theme.ink : theme.cell, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(isNow ? theme.ink : theme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                .accessibilityLabel(label(first))
            } else if loading {
                Capsule().fill(theme.soft).frame(height: 14).padding(.horizontal, 5).padding(.top, HSpace.x2)
            } else {
                Color.clear.accessibilityLabel("\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0), free.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
    }

    private func label(_ first: Lesson) -> String {
        [
            "\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0)",
            first.title,
            "\(Formatters.time(first.startsAt)) to \(Formatters.time(first.endsAt))",
            first.teacherName,
            DisplayNames.roomLabel(first.roomName),
            cell.extraCount > 0 ? "and \(cell.extraCount) more" : nil,
            isNow ? L10n.t("Now") : nil,
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
