// Experiences opens to the Stream (spec §11): native title, toolbar
// doorways (Explore · Your notes & posts · Share), the culture line with
// Why one tap away, Your classes | Around school, then raw chronological
// posts parted by hairlines. New posts are a banner, never a yank. The
// reader's position is the top visible post (scrollPosition), restored on
// return and when Home hands over a specific post.

import SwiftUI
import HOneyCore

/// Invitation cadence (spec §11.7): first after `every` posts, at most `max`
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
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle("Experiences")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { nav.push(.explore) } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(L10n.t("Find someone or something"))
                Button { nav.push(.mine) } label: { Image(systemName: "text.book.closed") }
                    .accessibilityLabel(L10n.t("Your notes & posts"))
                Button { nav.push(.compose(nil)) } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel(L10n.t("Share an experience"))
            }
        }
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header(model)
                if model.newAvailable {
                    Button {
                        Task {
                            await model.jumpToNew()
                            scrolledID = model.items.first?.id
                        }
                    } label: {
                        Text(L10n.t("New experiences are available"))
                            .font(HType.secondary.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HSpace.x2)
                            .background(Color.honeyAccentTint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .pageInset()
                    .padding(.bottom, HSpace.x2)
                }

                if model.loading, model.items.isEmpty {
                    LoadingPlaceholder(lines: 6).pageInset()
                } else if let error = model.error, model.items.isEmpty {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.refresh() } }))
                        .pageInset()
                } else if model.items.isEmpty {
                    emptyState(model)
                } else {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, exp in
                        if index > 0 { HairlineDivider().pageInset() }
                        if FeedInvitations.shows(at: index, count: model.items.count) {
                            invitation
                            HairlineDivider().pageInset()
                        }
                        ExperiencePostRow(
                            exp: exp,
                            reaction: model.reactions[exp.id] ?? ReactionState(exp),
                            onReact: { value in Task { await model.react(exp, value: value) } },
                            onReport: { category in await model.report(exp, category: category) },
                            openEntity: { route in nav.push(route) }
                        )
                        .pageInset()
                        .id(exp.id)
                        .onAppear { Task { await model.loadMoreIfNeeded(current: exp) } }
                    }
                    if model.loadingMore {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, HSpace.x4)
                    } else if model.end {
                        Text(L10n.t("You’re all caught up."))
                            .font(HType.meta)
                            .foregroundStyle(Color.honeyTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HSpace.x5)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.bottom, HSpace.x7)
        }
        .scrollPosition(id: $scrolledID)
        .refreshable { await model.refresh() }
        .onChange(of: scrolledID) { _, id in
            if let id, model.items.contains(where: { $0.id == id }) { model.restoreAnchorId = id }
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

    private func header(_ model: FeedViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { cultureLine }
                VStack(alignment: .leading, spacing: 2) { cultureLine }
            }
            Picker("Feed scope", selection: Binding(
                get: { scope },
                set: { next in
                    scope = next
                    Task { await model.switchScope(next) }
                }
            )) {
                Text("Your classes").tag(FeedScope.myClasses)
                Text("Around school").tag(FeedScope.school)
            }
            .pickerStyle(.segmented)
        }
        .pageInset()
        .padding(.bottom, HSpace.x3)
        .id("feed-top")
    }

    @ViewBuilder
    private var cultureLine: some View {
        Text("Written by students, for students.")
            .font(HType.secondary.weight(.semibold))
            .foregroundStyle(Color.honeyInk)
        Button(L10n.t("Why this space exists")) { nav.push(.why) }
            .font(HType.secondary)
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

    private var invitation: some View {
        HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
            Text(L10n.t("Anything from school you want to put into words?"))
                .font(HType.secondary)
                .foregroundStyle(Color.honeySecondary)
            Spacer()
            Button(L10n.t("Share an experience")) { nav.push(.compose(nil)) }
                .font(HType.secondary.weight(.medium))
        }
        .padding(.vertical, HSpace.x3)
        .pageInset()
    }
}
