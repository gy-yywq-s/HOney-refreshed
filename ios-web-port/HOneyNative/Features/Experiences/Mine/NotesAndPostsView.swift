// Your notes & posts (MinePage.tsx + features.css `.mine-*`, `.row--quiet`;
// fidelity spec v2 §11): the page title with the ink-filled Compose icon,
// one quiet row that points at the device-held controls, then private
// notes and shared posts as hairline rows — context · date, stars, the raw
// words, a status line and small ghost actions. Removal and deletion
// confirm in the Web's sheet.

import SwiftUI
import HOneyCore

@MainActor
@Observable
final class MineViewModel {
    private let env: AppEnvironment
    private(set) var keys: [StoredOwnershipKey] = []
    private(set) var notes: [PrivateNote] = []
    private(set) var shared: [MyExperience] = []
    private(set) var names = NameMaps()
    private(set) var loading = true
    private(set) var error: String?
    var feedback: (tone: BannerTone, text: String)?
    private(set) var busyKey: String?

    init(env: AppEnvironment) { self.env = env }

    var orphanKeys: [StoredOwnershipKey] {
        guard !loading, error == nil else { return [] }
        let found = Set(shared.map(\.id))
        return keys.filter { !found.contains($0.experienceId) }
    }

    var isEmpty: Bool { keys.isEmpty && notes.isEmpty }

    func load(reload: Bool = false) async {
        keys = (try? env.keys.list()) ?? []
        notes = ((try? await env.notes.list()) ?? []).sorted { $0.updatedAt > $1.updatedAt }
        if let maps = try? await NameMaps.load(env, reload: reload) { names = maps }
        do {
            if keys.isEmpty {
                shared = []
            } else {
                shared = try await env.api.myExperiences(keys: keys.map(\.key)).experiences.sorted { $0.createdAt > $1.createdAt }
            }
            error = nil
        } catch {
            self.error = APIErrorCopy.describe(error)
        }
        loading = false
    }

    func key(for exp: MyExperience) -> String? { keys.first { $0.experienceId == exp.id }?.key }

    func revoke(_ ownershipKey: String) async {
        busyKey = ownershipKey
        feedback = nil
        do {
            _ = try await env.api.revokeExperience(ownershipKey: ownershipKey)
            await env.feedStore.invalidateAll()
            feedback = (.success, "Removed. The post is gone — you can write a new one about this any time.")
            await load(reload: false)
        } catch {
            feedback = (.danger, "Could not remove the post. Please try again.")
        }
        busyKey = nil
    }

    func deleteNote(_ id: String) async {
        do {
            try await env.notes.remove(id: id)
            notes.removeAll { $0.id == id }
        } catch {
            feedback = (.danger, "Could not delete the note on this iPhone.")
        }
    }

    func forgetOrphans() {
        for k in orphanKeys { try? env.keys.remove(key: k.key) }
        keys = (try? env.keys.list()) ?? []
    }
}

struct NotesAndPostsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: MineViewModel?
    @State private var revoking: String?
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
                if !model.keys.isEmpty {
                    // `.row.row--quiet`: one low-priority line to the controls.
                    Button { nav.push(.settingsPrivacy) } label: {
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
                            ForEach(Array(model.shared.enumerated()), id: \.element.id) { index, exp in
                                SharedRowView(exp: exp, label: model.names.targetLabel(exp), first: index == 0, busy: model.busyKey == model.key(for: exp), canRevoke: exp.status != .revoked && model.key(for: exp) != nil) {
                                    revoking = model.key(for: exp)
                                }
                            }
                        }
                    }
                    if !model.orphanKeys.isEmpty {
                        let n = model.orphanKeys.count
                        InlineStatusBanner(
                            text: n == 1 ? "1 stored post control no longer matches a post on the server." : "\(n) stored post controls no longer match a post on the server.",
                            tone: .warning,
                            action: ("Forget \(n > 1 ? "them" : "it")", { model.forgetOrphans() })
                        )
                    }
                }
            }
            .refreshAnchor()
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model.load(reload: true) }
        .sheet(isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } })) {
            ConfirmSheet(
                title: "Remove this post?",
                message: "The post disappears for everyone and its text is deleted. You can write a new one about this later. This cannot be undone.",
                confirmLabel: "Remove post",
                danger: true,
                busy: model.busyKey != nil && model.busyKey == revoking,
                onCancel: { revoking = nil },
                onConfirm: {
                    if let key = revoking { Task { await model.revoke(key) } }
                    revoking = nil
                }
            )
        }
        .sheet(item: $deleting) { note in
            ConfirmSheet(
                title: "Delete this private note?",
                message: "The note exists only on this device; deleting it cannot be undone.",
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
    let exp: MyExperience
    let label: String
    var first = false
    let busy: Bool
    let canRevoke: Bool
    let revoke: () -> Void

    var body: some View {
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
                Text(exp.status == .revoked ? "(text deleted when you removed this post)" : "(no text)").hfont(.body).foregroundStyle(theme.muted)
            }
            if !meta.explain.isEmpty { Text(meta.explain).hfont(.caption).foregroundStyle(theme.muted) }
            if let detail = exp.statusDetail, !detail.isEmpty { Text(detail).hfont(.caption).foregroundStyle(theme.muted) }
            HStack(alignment: .center, spacing: HSpace.x3) {
                Text("\(meta.label) · \(ExperienceDisplay.provenanceLabel(exp.provenance))")
                    .font(ramp.font(.caption))
                    .foregroundStyle(meta.tone == .ok ? theme.ok : meta.tone == .danger ? theme.danger : theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if canRevoke {
                    Button(L10n.t("Remove…"), action: revoke).buttonStyle(.webSmallGhost).disabled(busy)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
