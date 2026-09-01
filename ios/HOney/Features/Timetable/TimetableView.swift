//
//  TimetableView.swift
//  HOney — explicit date controls and one truthful card per lesson.
//

import SwiftUI

struct TimetableView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: TimetableViewModel?
    @State private var selectedLesson: Lesson?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()

                if let viewModel {
                    content(viewModel)
                } else {
                    LoadingCard()
                        .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel == nil {
                    viewModel = TimetableViewModel(services: model.services)
                }
                await viewModel?.load()
            }
            .sheet(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson).environment(model)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TimetableViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                header(viewModel)

                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        AppBanner(text: errorMessage, style: .error)
                        Button("Try this day again") {
                            Task { await viewModel.refresh() }
                        }
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .frame(minHeight: 44)
                    }
                }

                if viewModel.isLoading && viewModel.lessons.isEmpty {
                    LoadingCard()
                } else {
                    daySchedule(viewModel)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ viewModel: TimetableViewModel) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(headerTitle(viewModel))
                    .font(AppTheme.Typography.scheduleHeader)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(height: 36, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

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
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(Palette.interactiveAccent)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }

            HStack(spacing: 8) {
                CompactDateButton(systemImage: "chevron.left") {
                    move(viewModel, byDays: -1)
                }

                WeekJumpControl(rangeTitle: weekRangeTitle(viewModel)) {
                    viewModel.goToToday()
                }

                CompactDateButton(systemImage: "chevron.right") {
                    move(viewModel, byDays: 1)
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Divider().overlay(Palette.line) }
    }

    private func daySchedule(_ viewModel: TimetableViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DaySelector(
                monday: SchoolDayGrid.monday(of: viewModel.selectedDate),
                selectedDate: viewModel.selectedDate,
                onSelect: viewModel.selectDate
            )

            if viewModel.lessons.isEmpty {
                AppEmptyState(title: "No lessons today", systemImage: "calendar")
                    .padding(.vertical, 24)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.lessons.sorted { $0.startsAt < $1.startsAt }) { lesson in
                            Button {
                                selectedLesson = lesson
                            } label: {
                                TimetableLessonCard(
                                    lesson: lesson,
                                    isToday: viewModel.isToday,
                                    now: context.date
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func headerTitle(_ viewModel: TimetableViewModel) -> String {
        let dateTitle = Self.headerDateFormatter.string(from: viewModel.selectedDate)
        return viewModel.isToday ? dateTitle + " · Today" : dateTitle
    }

    private func weekRangeTitle(_ viewModel: TimetableViewModel) -> String {
        let monday = SchoolDayGrid.monday(of: viewModel.selectedDate)
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) ?? monday
        return Self.rangeFormatter.string(from: monday) + " – " + Self.rangeFormatter.string(from: sunday)
    }

    private func move(_ viewModel: TimetableViewModel, byDays days: Int) {
        guard let date = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: viewModel.selectedDate
        ) else { return }
        viewModel.selectDate(date)
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

// MARK: - School-day helpers

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

    func overlaps(startMinute lessonStart: Int, endMinute lessonEnd: Int) -> Bool {
        lessonStart < endMinuteOfDay && lessonEnd > startMinuteOfDay
    }

    var startMinuteOfDay: Int { startHour * 60 + startMinute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }
}

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

        if matches.isEmpty { return "Custom" }
        if matches.count == 1 { return matches[0] }
        return (matches.first ?? "") + "-" + (matches.last ?? "")
    }

    static func timeRange(start: Date, end: Date) -> String {
        timeFormatter.string(from: start) + "–" + timeFormatter.string(from: end)
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
    var periodLabel: String {
        SchoolDayGrid.periodLabel(startMinute: startMinuteOfDay, endMinute: endMinuteOfDay)
    }
    var timeRange: String { SchoolDayGrid.timeRange(start: startsAt, end: endsAt) }
}

// MARK: - Date controls

private struct DaySelector: View {
    let monday: Date
    let selectedDate: Date
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: monday) ?? monday
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                    Button {
                        onSelect(date)
                    } label: {
                        VStack(spacing: 3) {
                            Text(Self.weekdayFormatter.string(from: date))
                                .font(AppTheme.Typography.caption2Semibold)
                            Text(Self.dayFormatter.string(from: date))
                                .font(AppTheme.Typography.captionSemibold)
                        }
                        .foregroundStyle(isSelected ? Palette.interactiveAccent : Palette.inkSecondary)
                        .frame(width: 44, height: 44)
                        .padding(.vertical, 7)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? Palette.interactiveAccent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.accessibleDateFormatter.string(from: date))
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                }
            }
            .frame(maxWidth: .infinity)
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

    private static let accessibleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}

private struct CompactDateButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(AppTheme.Typography.captionSemibold)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.inkSecondary)
        .fullHitArea()
        .accessibilityLabel(systemImage == "chevron.left" ? "Previous day" : "Next day")
    }
}

private struct WeekJumpControl: View {
    let rangeTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "calendar")
                    .foregroundStyle(Palette.interactiveAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(Palette.ink)
                    Text(rangeTitle)
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to today")
        .accessibilityHint("Current week is " + rangeTitle)
    }
}

// MARK: - Lesson card

private struct TimetableLessonCard: View {
    let lesson: Lesson
    let isToday: Bool
    let now: Date

    private var marker: Color {
        Palette.scheduleMarker(for: lesson.courseName ?? lesson.subjectName)
    }

    private var isCurrent: Bool {
        isToday && lesson.startsAt <= now && now < lesson.endsAt
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.timeFormatter.string(from: lesson.startsAt))
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.ink)
                Text(Self.timeFormatter.string(from: lesson.endsAt))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                Text(periodDescription)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(marker)
                    .padding(.top, 4)
            }
            .frame(width: 58, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(marker)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(lesson.subjectName)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 6)

                    if isCurrent {
                        Text("Now")
                            .font(AppTheme.Typography.captionSemibold)
                            .foregroundStyle(marker)
                    }
                }

                Label(teacherLabel, systemImage: "person")
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(Palette.inkSecondary)

                if let room = normalized(lesson.roomName) {
                    Label(room, systemImage: "mappin")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Palette.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(isCurrent ? marker : Palette.line, lineWidth: isCurrent ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens lesson details")
    }

    private var teacherLabel: String {
        normalized(lesson.teacherName) ?? "Teacher not listed"
    }

    private var periodDescription: String {
        let label = lesson.periodLabel
        guard label.hasPrefix("P") else { return label }
        return "Period " + label.dropFirst().replacingOccurrences(of: "-P", with: "–")
    }

    private var accessibilityText: String {
        var parts = [lesson.subjectName, teacherLabel, lesson.timeRange]
        if let room = normalized(lesson.roomName) { parts.append(room) }
        if isCurrent { parts.append("Now") }
        return parts.joined(separator: ", ")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return cleaned.isEmpty ? nil : cleaned
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct LoadingCard: View {
    var body: some View {
        AppCard(background: Palette.surface.opacity(0.62)) {
            AppLoadingState(title: "Loading schedule")
        }
    }
}
