// Timetable (TimetablePage.tsx + features.css `.daynav`; fidelity spec v2
// §12.2): the phone frame — the Day | Week pill centred, the stepper across
// the width with the date as the heading (a tap opens the platform
// calendar), "Back to today" when you left it — then the Day timeline or
// the Week matrix. Pull to refresh re-reads HOney; History and Sync with
// school sit in one overflow control (the phone Web answers them with
// gestures). Day is the cold-launch default.

import SwiftUI
import HOneyCore

struct TimetableRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: TimetableViewModel?
    @State private var showDatePicker = false
    @State private var showReconnect = false

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Timetable")
        .task {
            if model == nil { model = TimetableViewModel(env: env) }
            if !consumeIntent() { await model?.load() }
        }
        .onChange(of: nav.timetableIntent) { _, _ in _ = consumeIntent() }
        .sheet(isPresented: $showReconnect) {
            SchoolLoginSheet(purpose: .reconnect) { Task { await model?.syncWithSchool() } }
        }
    }

    /// Applies a deep link; returns true when it scheduled a load itself.
    @discardableResult
    private func consumeIntent() -> Bool {
        guard let model, let intent = nav.timetableIntent else { return false }
        nav.timetableIntent = nil
        var scheduled = false
        if let view = intent.view, view != model.view {
            model.setView(view)
            scheduled = true
        }
        if let date = intent.date, date != model.date {
            model.setDate(date)
            scheduled = true
        }
        return scheduled
    }

    @ViewBuilder
    private func content(_ model: TimetableViewModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            header(model)
            if let feedback = model.syncFeedback {
                syncBanner(feedback, model)
                    .pageInset()
                    .padding(.bottom, HSpace.x2)
            }
            Group {
                if model.view == .week {
                    WeekTimetableView(model: model) { date in
                        model.setView(.day)
                        model.setDate(date)
                    }
                } else {
                    DayTimetableScreen(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $model.selectedLesson) { lesson in
            LessonDetailSheet(lesson: lesson, showsOpenDay: model.view == .week) { action in
                model.selectedLesson = nil
                switch action {
                case .openDay(let date):
                    model.setView(.day)
                    model.setDate(date)
                case .compose(let target):
                    nav.go(.experiences, [.compose(target)])
                case .entity(let type, let id):
                    nav.go(.experiences, [.entity(type, id)])
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(iso: model.date) { picked in model.setDate(picked) }
        }
    }

    /// `.daynav` on phones: modes centred (with the overflow at the right),
    /// the stepper row, Back to today; 8 pt above, 4 pt below, 8 pt after.
    private func header(_ model: TimetableViewModel) -> some View {
        VStack(spacing: HSpace.x1) {
            ZStack {
                ModePill(
                    options: [(TimetableViewMode.day, L10n.t("Day")), (TimetableViewMode.week, L10n.t("Week"))],
                    selection: Binding(get: { model.view }, set: { model.setView($0) })
                )
                .accessibilityLabel("Timetable view")
                HStack {
                    Spacer()
                    Menu {
                        Button(model.view == .week ? L10n.t("This week") : L10n.t("Today"), systemImage: "calendar") { model.goToday() }
                        Button("History", systemImage: "clock.arrow.circlepath") { nav.push(.history(select: false)) }
                        Button(model.syncBusy ? L10n.t("Syncing with school…") : L10n.t("Sync with school"), systemImage: "arrow.triangle.2.circlepath") {
                            Task { await model.syncWithSchool() }
                        }
                        .disabled(model.syncBusy)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: HSize.icon, weight: .regular))
                            .foregroundStyle(theme.ink)
                            .frame(width: HSize.control, height: HSize.control)
                            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More")
                }
            }
            .padding(.bottom, HSpace.x1)

            // `.daynav__stepper`: ‹ | the date | › in one pill across the width.
            HStack(spacing: 0) {
                Button { model.step(-1) } label: {
                    Text("‹").font(ramp.font(.sectionTitle)).foregroundStyle(theme.ink2)
                        .frame(width: HSize.control).frame(minHeight: HSize.control)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.view == .week ? L10n.t("Previous week") : L10n.t("Previous day"))
                Button { showDatePicker = true } label: {
                    HStack(spacing: HSpace.x2) {
                        Text(model.view == .week
                             ? Formatters.weekRange(monday: model.monday, endOffset: weekEndOffset(model))
                             : Formatters.dayTitle(model.date))
                            .font(ramp.font(.sectionTitle))
                            .tracking(ramp.tracking(.sectionTitle))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.ink2)
                    }
                    .padding(.horizontal, HSpace.x3)
                    .frame(maxWidth: .infinity, minHeight: HSize.control)
                    .overlay(alignment: .leading) { Rectangle().fill(theme.line).frame(width: 1) }
                    .overlay(alignment: .trailing) { Rectangle().fill(theme.line).frame(width: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pick a date")
                .accessibilityAddTraits(.isHeader)
                Button { model.step(1) } label: {
                    Text("›").font(ramp.font(.sectionTitle)).foregroundStyle(theme.ink2)
                        .frame(width: HSize.control).frame(minHeight: HSize.control)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.view == .week ? L10n.t("Next week") : L10n.t("Next day"))
            }
            .background(theme.surfaceSolid, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
            .clipShape(Capsule())

            if model.view == .week ? !model.isThisWeek : !model.isToday {
                Button(model.view == .week ? L10n.t("This week") : L10n.t("Back to today")) { model.goToday() }
                    .buttonStyle(.webSmallGhost)
            }
        }
        .pageInset()
        .padding(.top, HSpace.x2)
        .padding(.bottom, HSpace.x1)
        .padding(.bottom, HSpace.x2)
        .background(theme.surface)
    }

    private func weekEndOffset(_ model: TimetableViewModel) -> Int {
        WeekMatrix(monday: model.monday, days: model.weekDays).endOffset
    }

    @ViewBuilder
    private func syncBanner(_ feedback: TimetableViewModel.SyncFeedback, _ model: TimetableViewModel) -> some View {
        switch feedback {
        case .synced(let n):
            InlineStatusBanner(text: "Synced \(n) lessons from the school portal.", tone: .success, action: ("OK", { model.syncFeedback = nil }))
        case .reconnectRequired:
            InlineStatusBanner(text: "HOney lost its connection to the school portal.", tone: .warning, action: (L10n.t("Reconnect"), { showReconnect = true }))
        case .failed(let message):
            InlineStatusBanner(text: message, tone: .danger, action: ("OK", { model.syncFeedback = nil }))
        }
    }
}

/// The Day mode: the canvas fills the frame (floor 560 pt) and scrolls
/// beneath the frame on short screens, with a smart cold landing.
struct DayTimetableScreen: View {
    let model: TimetableViewModel

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let day = model.day {
                            DayTimelineView(date: day.date, lessons: day.lessons, canvasHeight: max(560, geo.size.height - HSpace.x4)) { lesson in model.selectedLesson = lesson }
                                .pageInset()
                                .onAppear { land(day, proxy: proxy) }
                                .onChange(of: day.date) { _, _ in land(day, proxy: proxy) }
                        } else if let error = model.dayError {
                            InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } })).pageInset()
                        } else {
                            // The selected date's data is not here yet: never another day's.
                            LoadingPlaceholder(lines: 4).pageInset()
                        }
                    }
                    .padding(.bottom, HSpace.x4)
                }
                .refreshable { await model.load(reload: true) }
            }
        }
    }

    /// The running lesson, else the next one still ahead today, else the
    /// first — once per date, and only counted once the scroll target exists.
    private func land(_ day: TimetableResponse, proxy: ScrollViewProxy) {
        guard !model.landedDates.contains(day.date) else { return }
        let layout = DayLayout(lessons: day.lessons)
        let nowMinute = PeriodCatalog.minuteOfDay(HOneyClock.now().epochMillis)
        guard let target = layout.landingLesson(nowMinute: nowMinute, isToday: day.date == Formatters.todayIsoDate()) else {
            model.markLanded(day.date)
            return
        }
        DispatchQueue.main.async {
            proxy.scrollTo("lesson-\(target.id)", anchor: UnitPoint(x: 0, y: 0.18))
            model.markLanded(day.date)
        }
    }
}

/// The platform's own calendar (the Web taps into `<input type="date">`).
struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let iso: String
    let pick: (String) -> Void
    @State private var date: Date

    init(iso: String, pick: @escaping (String) -> Void) {
        self.iso = iso
        self.pick = pick
        _date = State(initialValue: Formatters.parseIsoDate(iso))
    }

    var body: some View {
        WebSheet(title: "Pick a date", onClose: { dismiss() }) {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.calendar, Calendar.schoolLocal)
                .environment(\.timeZone, HOneyClock.timeZone)
                .tint(theme.accent)
            SheetActions {
                Button(L10n.t("Done")) { pick(Formatters.toIsoDate(date)); dismiss() }.buttonStyle(.webBlockPrimary)
            }
        }
        .presentationDetents([.large])
    }
}
