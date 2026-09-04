// Experiences opens to the Stream (FeedPage.tsx + features.css `.feed-*`,
// `.post`; fidelity spec v2 §7): the page title with the three 44 pt icon
// doorways beside it (Compose ink-filled), the culture line, the scope
// switch, then raw chronological posts parted by hairlines. New posts are a
// quiet pill, never a yank. The reader's position is the top visible post,
// restored on return and when Home hands over a specific post.

import SwiftUI
import HOneyCore

/// Invitation cadence (§7.8): first after `every` posts, at most `max`
/// per reading session, none on a short feed.
enum FeedInvitations {
    static let every = 8
    static let max = 2
    static func shows(at index: Int, count: Int) -> Bool {
        index > 0 && index % every == 0 && index / every <= max && count > every
    }
}

struct ExperiencesFeedView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: FeedViewModel?
    @State private var scope: FeedScope = .myClasses
    @State private var scrolledID: String?

    var body: some View {
        Group {
            if let model {
                stream(model)
            } else {
                LoadingPlaceholder(lines: 6).pageInset()
            }
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Experiences")
        .task {
            if model == nil {
                scope = env.prefs.feedScope
                model = FeedViewModel(env: env, key: FeedKey(scope: scope))
            }
            await model?.enter()
            await consumeIntent()
        }
        .onChange(of: nav.experiencesIntent) { _, _ in Task { await consumeIntent() } }
        .onDisappear { Task { await model?.leave() } }
    }

    private func consumeIntent() async {
        guard let model, let intent = nav.experiencesIntent else { return }
        nav.experiencesIntent = nil
        if let target = intent.scope, target != scope {
            scope = target
            await model.switchScope(target)
        }
        if let anchor = intent.anchorId, model.items.contains(where: { $0.id == anchor }) {
            model.restoreAnchorId = anchor
            scrolledID = anchor
        }
    }

    private func stream(_ model: FeedViewModel) -> some View {
        GeometryReader { scrollGeo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header(model)
                        .padding(.bottom, HSpace.x4)

                    if model.loading, model.items.isEmpty {
                        LoadingPlaceholder(lines: 6).pageInset()
                    } else if let error = model.error, model.items.isEmpty {
                        InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.refresh() } }))
                            .pageInset()
                    } else if model.items.isEmpty {
                        emptyState(model)
                    } else {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, exp in
                            if FeedInvitations.shows(at: index, count: model.items.count) {
                                invitation
                            }
                            ExperiencePostRow(
                                exp: exp,
                                reaction: model.reactionState(for: exp),
                                name: model.name,
                                onReact: { value in Task { await model.react(exp, value: value) } },
                                onReport: { category in await model.report(exp, category: category) },
                                openEntity: { route in nav.push(route) }
                            )
                            .pageInset()
                            .id(exp.id)
                            .onAppear { Task { await model.loadMoreIfNeeded(current: exp) } }
                        }
                        if model.loadingMore {
                            Text("…")
                                .hfont(.body)
                                .foregroundStyle(theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HSpace.x4)
                        } else if model.end {
                            Text(L10n.t("You’re all caught up."))
                                .hfont(.caption)
                                .foregroundStyle(theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HSpace.x4)
                        }
                    }
                }
                .frame(minHeight: scrollGeo.size.height, alignment: .top)
                .scrollTargetLayout()
                .padding(.top, HSpace.x4)
                .padding(.bottom, HSpace.x4)
            }
            .honeyRefreshable { await model.refresh() }
            .scrollPosition(id: $scrolledID)
            .overlay(alignment: .top) {
                if model.newAvailable {
                    // `.feed-new`: a sticky pill 8 pt under the top, never a scroll yank.
                    Button {
                        Task {
                            await model.jumpToNew()
                            scrolledID = model.items.first?.id
                        }
                    } label: {
                        Text(L10n.t("New experiences are available"))
                            .font(ramp.font(.caption))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, HSpace.x4)
                            .padding(.vertical, HSpace.x2)
                            .background(theme.surfaceSolid, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
                            .shadow(color: .black.opacity(0.08), radius: 7, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, HSpace.x2)
                }
            }
            .onChange(of: scrolledID) { _, id in
                if let id, model.items.contains(where: { $0.id == id }) {
                    model.restoreAnchorId = id
                }
            }
            .onChange(of: model.loading) { _, loading in
                // Page one arrived (or was restored): land on the remembered post.
                if !loading, let anchor = model.restoreAnchorId, model.items.contains(where: { $0.id == anchor }) {
                    scrolledID = anchor
                }
            }
            .onAppear {
                if let anchor = model.restoreAnchorId, model.items.contains(where: { $0.id == anchor }) {
                    scrolledID = anchor
                }
            }
        }
    }

    /// `.feed-head`: title row with the tools, the culture line, the scope switch.
    private func header(_ model: FeedViewModel) -> some View {
        let showHeaderShare = model.loading || (model.error == nil && !model.items.isEmpty)
        return VStack(alignment: .leading, spacing: HSpace.x3) {
            HStack(alignment: .center, spacing: HSpace.x3) {
                PageTitle(text: "Experiences")
                HStack(spacing: HSpace.x2) {
                    Button { nav.push(.explore) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.webIcon)
                        .accessibilityLabel(L10n.t("Find someone or something"))
                    Button { nav.push(.mine) } label: { Image(systemName: "bookmark") }
                        .buttonStyle(.webIcon)
                        .accessibilityLabel(L10n.t("Your notes & posts"))
                    if showHeaderShare {
                        Button { nav.push(.compose(nil)) } label: { Image(systemName: "pencil.line") }
                            .buttonStyle(.webIconPrimary)
                            .accessibilityLabel(L10n.t("Share an experience"))
                    }
                }
            }
            cultureLine
            ScopeSwitch(
                options: [(FeedScope.myClasses, "Your classes"), (FeedScope.school, "Around school")],
                selection: Binding(
                    get: { scope },
                    set: { next in
                        scope = next
                        Task { await model.switchScope(next) }
                    }
                )
            )
            .accessibilityLabel("Feed scope")
        }
        .pageInset()
        .id("feed-top")
    }

    /// `.feed-identity`: "**Written by students, for students.** Why this space exists".
    private var cultureLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) { cultureParts }
            VStack(alignment: .leading, spacing: 2) { cultureParts }
        }
    }

    @ViewBuilder
    private var cultureParts: some View {
        Text("Written by students, for students.")
            .font(ramp.font(.secondarySemibold))
            .foregroundStyle(theme.ink)
        Button(L10n.t("Why this space exists")) { nav.push(.why) }
            .buttonStyle(WebLinkStyle(role: .secondary))
            .frame(minHeight: 0)
    }

    private func emptyState(_ model: FeedViewModel) -> some View {
        Group {
            if scope == .myClasses {
                EmptyStateView(title: L10n.t("Nothing from your classes yet."), detail: L10n.t("A small honest note is enough."), action: (L10n.t("Share the first one"), { nav.push(.compose(nil)) }))
            } else {
                EmptyStateView(title: L10n.t("Nothing has been shared yet."), detail: L10n.t("A short thought is enough to begin."), action: (L10n.t("Share an experience"), { nav.push(.compose(nil)) }))
            }
        }
        .pageInset()
    }

    /// `.feed-invite`: a sentence and a small ghost button, ruled beneath.
    private var invitation: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: HSpace.x3) {
                Text(L10n.t("Anything from school you want to put into words?"))
                    .font(ramp.font(.secondary))
                    .foregroundStyle(theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(L10n.t("Share an experience")) { nav.push(.compose(nil)) }
                    .buttonStyle(.webSmallGhost)
            }
            .padding(.vertical, HSpace.x4)
            HairlineDivider()
        }
        .padding(.vertical, HSpace.x1)
        .pageInset()
    }
}
