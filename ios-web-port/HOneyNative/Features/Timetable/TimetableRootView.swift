// Timetable (spec §18.2): a compact custom top frame — Day | Week, the
// overflow menu (Today / History / Sync with school), the date stepper —
// then the Day timeline or the Week matrix. `.refreshable` re-reads HOney;
// Sync with school is the explicit upstream action. Day is the cold-launch
// default; Week is remembered only while the app lives (review §3.4).

import SwiftUI
import HOneyCore

struct TimetableRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
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
        .background(Color.honeyCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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

    private func header(_ model: TimetableViewModel) -> some View {
        VStack(spacing: HSpace.x2) {
            HStack {
                Picker("Timetable view", selection: Binding(get: { model.view }, set: { model.setView($0) })) {
                    Text(L10n.t("Day")).tag(TimetableViewMode.day)
                    Text(L10n.t("Week")).tag(TimetableViewMode.week)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                Spacer()
                if model.view == .week ? !model.isThisWeek : !model.isToday {
                    Button(model.view == .week ? L10n.t("This week") : L10n.t("Back to today")) { model.goToday() }
                        .font(HType.secondary)
                }
                Menu {
                    Button(model.view == .week ? L10n.t("This week") : L10n.t("Today"), systemImage: "calendar") { model.goToday() }
                    Button("History", systemImage: "clock.arrow.circlepath") { nav.push(.history(select: false)) }
                    Button(model.syncBusy ? L10n.t("Syncing with school…") : L10n.t("Sync with school"), systemImage: "arrow.triangle.2.circlepath") {
                        Task { await model.syncWithSchool() }
                    }
                    .disabled(model.syncBusy)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("More")
            }
            HStack {
                Button { model.step(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel(model.view == .week ? L10n.t("Previous week") : L10n.t("Previous day"))
                Spacer()
                Button { showDatePicker = true } label: {
                    HStack(spacing: 6) {
                        Text(model.view == .week
                             ? Formatters.weekRange(monday: model.monday, endOffset: weekEndOffset(model))
                             : Formatters.dayTitle(model.date))
                            .font(HType.pageTitle)
                            .foregroundStyle(Color.honeyInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Color.honeyTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pick a date")
                .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { model.step(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel(model.view == .week ? L10n.t("Next week") : L10n.t("Next day"))
            }
        }
        .pageInset()
        .padding(.top, HSpace.x2)
        .padding(.bottom, HSpace.x2)
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

/// The Day mode: the timeline in a ScrollView with a smart cold landing.
struct DayTimetableScreen: View {
    let model: TimetableViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let day = model.day {
                        DayTimelineView(date: day.date, lessons: day.lessons) { lesson in model.selectedLesson = lesson }
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
                .padding(.bottom, HSpace.x7)
            }
            .refreshable { await model.load(reload: true) }
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

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let iso: String
    let pick: (String) -> Void
    @State private var date: Date

    init(iso: String, pick: @escaping (String) -> Void) {
        self.iso = iso
        self.pick = pick
        _date = State(initialValue: Formatters.parseIsoDate(iso))
    }

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.calendar, Calendar.schoolLocal)
                .environment(\.timeZone, HOneyClock.timeZone)
                .padding()
                .navigationTitle("Pick a date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L10n.t("Done")) { pick(Formatters.toIsoDate(date)); dismiss() } }
                }
        }
        .presentationDetents([.medium])
    }
}
