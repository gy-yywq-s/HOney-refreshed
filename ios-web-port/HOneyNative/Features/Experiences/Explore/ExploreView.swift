// Explore (spec §12): the deliberate lookup mode. Native `.searchable`, a
// four-category control, Recent contexts, the COMPLETE list for the chosen
// category (never "search for the rest"), and — from two characters — the
// published words that mention the query.

import SwiftUI
import HOneyCore

struct ExploreView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var query = ""
    @State private var category: EntityType = .teacher
    @State private var entities: [EntityRef] = []
    @State private var mine: Set<String> = []
    @State private var loading = true
    @State private var error: String?
    @State private var search: SearchResponse?
    @State private var searching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var feed: FeedViewModel?

    private let categories: [(EntityType, String)] = [(.teacher, "Teachers"), (.course, "Courses"), (.room, "Places"), (.dish, "Food")]
    private let groupThreshold = 18

    private var needle: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    var body: some View {
        List {
            if needle.isEmpty {
                if typeSize.isAccessibilitySize {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.0) { Text(L10n.t($0.1)).tag($0.0) }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.0) { Text(L10n.t($0.1)).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: HSpace.x2, leading: HSpace.pageX, bottom: HSpace.x2, trailing: HSpace.pageX))
                    .listRowBackground(Color.clear)
                }
            }
            if let error {
                InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load(reload: true) } }))
                    .listRowBackground(Color.clear)
            }
            if loading, entities.isEmpty {
                LoadingPlaceholder(lines: 6).listRowBackground(Color.clear)
            } else if needle.isEmpty {
                recentSection
                categorySection(category, items: byType(category), count: "\(byType(category).count)")
            } else {
                let matching = categories.filter { !byType($0.0).isEmpty }
                if matching.isEmpty {
                    Text(L10n.t("Nothing by that name.")).foregroundStyle(Color.honeySecondary).listRowBackground(Color.clear)
                }
                ForEach(matching, id: \.0) { type, _ in
                    categorySection(type, items: byType(type), count: "\(byType(type).count) of \(total(type))")
                }
                mentionsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.t("Search names and experiences"))
        .autocorrectionDisabled()
        .task {
            category = env.prefs.exploreCategory
            await load()
        }
        .onChange(of: category) { _, next in env.prefs.exploreCategory = next }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .refreshable { await load(reload: true) }
    }

    // MARK: Data

    @MainActor
    private func load(reload: Bool = false) async {
        loading = entities.isEmpty
        do {
            let repo = env.timetable
            async let ents = repo.entities(reload: reload)
            async let dir = repo.directory(reload: reload)
            let (e, d) = (try await ents, try await dir)
            entities = e.entities.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let known = Set(e.entities.map(\.entityKey))
            var own = Set<String>()
            for t in d.teachers where known.contains("teacher:\(t.id)") { own.insert("teacher:\(t.id)") }
            for c in d.courses where known.contains("course:\(c.id)") { own.insert("course:\(c.id)") }
            mine = own
            error = nil
        } catch {
            if entities.isEmpty { self.error = APIErrorCopy.describe(error) }
        }
        loading = false
    }

    private func byType(_ type: EntityType) -> [EntityRef] {
        entities.filter { $0.type == type && (needle.isEmpty || $0.name.lowercased().contains(needle)) }
    }

    private func total(_ type: EntityType) -> Int { entities.filter { $0.type == type }.count }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            search = nil
            searchError = nil
            searching = false
            return
        }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await env.api.search(q: q)
                guard !Task.isCancelled, q == query.trimmingCharacters(in: .whitespaces) else { return }
                search = result
                searchError = nil
            } catch {
                guard !Task.isCancelled else { return }
                searchError = APIErrorCopy.describe(error)
            }
            searching = false
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var recentSection: some View {
        let recent = env.prefs.recentContexts
        if !recent.isEmpty {
            Section {
                ForEach(recent) { ctx in
                    Button { nav.push(.entity(ctx.type, ctx.entityId)) } label: {
                        EntityRow(title: ctx.name)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(L10n.t("Recently opened")).eyebrow()
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ type: EntityType, items: [EntityRef], count: String) -> some View {
        let label = categories.first { $0.0 == type }?.1 ?? ""
        let markable = items.contains { mine.contains($0.entityKey) } && items.contains { !mine.contains($0.entityKey) }
        Section {
            if items.isEmpty {
                Text(L10n.t("Nothing here yet.")).foregroundStyle(Color.honeySecondary).listRowBackground(Color.clear)
            } else if items.count >= groupThreshold {
                ForEach(letterGroups(items), id: \.0) { letter, list in
                    Text(letter).eyebrow().listRowBackground(Color.clear).listRowSeparator(.hidden)
                    ForEach(list) { entity in row(entity, mark: markable && mine.contains(entity.entityKey)) }
                }
            } else {
                ForEach(items) { entity in row(entity, mark: markable && mine.contains(entity.entityKey)) }
            }
        } header: {
            HStack {
                Text(L10n.t(label)).eyebrow()
                Text(count).font(HType.micro).foregroundStyle(Color.honeyTertiary)
            }
        }
    }

    private func letterGroups(_ items: [EntityRef]) -> [(String, [EntityRef])] {
        var map: [String: [EntityRef]] = [:]
        for e in items {
            let first = e.name.first.map { String($0).uppercased() } ?? "#"
            let key = first.range(of: "^[A-Z]$", options: .regularExpression) != nil ? first : "#"
            map[key, default: []].append(e)
        }
        return map.keys.sorted().map { ($0, map[$0]!) }
    }

    private func row(_ entity: EntityRef, mark: Bool) -> some View {
        let title = DisplayNames.entityTitle(type: entity.type, name: entity.name)
        let meta = DisplayNames.entityMeta(type: entity.type, name: entity.name)
        let caption = [meta, mark ? L10n.t("from your classes") : ""].filter { !$0.isEmpty }.joined(separator: " · ")
        return Button {
            if let route = ExperienceDisplay.route(for: entity) {
                if case .entity(let type, let id) = route {
                    env.prefs.rememberContext(RecentContext(name: title, type: type, entityId: id))
                }
                nav.push(route)
            }
        } label: {
            EntityRow(title: title, caption: caption)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var mentionsSection: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.count >= 2 {
            Section {
                if searching, search == nil {
                    LoadingPlaceholder(lines: 3).listRowBackground(Color.clear)
                } else if let searchError {
                    InlineStatusBanner(text: searchError, tone: .danger, action: (L10n.t("Try again"), { scheduleSearch() })).listRowBackground(Color.clear)
                } else if let search, !search.experiences.isEmpty {
                    ForEach(search.experiences) { exp in
                        ExperiencePostRow(
                            exp: exp,
                            reaction: feed?.reactions[exp.id] ?? ReactionState(exp),
                            onReact: { value in Task { await feedModel().react(exp, value: value) } },
                            onReport: { category in await feedModel().report(exp, category: category) },
                            openEntity: { route in nav.push(route) }
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Text("No experiences mention “\(q)”.").font(HType.meta).foregroundStyle(Color.honeySecondary).listRowBackground(Color.clear)
                }
            } header: {
                Text("Experiences that mention “\(q)”").eyebrow()
            }
        }
    }

    private func feedModel() -> FeedViewModel {
        if let feed { return feed }
        let model = FeedViewModel(env: env, key: FeedKey(scope: .school))
        feed = model
        return model
    }
}
