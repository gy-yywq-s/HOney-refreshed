// History (spec §19): lessons grouped by day in a List with `.searchable`
// and a compact Filters sheet (teacher / course). Whole rows act: browse
// opens Lesson detail, selection mode hands the lesson to the composer.

import SwiftUI
import HOneyCore

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    let selectMode: Bool

    @State private var query = ""
    @State private var debounced = ""
    @State private var teacherId = ""
    @State private var courseId = ""
    @State private var directory: DirectoryResponse?
    @State private var groups: [HistoryDayGroup] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showFilters = false
    @State private var selected: Lesson?
    @State private var searchTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?

    private var filterCount: Int { (teacherId.isEmpty ? 0 : 1) + (courseId.isEmpty ? 0 : 1) }

    var body: some View {
        List {
            if selectMode {
                InlineStatusBanner(text: "Pick the lesson your experience is about.", tone: .info).listRowBackground(Color.clear)
            }
            if loading, groups.isEmpty {
                LoadingPlaceholder(lines: 5).listRowBackground(Color.clear)
            } else if let error {
                InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { reload() })).listRowBackground(Color.clear)
            } else if groups.isEmpty {
                Text("No lessons match.").foregroundStyle(Color.honeySecondary).listRowBackground(Color.clear)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.lessons) { lesson in
                            Button {
                                if selectMode {
                                    nav.push(.compose(.lesson(id: lesson.id, date: group.date)))
                                } else {
                                    selected = lesson
                                }
                            } label: {
                                LessonRow(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text(group.label).eyebrow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.t("Search lessons…"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFilters = true } label: {
                    Label(L10n.t("Filters"), systemImage: filterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(filterCount > 0 ? "\(L10n.t("Filters")), \(filterCount) active" : L10n.t("Filters"))
            }
        }
        .sheet(isPresented: $showFilters) {
            HistoryFiltersSheet(directory: directory, teacherId: $teacherId, courseId: $courseId)
        }
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
        .refreshable { await load(reload: true) }
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

struct HistoryFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let directory: DirectoryResponse?
    @Binding var teacherId: String
    @Binding var courseId: String

    var body: some View {
        NavigationStack {
            Form {
                Picker("Teacher", selection: $teacherId) {
                    Text("All teachers").tag("")
                    ForEach(directory?.teachers ?? []) { Text($0.name).tag($0.id) }
                }
                Picker("Course", selection: $courseId) {
                    Text("All courses").tag("")
                    ForEach(directory?.courses ?? []) { Text(DisplayNames.parseCourseName($0.name).title).tag($0.id) }
                }
                if !teacherId.isEmpty || !courseId.isEmpty {
                    Button("Clear filters") { teacherId = ""; courseId = "" }
                }
            }
            .navigationTitle(L10n.t("Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("Done")) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
