// History (HistoryPage.tsx + features.css `.filters`, `.day-group`,
// `.history-row`): the page title, the search field with the two filter
// selects on one row beneath, then lessons grouped by day — the day as a
// ruled heading, each row subject + teacher · room with the start time at
// the right. Every row leads to the composer — History IS the picker (Gary
// 2026-09-03), a chevron says so; `select` only explains why you are here.

import SwiftUI
import HOneyCore

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let selectMode: Bool

    @State private var query = ""
    @State private var debounced = ""
    @State private var teacherId = ""
    @State private var courseId = ""
    @State private var directory: DirectoryResponse?
    @State private var groups: [HistoryDayGroup] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selected: Lesson?
    @State private var searchTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                PageTitle(text: "History").padding(.bottom, HSpace.x4)
                if selectMode {
                    InlineStatusBanner(text: L10n.t("Pick the lesson your experience is about."), tone: .success)
                        .padding(.bottom, HSpace.x4)
                }
                Section {
                    if loading, groups.isEmpty {
                        LoadingPlaceholder(lines: 5)
                    } else if let error {
                        InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { reload() }))
                    } else if groups.isEmpty {
                        Text(L10n.t("No lessons match."))
                            .hfont(.body)
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(HSpace.x6)
                            .webCard()
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(group.label)
                                    .font(ramp.font(TypeRole(size: 15, weight: 650, textStyle: .subheadline, tracking: 0, lineHeight: 1.4)))
                                    .foregroundStyle(theme.ink)
                                    .padding(.bottom, HSpace.x2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .bottom) { HairlineDivider() }
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(Array(group.lessons.enumerated()), id: \.element.id) { index, lesson in
                                    if index > 0 { HairlineDivider() }
                                    // `.history-row__link`: the row itself is the way to
                                    // the composer; a long press still opens the lesson.
                                    Button {
                                        nav.push(.compose(.lesson(id: lesson.id, date: group.date)))
                                    } label: {
                                        HStack(alignment: .center, spacing: HSpace.x4) {
                                            VStack(alignment: .leading, spacing: HSpace.x1) {
                                                Text(lesson.title).font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                                                let who = [lesson.teacherName, DisplayNames.roomLabel(lesson.roomName)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                                                if !who.isEmpty {
                                                    Text(who).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            Text(Formatters.time(lesson.startsAt))
                                                .font(ramp.font(.secondarySemibold))
                                                .monospacedDigit()
                                                .foregroundStyle(theme.ink2)
                                            ChevronGlyph()
                                        }
                                        .padding(.vertical, HSpace.x3)
                                        .frame(minHeight: HSize.row)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(L10n.t("Share what this was like")) — \(lesson.title)")
                                    .contextMenu {
                                        Button(L10n.t("More lesson details")) { selected = lesson }
                                    }
                                }
                            }
                            .padding(.bottom, HSpace.x5)
                        }
                    }
                } header: {
                    filters
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load(reload: true) }
        .webScreen(title: "History")
        .sheet(item: $selected) { lesson in
            LessonDetailSheet(lesson: lesson, showsOpenDay: true) { action in
                selected = nil
                switch action {
                case .openDay(let date):
                    nav.timetableIntent = TimetableIntent(date: date, view: .day)
                    nav.go(.timetable)
                case .compose(let target): nav.push(.compose(target))
                case .entity(let type, let id): nav.push(.entity(type, id))
                }
            }
        }
        .task {
            directory = try? await env.timetable.directory()
            reload()
        }
        .onChange(of: query) { _, next in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                debounced = next.trimmingCharacters(in: .whitespaces)
            }
        }
        .onChange(of: debounced) { _, _ in reload() }
        .onChange(of: teacherId) { _, _ in reload() }
        .onChange(of: courseId) { _, _ in reload() }
    }

    /// `.filters` on phones: the search full width, the two selects sharing a row.
    private var filters: some View {
        VStack(spacing: HSpace.x2) {
            TextField("", text: $query, prompt: Text(L10n.t("Search lessons…")).foregroundStyle(theme.muted))
                .textFieldStyle(.web)
                .autocorrectionDisabled()
                .accessibilityLabel(L10n.t("Search lessons…"))
            HStack(spacing: HSpace.x2) {
                SelectField(label: L10n.t("Filter by teacher"), allLabel: "All teachers", selection: $teacherId, options: (directory?.teachers ?? []).map { ($0.id, $0.name) })
                SelectField(label: L10n.t("Filter by course"), allLabel: "All courses", selection: $courseId, options: (directory?.courses ?? []).map { ($0.id, $0.name) })
            }
        }
        .padding(.bottom, HSpace.x5)
        .background(theme.surface)
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await load(reload: false) }
    }

    private func load(reload: Bool) async {
        let params = HistoryParams(q: debounced.isEmpty ? nil : debounced, teacherId: teacherId.isEmpty ? nil : teacherId, courseId: courseId.isEmpty ? nil : courseId, limit: 200, order: .desc)
        loading = groups.isEmpty
        do {
            let response = try await env.timetable.history(params, reload: reload)
            guard !Task.isCancelled else { return }
            groups = HistoryGrouping.groupByDay(response.lessons)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = APIErrorCopy.describe(error)
        }
        loading = false
    }
}

/// A `<select class="input">`: the field's frame with the chosen option
/// and a caret; every option in one native menu.
struct SelectField: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let label: String
    let allLabel: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                Text(allLabel).tag("")
                ForEach(options, id: \.0) { id, name in Text(name).tag(id) }
            }
        } label: {
            HStack(spacing: HSpace.x2) {
                Text(options.first { $0.0 == selection }?.1 ?? allLabel)
                    .font(ramp.font(.body))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, HSpace.x3)
            .frame(minHeight: HSize.control)
            .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        }
        .accessibilityLabel(label)
    }
}
