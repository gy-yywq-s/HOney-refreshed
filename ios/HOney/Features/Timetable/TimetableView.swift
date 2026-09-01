//
//  TimetableView.swift
//  HOney — an editorial day canvas: neutral period rhythm, restrained breaks,
//  free-period labels and one precise current-time indicator.
//

import SwiftUI

struct TimetableView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: TimetableViewModel?
    @State private var selectedLesson: Lesson?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if let viewModel {
                        content(viewModel, viewHeight: proxy.size.height)
                    } else {
                        LoadingCard()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel == nil { viewModel = TimetableViewModel(services: model.services) }
                await viewModel?.load()
            }
            .sheet(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson).environment(model)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TimetableViewModel, viewHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            compactHeader(viewModel)

            if let errorMessage = viewModel.errorMessage {
                AppBanner(text: errorMessage, style: .error)
            }

            if viewModel.isLoading && viewModel.lessons.isEmpty {
                LoadingCard()
            } else {
                daySchedule(viewModel, viewHeight: viewHeight)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < 0 { viewModel.goToNextDay() }
                    else if value.translation.width > 0 { viewModel.goToPreviousDay() }
                }
        )
    }

    // MARK: - Header

    private func compactHeader(_ viewModel: TimetableViewModel) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(headerTitle(viewModel))
                    .font(AppTheme.Typography.scheduleHeader)
                    .foregroundStyle(Palette.navy)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: 36, alignment: .leading)

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating timetable")
                }

                Spacer()

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.inkSecondary)
                .disabled(viewModel.isLoading || viewModel.isRefreshing)
                .accessibilityLabel("Refresh timetable")

                NavigationLink {
                    HistoryView()
                } label: {
                    Label("Past lessons", systemImage: "clock.arrow.circlepath")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(Palette.ocean)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Palette.ocean.opacity(0.14), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }

            HStack(spacing: 8) {
                CompactWeekButton(systemImage: "chevron.left") {
                    move(viewModel, byDays: -7)
                }

                WeekJumpControl(rangeTitle: weekRangeTitle(viewModel)) {
                    viewModel.goToToday()
                }

                CompactWeekButton(systemImage: "chevron.right") {
                    move(viewModel, byDays: 7)
                }
            }
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.line, lineWidth: 1)
        )
    }

    private func headerTitle(_ viewModel: TimetableViewModel) -> String {
        let dateTitle = Self.headerDateFormatter.string(from: viewModel.selectedDate)
        if viewModel.isToday {
            return "\(dateTitle) · Today"
        }
        return dateTitle
    }

    private func weekRangeTitle(_ viewModel: TimetableViewModel) -> String {
        let monday = SchoolDayGrid.monday(of: viewModel.selectedDate)
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) ?? monday
        return "\(Self.rangeFormatter.string(from: monday)) – \(Self.rangeFormatter.string(from: sunday))"
    }

    private func move(_ viewModel: TimetableViewModel, byDays days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) else { return }
        viewModel.selectDate(date)
    }

    // MARK: - Day canvas

    private func daySchedule(_ viewModel: TimetableViewModel, viewHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DaySelector(
                monday: SchoolDayGrid.monday(of: viewModel.selectedDate),
                selectedDate: viewModel.selectedDate
            ) { date in
                viewModel.selectDate(date)
            }

            DayTimelineView(
                lessons: viewModel.lessons,
                showsNowLine: viewModel.isToday,
                height: dayTimelineHeight(viewHeight: viewHeight)
            ) { lesson in
                selectedLesson = lesson
            }
        }
    }

    private func dayTimelineHeight(viewHeight: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 116
        let selectorHeight: CGFloat = 48
        let verticalPadding: CGFloat = 16
        let sectionSpacing: CGFloat = 12
        let available = viewHeight - headerHeight - selectorHeight - verticalPadding - sectionSpacing
        return max(260, available)
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - School-day grid

struct PeriodSlot: Identifiable {
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    var id: String {
        "\(startHour):\(startMinute)-\(endHour):\(endMinute)"
    }

    static let standard = [
        PeriodSlot(startHour: 9, startMinute: 0, endHour: 10, endMinute: 20),
        PeriodSlot(startHour: 10, startMinute: 30, endHour: 12, endMinute: 50),
        PeriodSlot(startHour: 13, startMinute: 30, endHour: 14, endMinute: 50),
        PeriodSlot(startHour: 15, startMinute: 0, endHour: 16, endMinute: 20),
        PeriodSlot(startHour: 16, startMinute: 30, endHour: 17, endMinute: 50),
        PeriodSlot(startHour: 18, startMinute: 30, endHour: 19, endMinute: 50)
    ]

    static var dayStartMinute: Int {
        standard.first?.startMinuteOfDay ?? 9 * 60
    }

    static var dayEndMinute: Int {
        20 * 60
    }

    func overlaps(startMinute lessonStart: Int, endMinute lessonEnd: Int) -> Bool {
        lessonStart < endMinuteOfDay && lessonEnd > startMinuteOfDay
    }

    var startMinuteOfDay: Int {
        startHour * 60 + startMinute
    }

    var endMinuteOfDay: Int {
        endHour * 60 + endMinute
    }
}

struct TimelineBand: Identifiable {
    enum Kind {
        case period(Int)
        case longBreak(String)
    }

    let id: String
    let startMinute: Int
    let endMinute: Int
    let kind: Kind

    var color: Color {
        switch kind {
        case .period(let number):
            return number.isMultiple(of: 2) ? Palette.surfaceMuted.opacity(0.48) : Palette.surface
        case .longBreak:
            return Palette.accentSoft.opacity(0.52)
        }
    }

    static var standard: [TimelineBand] {
        [
            TimelineBand(id: "p1", startMinute: 9 * 60, endMinute: 10 * 60 + 30, kind: .period(1)),
            TimelineBand(id: "p2", startMinute: 10 * 60 + 30, endMinute: 12 * 60, kind: .period(2)),
            TimelineBand(id: "lunch", startMinute: 12 * 60, endMinute: 13 * 60 + 30, kind: .longBreak("Lunch Break")),
            TimelineBand(id: "p3", startMinute: 13 * 60 + 30, endMinute: 15 * 60, kind: .period(3)),
            TimelineBand(id: "p4", startMinute: 15 * 60, endMinute: 16 * 60 + 30, kind: .period(4)),
            TimelineBand(id: "p5", startMinute: 16 * 60 + 30, endMinute: 18 * 60, kind: .period(5)),
            TimelineBand(id: "dinner", startMinute: 18 * 60, endMinute: 18 * 60 + 30, kind: .longBreak("Dinner Break")),
            TimelineBand(id: "p6", startMinute: 18 * 60 + 30, endMinute: 20 * 60, kind: .period(6))
        ]
    }
}

/// Pure date → school-day-grid helpers, shared with Home's lesson cards.
enum SchoolDayGrid {
    static func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func periodLabel(start: Date, end: Date) -> String {
        periodLabel(startMinute: minuteOfDay(start), endMinute: minuteOfDay(end))
    }

    static func periodLabel(startMinute: Int, endMinute: Int) -> String {
        let matches = PeriodSlot.standard.enumerated().compactMap { index, slot -> String? in
            slot.overlaps(startMinute: startMinute, endMinute: endMinute) ? "P\(index + 1)" : nil
        }

        if matches.isEmpty {
            return "Custom"
        }

        if matches.count == 1 {
            return matches[0]
        }

        return "\(matches.first ?? "")-\(matches.last ?? "")"
    }

    static func timeRange(start: Date, end: Date) -> String {
        "\(timeFormatter.string(from: start))–\(timeFormatter.string(from: end))"
    }

    static func monday(of date: Date) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return Calendar.current.startOfDay(for: start)
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

extension Lesson {
    var startMinuteOfDay: Int { SchoolDayGrid.minuteOfDay(startsAt) }
    var endMinuteOfDay: Int { SchoolDayGrid.minuteOfDay(endsAt) }
    var periodLabel: String { SchoolDayGrid.periodLabel(startMinute: startMinuteOfDay, endMinute: endMinuteOfDay) }
    var timeRange: String { SchoolDayGrid.timeRange(start: startsAt, end: endsAt) }

    var isCompactTimelineLabel: Bool {
        endMinuteOfDay - startMinuteOfDay <= 55
    }
}

// MARK: - Day selector

private struct DaySelector: View {
    let monday: Date
    let selectedDate: Date
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: monday) ?? monday
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                Button {
                    onSelect(date)
                } label: {
                    VStack(spacing: 3) {
                        Text(Self.weekdayFormatter.string(from: date))
                            .font(AppTheme.Typography.caption2Bold)
                        Text(Self.dayFormatter.string(from: date))
                            .font(AppTheme.Typography.captionSemibold)
                    }
                    .foregroundStyle(isSelected ? Palette.accentForeground : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? Palette.accent : Palette.surface,
                        in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            .stroke(Palette.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}

// MARK: - Day timeline

private struct DayTimelineView: View {
    let lessons: [Lesson]
    let showsNowLine: Bool
    let height: CGFloat
    let onSelectLesson: (Lesson) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            timeLabels

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    timelineBackground(width: proxy.size.width, height: proxy.size.height)
                    timelineGrid(width: proxy.size.width)
                    emptyPeriodLabels(width: proxy.size.width, height: proxy.size.height)
                    breakLabels(width: proxy.size.width, height: proxy.size.height)

                    ForEach(visibleLessons) { lesson in
                        Button {
                            onSelectLesson(lesson)
                        } label: {
                            TimelineLessonBlock(lesson: lesson)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle().inset(by: -12))
                        .accessibilityLabel(lesson.subjectName + ", " + lesson.timeRange + (lesson.roomName.map { ", " + $0 } ?? ""))
                        .frame(width: lessonBlockWidth(in: proxy.size.width), height: blockHeight(for: lesson, in: proxy.size.height))
                        .offset(x: 10, y: blockOffset(for: lesson, in: proxy.size.height))
                    }

                    if lessons.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(AppTheme.Typography.title3)
                                .foregroundStyle(Palette.ocean)
                            Text("No lessons today")
                                .font(AppTheme.Typography.subheadlineSemibold)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: height)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .frame(height: height)
    }

    private var timeLabels: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Self.hourMarks, id: \.self) { minute in
                Text(timeText(forMinute: minute))
                    .font(AppTheme.Typography.captionMedium)
                    .foregroundStyle(Palette.inkSecondary)
                    .offset(y: yPosition(for: minute, in: height) - 8)
            }
        }
        .frame(width: 50, height: height, alignment: .topTrailing)
    }

    private func timelineBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(TimelineBand.standard) { band in
                ZStack(alignment: .topLeading) {
                    band.color

                    Rectangle()
                        .fill(Palette.line.opacity(0.72))
                        .frame(height: 1)
                }
                .frame(width: width, height: periodBandHeight(for: band, in: height))
                .offset(y: yPosition(for: band.startMinute, in: height))
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }

    private func periodBandHeight(for band: TimelineBand, in availableHeight: CGFloat) -> CGFloat {
        max(1, yPosition(for: band.endMinute, in: availableHeight) - yPosition(for: band.startMinute, in: availableHeight))
    }

    private func timelineGrid(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.hourMarks, id: \.self) { minute in
                Rectangle()
                    .fill(Palette.line.opacity(0.70))
                    .frame(width: width, height: 1)
                    .offset(y: yPosition(for: minute, in: height))
            }

            if showsNowLine,
               let nowMinute = currentMinute,
               PeriodSlot.dayStartMinute...PeriodSlot.dayEndMinute ~= nowMinute {
                CurrentTimeLine(width: width)
                    .offset(y: yPosition(for: nowMinute, in: height))
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func emptyPeriodLabels(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(PeriodSlot.standard.enumerated()), id: \.offset) { index, slot in
                if !lessons.contains(where: { slot.overlaps(startMinute: $0.startMinuteOfDay, endMinute: $0.endMinuteOfDay) }) {
                    HStack(spacing: 6) {
                        Text("P\(index + 1)")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(Palette.accent)

                        Text("Free")
                            .font(AppTheme.Typography.captionMedium)
                            .foregroundStyle(Palette.inkSecondary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .offset(y: yPosition(for: slot.startMinuteOfDay, in: height) + 7)
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func breakLabels(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(TimelineBand.standard) { band in
                if case .longBreak(let title) = band.kind {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(AppTheme.Typography.caption2Bold)
                            .foregroundStyle(Palette.accent)

                        Text(title)
                            .font(AppTheme.Typography.captionSemibold)
                            .foregroundStyle(Palette.inkSecondary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .offset(y: yPosition(for: band.startMinute, in: height) + 7)
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func blockOffset(for lesson: Lesson, in availableHeight: CGFloat) -> CGFloat {
        let start = clampedStartMinute(for: lesson)
        return safeDimension(yPosition(for: start, in: availableHeight))
    }

    private func blockHeight(for lesson: Lesson, in availableHeight: CGFloat) -> CGFloat {
        let start = clampedStartMinute(for: lesson)
        let end = clampedEndMinute(for: lesson)
        let rawHeight = yPosition(for: end, in: availableHeight) - yPosition(for: start, in: availableHeight)
        return max(20, safeDimension(rawHeight))
    }

    private var visibleLessons: [Lesson] {
        lessons.filter { lesson in
            clampedEndMinute(for: lesson) > clampedStartMinute(for: lesson)
        }
    }

    private func lessonBlockWidth(in availableWidth: CGFloat) -> CGFloat {
        max(1, safeDimension(availableWidth) - 16)
    }

    private func clampedStartMinute(for lesson: Lesson) -> Int {
        min(max(lesson.startMinuteOfDay, PeriodSlot.dayStartMinute), PeriodSlot.dayEndMinute)
    }

    private func clampedEndMinute(for lesson: Lesson) -> Int {
        min(max(lesson.endMinuteOfDay, PeriodSlot.dayStartMinute), PeriodSlot.dayEndMinute)
    }

    private func safeDimension(_ value: CGFloat) -> CGFloat {
        value.isFinite ? value : 0
    }

    private func yPosition(for minute: Int, in availableHeight: CGFloat) -> CGFloat {
        let clamped = min(max(minute, PeriodSlot.dayStartMinute), PeriodSlot.dayEndMinute)
        let progress = CGFloat(clamped - PeriodSlot.dayStartMinute) / CGFloat(PeriodSlot.dayEndMinute - PeriodSlot.dayStartMinute)
        return progress * max(1, safeDimension(availableHeight))
    }

    private func timeText(forMinute minute: Int) -> String {
        let hour = minute / 60
        return "\(String(format: "%02d", hour)):00"
    }

    private var currentMinute: Int? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return hour * 60 + minute
    }

    private static let hourMarks = Array(stride(from: 9 * 60, through: 20 * 60, by: 60))
}

private struct CurrentTimeLine: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Palette.error)
                .frame(width: 7, height: 7)

            Rectangle()
                .fill(Palette.error)
                .frame(width: max(0, width - 7), height: 1.5)
        }
        .frame(width: width, height: 8, alignment: .leading)
    }
}

private struct TimelineLessonBlock: View {
    let lesson: Lesson

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.ocean)
                .frame(width: 3)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: lesson.isCompactTimelineLabel ? 1 : 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(lesson.subjectName)
                        .font(AppTheme.Typography.lessonTimelineTitle(isCompact: lesson.isCompactTimelineLabel))
                        .foregroundStyle(Palette.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 6)

                    Text(lesson.roomName ?? "")
                        .font(AppTheme.Typography.subheadlineBold)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(lesson.periodLabel)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text("·")

                    Text(lesson.timeRange)
                        .lineLimit(1)
                }
                .font(AppTheme.Typography.lessonTimelineMeta(isCompact: lesson.isCompactTimelineLabel))
                .foregroundStyle(Palette.inkSecondary)
            }
            .padding(.vertical, lesson.isCompactTimelineLabel ? 2 : 4)
            .padding(.trailing, 8)
        }
        .padding(.leading, 6)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CompactWeekButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTheme.Typography.captionBold)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.navy)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .fullHitArea()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(Palette.line, lineWidth: 1)
        )
        .accessibilityLabel(systemImage == "chevron.left" ? "Previous week" : "Next week")
    }
}

private struct WeekJumpControl: View {
    let rangeTitle: String
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Button(action: action) {
                    Label("Today", systemImage: "calendar")
                        .font(AppTheme.Typography.captionBold)
                        .labelStyle(.titleAndIcon)
                        .frame(width: proxy.size.width * 0.36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.accentForeground)
                .background(Palette.accent)
                .fullHitArea()

                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1, height: 44)

                Text(rangeTitle)
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(width: max(0, proxy.size.width * 0.64 - 1), height: 44)
                    .background(Palette.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.line, lineWidth: 1)
            )
        }
        .frame(height: 44)
    }
}

private struct LoadingCard: View {
    var body: some View {
        AppCard(background: Palette.surface) {
            AppLoadingState(title: "Loading schedule")
        }
    }
}
