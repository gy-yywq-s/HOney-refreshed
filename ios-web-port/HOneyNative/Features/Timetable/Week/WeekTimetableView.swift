// The Week overview (spec §18.5): a school-period matrix in a native Grid —
// Mon–Fri (plus a weekend day only when it has lessons), rows P1–P6 with
// Lunch/Dinner as spanning separators, subject + room per cell, today
// column tinted, the running lesson emphasised, unplaced lessons listed
// separately. At accessibility sizes the matrix becomes a day-by-day list.

import SwiftUI
import HOneyCore

struct WeekTimetableView: View {
    let model: TimetableViewModel
    let onOpenDay: (String) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private let columnWidth: CGFloat = 66
    private let gutterWidth: CGFloat = 40

    var body: some View {
        let matrix = WeekMatrix(monday: model.monday, days: model.weekDays)
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                if let error = model.weekError, model.weekDays == nil {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } })).pageInset()
                }
                if typeSize.isAccessibilitySize {
                    accessibleList(matrix)
                } else if matrix.dates.count > 5 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        grid(matrix, fixedColumns: true).pageInset()
                    }
                } else {
                    grid(matrix, fixedColumns: false).pageInset()
                }
                if !matrix.unplaced.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Outside the school periods").eyebrow()
                        ForEach(matrix.unplaced) { item in
                            Button { model.selectedLesson = item.lesson } label: {
                                LessonRow(lesson: item.lesson, leading: Formatters.dayTitle(item.date))
                            }
                            .buttonStyle(.plain)
                            HairlineDivider()
                        }
                    }
                    .pageInset()
                }
            }
            .padding(.bottom, HSpace.x7)
        }
        .refreshable { await model.load(reload: true) }
    }

    private func grid(_ matrix: WeekMatrix, fixedColumns: Bool) -> some View {
        let today = Formatters.todayIsoDate()
        let now = HOneyClock.now().epochMillis
        return Grid(alignment: .topLeading, horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Color.clear.frame(width: gutterWidth, height: 1)
                ForEach(matrix.dates, id: \.self) { date in
                    Button { onOpenDay(date) } label: {
                        VStack(spacing: 1) {
                            Text(Formatters.weekdayShort(date)).font(HType.micro).foregroundStyle(Color.honeySecondary)
                            Text("\(Formatters.dayNumber(date))")
                                .font(HType.secondary.weight(.semibold).monospacedDigit())
                                .foregroundStyle(date == today ? Color.honeyOnAccent : Color.honeyInk)
                                .frame(width: 28, height: 28)
                                .background(date == today ? Color.honeyAccent : Color.clear, in: Circle())
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(Formatters.dayTitle(date))")
                    .gridCellUnsizedAxes(fixedColumns ? [] : .horizontal)
                    .frame(width: fixedColumns ? columnWidth : nil)
                }
            }
            ForEach(PeriodCatalog.bands) { band in
                if band.isPeriod {
                    GridRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("P\(band.periodNumber ?? 0)").font(HType.micro.weight(.semibold)).foregroundStyle(Color.honeySecondary)
                            Text(PeriodCatalog.minuteLabel(band.start)).font(.system(size: 10).monospacedDigit()).foregroundStyle(Color.honeyTertiary)
                        }
                        .frame(width: gutterWidth, alignment: .leading)
                        .accessibilityHidden(true)
                        ForEach(matrix.dates, id: \.self) { date in
                            let cell = matrix.cell(date: date, band: band)
                            WeekCell(cell: cell, isToday: date == today, isNow: cell.first.map { WeekMatrix.isNow($0, now: now) } ?? false, loading: model.weekDays == nil && model.weekLoading) {
                                if let first = cell.first { model.selectedLesson = first }
                            }
                            .frame(width: fixedColumns ? columnWidth : nil)
                        }
                    }
                } else {
                    GridRow {
                        Text("\(band.breakLabel?.replacingOccurrences(of: " Break", with: "") ?? "") · \(PeriodCatalog.minuteLabel(band.start))–\(PeriodCatalog.minuteLabel(band.end))")
                            .font(HType.micro)
                            .foregroundStyle(Color.honeySuccess)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 3)
                            .background(Color.honeyBreak, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                        HStack { Text(Formatters.dayTitle(date)).font(HType.body.weight(.semibold)); Spacer(); Image(systemName: "chevron.right").font(.footnote) }
                            .frame(minHeight: 44)
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

struct WeekCell: View {
    let cell: WeekMatrix.Cell
    let isToday: Bool
    let isNow: Bool
    let loading: Bool
    let tap: () -> Void

    var body: some View {
        Group {
            if let first = cell.first {
                Button(action: tap) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(DisplayNames.shortSubjectName(first.subjectName))
                            .font(HType.micro.weight(.semibold))
                            .foregroundStyle(Color.honeyInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if let room = first.roomName, !room.isEmpty {
                            Text(room).font(.system(size: 10).monospacedDigit()).foregroundStyle(Color.honeySecondary).lineLimit(1)
                        }
                        if cell.extraCount > 0 {
                            Text("+\(cell.extraCount)").font(.system(size: 10)).foregroundStyle(Color.honeyTertiary)
                        }
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
                    .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(isNow ? Color.honeyInk : Color.honeyFrame, lineWidth: isNow ? 1.5 : 1))
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(first))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isToday ? Color.honeyAccentTint.opacity(0.5) : Color.honeySoft)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay { if loading { ProgressView().controlSize(.mini) } }
                    .accessibilityLabel("\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0), free.")
            }
        }
    }

    private func label(_ first: Lesson) -> String {
        [
            "\(Formatters.dayTitle(cell.date)), Period \(cell.band.periodNumber ?? 0)",
            first.subjectName,
            "\(Formatters.time(first.startsAt)) to \(Formatters.time(first.endsAt))",
            first.teacherName,
            DisplayNames.roomLabel(first.roomName),
            cell.extraCount > 0 ? "and \(cell.extraCount) more" : nil,
            isNow ? L10n.t("Now") : nil,
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
