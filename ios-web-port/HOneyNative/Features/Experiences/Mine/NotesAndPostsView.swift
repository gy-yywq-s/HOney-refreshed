// Your notes & posts (MinePage.tsx + features.css `.mine-*`, `.row--quiet`;
// fidelity spec v2 §11): the page title with the ink-filled Compose icon,
// one quiet row that points at the device-held post controls, then private
// notes and shared posts as hairline rows — context · date, stars, the raw
// words, a status line and small ghost actions. Removal and deletion
// confirm in the Web's sheet.
//
// v2: shared posts are proved by the posting keys derived from the roots on
// this iPhone (no stored per-post key); removal signs with the post's own
// control key; a removed post is deleted outright, so it simply disappears.

import SwiftUI
import HOneyCore

@MainActor
@Observable
final class MineViewModel {
    private let env: AppEnvironment
    private(set) var notes: [PrivateNote] = []
    private(set) var shared: [OwnedPost] = []
    private(set) var names = NameMaps()
    private(set) var loading = true
    private(set) var error: String?
    /// A server vault exists that this iPhone has not restored: posts cannot be listed yet.
    private(set) var restoreNeeded = false
    private(set) var hasControls = false
    var feedback: (tone: BannerTone, text: String)?
    private(set) var busyId: String?

    init(env: AppEnvironment) { self.env = env }

    var isEmpty: Bool { notes.isEmpty && shared.isEmpty && !restoreNeeded }

    func load(reload: Bool = false) async {
        notes = ((try? await env.notes.list()) ?? []).sorted { $0.updatedAt > $1.updatedAt }
        if let maps = try? await NameMaps.load(env, reload: reload) { names = maps }
        guard let account = env.scope?.honeyId else {
            loading = false
            return
        }
        do {
            let status = try await env.postControls.status(account: account)
            switch status {
            case .restoreNeeded:
                restoreNeeded = true
                hasControls = false
                shared = []
            case .none:
                restoreNeeded = false
                hasControls = false
                shared = []
            case .localOnly, .ready:
                restoreNeeded = false
                hasControls = true
                shared = try await env.publish.listOwnedPosts(account: account)
            }
            error = nil
        } catch {
            self.error = APIErrorCopy.describe(error)
        }
        loading = false
    }

    func revoke(_ post: OwnedPost) async {
        guard let account = env.scope?.honeyId else { return }
        busyId = post.id
        feedback = nil
        do {
            try await env.publish.revoke(account: account, post: post)
            await env.feedStore.invalidateAll()
            feedback = (.success, MineStatusCopy.removed)
            await load(reload: false)
        } catch let error as PublishError where error == .rootNotOnThisDevice {
            feedback = (.danger, MineStatusCopy.rootNotHere)
        } catch {
            feedback = (.danger, MineStatusCopy.removeFailed)
        }
        busyId = nil
    }

    func deleteNote(_ id: String) async {
        do {
            try await env.notes.remove(id: id)
            notes.removeAll { $0.id == id }
        } catch {
            feedback = (.danger, "Could not delete the note on this iPhone.")
        }
    }
}

struct NotesAndPostsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: MineViewModel?
    @State private var revoking: OwnedPost?
    @State private var deleting: PrivateNote?

    var body: some View {
        Group {
            if let model {
                list(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .webScreen(title: L10n.t("Your notes & posts"))
        .task {
            if model == nil { model = MineViewModel(env: env) }
            await model?.load()
        }
    }

    private func list(_ model: MineViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                HStack(alignment: .center, spacing: HSpace.x4) {
                    PageTitle(text: L10n.t("Your notes & posts"))
                    if !model.isEmpty {
                        Button { nav.push(.compose(nil)) } label: { Image(systemName: "pencil.line") }
                            .buttonStyle(.webIconPrimary)
                            .accessibilityLabel(L10n.t("Share an experience"))
                    }
                }
                if model.hasControls {
                    // `.row.row--quiet`: one low-priority line to the controls.
                    Button { nav.push(.settingsPostControls) } label: {
                        HStack(spacing: HSpace.x4) {
                            Text(L10n.t("Post controls are stored on this device."))
                                .font(ramp.font(.captionMedium))
                                .foregroundStyle(theme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: HSpace.x1) {
                                Text(L10n.t("Manage")).font(ramp.font(.captionSemibold))
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(theme.accent)
                        }
                        .padding(.vertical, HSpace.x2)
                        .frame(minHeight: HSize.control)
                        .overlay(alignment: .bottom) { HairlineDivider() }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if model.restoreNeeded {
                    InlineStatusBanner(text: PostControlsCopy.restoreExplain, tone: .warning, action: (L10n.t("Restore"), { nav.push(.settingsPostControls) }))
                }
                if let feedback = model.feedback {
                    InlineStatusBanner(text: feedback.text, tone: feedback.tone)
                }
                if model.isEmpty, !model.loading {
                    EmptyStateView(title: L10n.t("Nothing here yet."), detail: L10n.t("Keep something private or share an Experience when you are ready."), action: (L10n.t("Share an experience"), { nav.push(.compose(nil)) }))
                } else if model.loading, model.isEmpty {
                    LoadingPlaceholder(lines: 4)
                } else if let error = model.error {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } }))
                } else {
                    if !model.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.t("Private notes")).sectionLabel().padding(.bottom, HSpace.x1)
                            ForEach(Array(model.notes.enumerated()), id: \.element.id) { index, note in
                                PrivateNoteRowView(note: note, first: index == 0, open: { nav.push(.compose(.note(id: note.id))) }, delete: { deleting = note })
                            }
                        }
                    }
                    if !model.shared.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.t("Shared")).sectionLabel().padding(.bottom, HSpace.x1)
                            ForEach(Array(model.shared.enumerated()), id: \.element.id) { index, post in
                                SharedRowView(post: post, label: model.names.targetLabel(post.experience), first: index == 0, busy: model.busyId == post.id) {
                                    revoking = post
                                }
                            }
                        }
                    }
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model.load(reload: true) }
        .sheet(item: $revoking) { post in
            ConfirmSheet(
                title: L10n.t("Remove this post?"),
                message: L10n.t("The post disappears for everyone and its text is deleted. You can write a new one about this later. This cannot be undone."),
                confirmLabel: "Remove post",
                danger: true,
                busy: model.busyId == post.id,
                onCancel: { revoking = nil },
                onConfirm: {
                    Task { await model.revoke(post) }
                    revoking = nil
                }
            )
        }
        .sheet(item: $deleting) { note in
            ConfirmSheet(
                title: L10n.t("Delete this private note?"),
                message: L10n.t("The note exists only on this device; deleting it cannot be undone."),
                confirmLabel: "Delete note",
                danger: true,
                onCancel: { deleting = nil },
                onConfirm: {
                    Task { await model.deleteNote(note.id) }
                    deleting = nil
                }
            )
        }
    }
}

