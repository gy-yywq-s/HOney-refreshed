// Entity pages (EntityPage.tsx; fidelity spec v2 §9): the kind as a
// section label over the page title, "Share your experience" as a
// full-width primary button when the entry is listed, one muted sentence of
// context with descriptive counts (never a score), then the raw stream
// through the same post row.

import SwiftUI
import HOneyCore

struct EntityExperiencesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    let type: EntityType
    let id: String

    @State private var feed: FeedViewModel?
    @State private var names = NameMaps()
    @State private var namesError: String?
    @State private var stats: EntityStatsV2?

    private var entityKey: String { "\(type.rawValue):\(id)" }

    private var kindTitle: String {
        switch type {
        case .teacher: return "Teacher"
        case .course: return "Course"
        case .room: return "Place"
        case .dish: return "Dish"
        case .unknown(let raw): return raw.capitalized
        }
    }

    private var listed: Bool { names.entities.contains { $0.entityKey == entityKey } }

    private var name: String {
        let raw: String?
        switch type {
        case .teacher: raw = names.teacher[id] ?? names.entity[entityKey]
        case .room: raw = names.room[id] ?? names.entity[entityKey]
        case .course: raw = names.course[id] ?? names.entity[entityKey]
        default: raw = names.entity[entityKey]
        }
        return raw ?? kindTitle
    }

    private var neverListed: Bool {
        names.loaded && !listed && names.entity[entityKey] == nil && names.teacher[id] == nil && names.room[id] == nil && names.course[id] == nil
    }

    private var survivor: EntityRef? {
        names.entities.first { $0.type == type && $0.entityKey != entityKey && $0.name == name }
    }

    private var intro: String {
        switch type {
        case .teacher: return "What students have experienced in classes with \(name)."
        case .course: return "Experiences of this course across lessons and teachers."
        case .room: return "What students have experienced in this place."
        default: return "What students thought of it."
        }
    }

    var body: some View {
        Group {
            if neverListed {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    PageTitle(text: "Nothing is listed at this address.")
                    Button(L10n.t("Find someone or something")) { nav.push(.explore) }.buttonStyle(.webPrimary)
                }
                .pageInset()
                .padding(.top, HSpace.x2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let feed {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HSpace.x4) {
                        header
                        posts(feed)
                    }
                    .refreshAnchor()
                    .padding(.top, HSpace.x2)
                    .padding(.bottom, HSpace.x4)
                }
                .honeyRefreshable { await feed.refresh(); await loadNames(reload: true) }
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .webScreen(title: name)
        .task {
            if feed == nil {
                var key = FeedKey(scope: .school)
                switch type {
                case .teacher: key.teacherId = id
                case .room: key.roomId = id
                case .course: key.courseId = id
                default: key.entityKey = entityKey
                }
                feed = FeedViewModel(env: env, key: key)
            }
            await loadNames()
            if let feed { await feed.enter() }
            stats = try? await env.community.stats(entityKey: entityKey)
        }
        .onDisappear { Task { await feed?.leave() } }
    }

    private func loadNames(reload: Bool = false) async {
        do {
            names = try await NameMaps.load(env, reload: reload)
            namesError = nil
            if listed, name != kindTitle {
                env.prefs.rememberContext(RecentContext(name: name, type: type, entityId: id))
            }
        } catch {
            namesError = APIErrorCopy.describe(error)
        }
    }

    /// `.page-head` (wrapping on phones): the label, the title, the button.
    private var header: some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                Text(kindTitle).sectionLabel()
                PageTitle(text: name)
            }
            if listed {
                Button("Share your experience") { nav.push(.compose(.entity(key: entityKey))) }
                    .buttonStyle(.webBlockPrimary)
            }
            if names.loaded, !listed {
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    Text("This entry is no longer listed.").hfont(.body).foregroundStyle(theme.muted)
                    if let survivor {
                        Button("Open the current entry for \(DisplayNames.entityTitle(type: type, name: survivor.name))") {
                            if let route = ExperienceDisplay.route(for: survivor) { nav.push(route) }
                        }
                        .buttonStyle(.webLinkBody)
                    }
                }
            }
            if names.loaded {
                Text(introWithCounts).hfont(.body).foregroundStyle(theme.muted)
            }
            if let namesError {
                InlineStatusBanner(text: namesError, tone: .danger, action: (L10n.t("Try again"), { Task { await loadNames(reload: true) } }))
            }
        }
        .pageInset()
    }

    private var introWithCounts: String {
        var text = "\(intro) No single Experience is the whole picture."
        if let stats, stats.experiences > 0 {
            text += " " + (stats.experiences == 1 ? "1 experience" : "\(stats.experiences) experiences")
            if type == .teacher, stats.courses > 0 {
                text += " across " + (stats.courses == 1 ? "1 course" : "\(stats.courses) courses")
            } else if type == .course, stats.teachers > 0 {
                text += " with " + (stats.teachers == 1 ? "1 teacher" : "\(stats.teachers) teachers")
            }
            text += "."
        }
        return text
    }

    @ViewBuilder
    private func posts(_ feed: FeedViewModel) -> some View {
        if feed.loading, feed.items.isEmpty {
            LoadingPlaceholder(lines: 4).pageInset()
        } else if let error = feed.error, feed.items.isEmpty {
            InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await feed.refresh() } })).pageInset()
        } else if feed.items.isEmpty {
            Text(listed ? "No one has shared an experience here yet." : "No experiences here.")
                .hfont(.body)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: .infinity)
                .padding(HSpace.x6)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(feed.items) { exp in
                    ExperiencePostRow(
                        exp: exp,
                        reaction: feed.reactionState(for: exp),
                        name: feed.name,
                        onReact: { value in Task { await feed.react(exp, value: value) } },
                        onReport: { category in await feed.report(exp, category: category) },
                        openEntity: { route in nav.push(route) }
                    )
                    .pageInset()
                    .onAppear { Task { await feed.loadMoreIfNeeded(current: exp) } }
                }
                if feed.loadingMore {
                    Text("…").hfont(.body).foregroundStyle(theme.muted).frame(maxWidth: .infinity).padding(.vertical, HSpace.x4)
                }
            }
        }
    }
}
