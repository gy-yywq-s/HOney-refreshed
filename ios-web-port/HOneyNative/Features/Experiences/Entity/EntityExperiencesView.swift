// Entity pages (spec §13): a compact header, one contextual sentence with
// descriptive counts (never a score), raw chronological posts through the
// same post row, and Share only when the entry is listed.

import SwiftUI
import HOneyCore

struct EntityExperiencesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    let type: EntityType
    let id: String

    @State private var feed: FeedViewModel?
    @State private var names = NameMaps()
    @State private var namesError: String?
    @State private var stats: EntityStats?

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
        guard let raw else { return kindTitle }
        return DisplayNames.entityTitle(type: type, name: raw)
    }

    private var neverListed: Bool {
        names.loaded && !listed && names.entity[entityKey] == nil && names.teacher[id] == nil && names.room[id] == nil && names.course[id] == nil
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
                    Text("Nothing is listed at this address.").font(HType.pageTitle).foregroundStyle(Color.honeyInk)
                    Button(L10n.t("Find someone or something")) { nav.push(.explore) }.buttonStyle(.borderedProminent)
                }
                .pageInset()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if let feed {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                        posts(feed)
                    }
                    .padding(.bottom, HSpace.x7)
                }
                .refreshable { await feed.refresh(); await loadNames(reload: true) }
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if listed {
                ToolbarItem(placement: .primaryAction) {
                    Button { nav.push(.compose(.entity(key: entityKey))) } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("Share your experience")
                }
            }
        }
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
            stats = try? await env.api.entityStats(entityKey: entityKey)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            Text(kindTitle).eyebrow()
            Text(name).font(HType.pageTitle).foregroundStyle(Color.honeyInk)
            if names.loaded, !listed {
                Text("This entry is no longer listed.").font(HType.secondary).foregroundStyle(Color.honeySecondary)
            }
            if names.loaded {
                Text(introWithCounts).font(HType.secondary).foregroundStyle(Color.honeySecondary)
            }
            if let namesError {
                InlineStatusBanner(text: namesError, tone: .danger, action: (L10n.t("Try again"), { Task { await loadNames(reload: true) } }))
            }
        }
        .pageInset()
        .padding(.bottom, HSpace.x4)
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
            EmptyStateView(
                title: listed ? "No one has shared an experience here yet." : "No experiences here.",
                action: listed ? ("Share your experience", { nav.push(.compose(.entity(key: entityKey))) }) : nil
            ).pageInset()
        } else {
            HairlineDivider().pageInset()
            ForEach(Array(feed.items.enumerated()), id: \.element.id) { index, exp in
                if index > 0 { HairlineDivider().pageInset() }
                ExperiencePostRow(
                    exp: exp,
                    reaction: feed.reactions[exp.id] ?? ReactionState(exp),
                    onReact: { value in Task { await feed.react(exp, value: value) } },
                    onReport: { category in await feed.report(exp, category: category) },
                    openEntity: { route in nav.push(route) }
                )
                .pageInset()
                .onAppear { Task { await feed.loadMoreIfNeeded(current: exp) } }
            }
            if feed.loadingMore { ProgressView().frame(maxWidth: .infinity).padding(.vertical, HSpace.x4) }
        }
    }
}