/// `.mine-item`: context · date, stars, the words, the status and actions.
private struct MineItemFrame<Content: View>: View {
    let first: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            if !first { HairlineDivider() }
            content()
        }
        .padding(.vertical, HSpace.x4)
    }
}

struct PrivateNoteRowView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let note: PrivateNote
    var first = false
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let remaining = (note.cooldown?.until ?? 0) - context.date.epochMillis
            let cooling = note.cooldown != nil && remaining > 0
            let paused = note.cooldown != nil && remaining <= 0
            MineItemFrame(first: first) {
                HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
                    Text(note.target.label).font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2).lineLimit(2)
                    Spacer(minLength: 0)
                    Text(Formatters.coarseDate(note.updatedAt)).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                }
                if let rating = note.rating { StarsView(value: rating) }
                Text(note.body).hfont(.reading).foregroundStyle(theme.ink).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .center, spacing: HSpace.x3) {
                    Group {
                        if cooling {
                            Text("\(L10n.t("Cooling · you can share this in")) \(Formatters.remaining(remaining))").font(ramp.font(.captionSemibold)).foregroundStyle(theme.accent)
                        } else if paused {
                            Text(L10n.t("Pause over · ready to share")).font(ramp.font(.caption)).foregroundStyle(theme.ok)
                        } else {
                            Text(L10n.t("Private · only on this device")).font(ramp.font(.caption)).foregroundStyle(theme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: HSpace.x1) {
                        Button(paused ? L10n.t("Share now") : cooling ? L10n.t("Edit") : L10n.t("Edit / share"), action: open)
                            .buttonStyle(paused ? .webSmallPrimary : .webSmallGhost)
                        Button(L10n.t("Delete"), action: delete).buttonStyle(.webSmallGhost)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct SharedRowView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let post: OwnedPost
    let label: String
    var first = false
    let busy: Bool
    let revoke: () -> Void

    var body: some View {
        let exp = post.experience
        let meta = MineStatusCopy.meta(exp.status)
        MineItemFrame(first: first) {
            HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
                Text(label).font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2).lineLimit(2)
                Spacer(minLength: 0)
                Text(Formatters.coarseDate(exp.createdAt)).font(ramp.font(.caption)).foregroundStyle(theme.muted)
            }
            if let rating = exp.rating { StarsView(value: rating) }
            if let body = exp.body {
                Text(body).hfont(.reading).foregroundStyle(theme.ink).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L10n.t("(no text)")).hfont(.body).foregroundStyle(theme.muted)
            }
            if !meta.explain.isEmpty { Text(meta.explain).hfont(.caption).foregroundStyle(theme.muted) }
            if let detail = exp.statusDetail, !detail.isEmpty { Text(detail).hfont(.caption).foregroundStyle(theme.muted) }
            HStack(alignment: .center, spacing: HSpace.x3) {
                Text("\(meta.label) · \(ExperienceDisplay.provenanceLabel(exp.provenance))")
                    .font(ramp.font(.caption))
                    .foregroundStyle(meta.tone == .ok ? theme.ok : meta.tone == .danger ? theme.danger : theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(L10n.t("Remove…"), action: revoke).buttonStyle(.webSmallGhost).disabled(busy)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
