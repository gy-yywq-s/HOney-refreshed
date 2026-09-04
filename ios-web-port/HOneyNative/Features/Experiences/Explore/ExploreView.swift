// Explore (ExplorePage.tsx + features.css `.explore-*`, `.chip-tab`,
// `.entity-row`; fidelity spec v2 §8): the page title and its support line,
// the Web search field, the four category chips (every one visible), Recent
// or the COMPLETE list for the chosen category (never "search for the
// rest"), and — from two characters — the experiences that mention the
// words, through the same post row as the Stream. The field and chips stay
// in the frame while the results scroll.

import SwiftUI
import HOneyCore

struct ExploreView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
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
    private var searchQ: String {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.count >= 2 ? q : ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HSpace.x4, pinnedViews: [.sectionHeaders]) {
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    PageTitle(text: "Explore")
                    Text(L10n.t("Teachers, courses, places and food."))
                        .hfont(.body)
                        .foregroundStyle(theme.muted)
                }
                .pageInset()
                .padding(.top, HSpace.x2)

                Section {
                    if let error {
                        InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await load(reload: true) } }))
                            .pageInset()
                    }
                    VStack(alignment: .leading, spacing: HSpace.x4) {
                        if loading, entities.isEmpty {
                            LoadingPlaceholder(lines: 6)
                        } else if error == nil, needle.isEmpty {
                            recentSection
                            categorySection(category, items: byType(category), count: "\(total(category))")
                        } else if error == nil {
                            let matching = categories.filter { !byType($0.0).isEmpty }
                            if matching.isEmpty {
                                Text(L10n.t("Nothing by that name."))
                                    .hfont(.body)
                                    .foregroundStyle(theme.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(HSpace.x6)
                            }
                            ForEach(matching, id: \.0) { type, _ in
                                categorySection(type, items: byType(type), count: "\(byType(type).count) of \(total(type))")
                            }
                        }
                        if !searchQ.isEmpty { mentionsSection }
                    }
                    .pageInset()
                } header: {
                    frame
                }
            }
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await load(reload: true) }
        .webScreen(title: "Explore")
        .task {
            category = env.prefs.exploreCategory
            await load()
        }
        .onChange(of: category) { _, next in env.prefs.exploreCategory = next }
        .onChange(of: query) { _, _ in scheduleSearch() }
    }

    /// `.explore-frame`: the field, then the chips while nothing is typed.
    private var frame: some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            SearchField(text: $query, prompt: L10n.t("Search names and experiences"))
            if needle.isEmpty {
                FlowLayout(spacing: HSpace.x2) {
                    ForEach(categories, id: \.0) { type, label in
                        ChipTab(label: L10n.t(label), selected: category == type) { category = type }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Category")
            }
        }
        .pageInset()
        .padding(.bottom, HSpace.x2)
        .background(theme.surface)
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
                feedModel().seed(result.experiences)
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
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.t("Recently opened")).sectionLabel().padding(.bottom, HSpace.x2)
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, ctx in
                    if index > 0 { HairlineDivider() }
                    Button { nav.push(.entity(ctx.type, ctx.entityId)) } label: {
                        EntityRow(title: ctx.name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// `ExploreSection`: label + count, then the complete list, letter
    /// landmarks once it is long enough (and mostly Latin).
    @ViewBuilder
    private func categorySection(_ type: EntityType, items: [EntityRef], count: String) -> some View {
        let label = categories.first { $0.0 == type }?.1 ?? ""
        let markable = items.contains { mine.contains($0.entityKey) } && items.contains { !mine.contains($0.entityKey) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: HSpace.x1) {
                Text(L10n.t(label)).sectionLabel()
                Text(count).hfont(.caption).foregroundStyle(theme.muted)
            }
            .padding(.bottom, HSpace.x2)
            if items.isEmpty {
                Text(L10n.t("Nothing here yet."))
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(HSpace.x6)
            } else if items.count >= groupThreshold, Self.mostlyLatin(items) {
                ForEach(letterGroups(items), id: \.0) { letter, list in
                    HStack(alignment: .top, spacing: HSpace.x2) {
                        Text(letter)
                            .hfont(.captionBold)
                            .foregroundStyle(theme.ink3)
                            .frame(width: 28, alignment: .leading)
                            .padding(.top, HSpace.x3)
                        VStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, entity in
                                if index > 0 { HairlineDivider() }
                                row(entity, mark: markable && mine.contains(entity.entityKey))
                            }
                        }
                    }
                    .padding(.bottom, HSpace.x1)
                }
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, entity in
                    if index > 0 { HairlineDivider() }
                    row(entity, mark: markable && mine.contains(entity.entityKey))
                }
            }
        }
    }

    /// Letter landmarks only help when the names start with letters; a
    /// Chinese directory would collapse into one "#" group (review §4.12).
    static func mostlyLatin(_ items: [EntityRef]) -> Bool {
        let latin = items.filter { ($0.name.first?.isLetter ?? false) && ($0.name.first?.isASCII ?? false) }.count
        return Double(latin) >= Double(items.count) * 0.8
    }

    private func letterGroups(_ items: [EntityRef]) -> [(String, [EntityRef])] {
        var map: [String: [EntityRef]] = [:]
        for e in items {
            let first = e.name.first.map { String($0).uppercased() } ?? "#" // case-allowed: a letter landmark is content, not a label style
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
    }

    /// `.explore-mentions`: the label, then the same post rows as the Stream.
    @ViewBuilder
    private var mentionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Experiences that mention “\(searchQ)”").sectionLabel().padding(.bottom, HSpace.x2)
            if searching, search == nil {
                LoadingPlaceholder(lines: 4)
            } else if let searchError {
                InlineStatusBanner(text: searchError, tone: .danger, action: (L10n.t("Try again"), { scheduleSearch() }))
            } else if let search, !search.experiences.isEmpty {
                ForEach(search.experiences) { exp in
                    ExperiencePostRow(
                        exp: exp,
                        reaction: feed?.reactions[exp.id] ?? ReactionState(exp),
                        onReact: { value in Task { await feedModel().react(exp, value: value) } },
                        onReport: { category in await feedModel().report(exp, category: category) },
                        openEntity: { route in nav.push(route) }
                    )
                }
                .padding(.top, -HSpace.x2)
            } else {
                Text("No experiences mention “\(searchQ)”.").hfont(.caption).foregroundStyle(theme.muted)
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
