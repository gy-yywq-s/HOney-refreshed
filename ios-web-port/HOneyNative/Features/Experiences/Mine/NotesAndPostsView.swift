// Your notes & posts (spec §17): the student's own words first — private
// notes and shared posts as plain rows with quiet status labels; the
// device-held control is one low-priority row that only escalates when
// something is wrong (orphaned keys).

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
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("Your notes & posts"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { nav.push(.compose(nil)) } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel(L10n.t("Share an experience"))
            }
        }
        .task {
            if model == nil { model = MineViewModel(env: env) }
            await model?.load()
        }
    }

    private func list(_ model: MineViewModel) -> some View {
        List {
            if let feedback = model.feedback {
                InlineStatusBanner(text: feedback.text, tone: feedback.tone).listRowBackground(Color.clear)
            }
            if model.loading, model.isEmpty {
                LoadingPlaceholder(lines: 4).listRowBackground(Color.clear)
            } else if model.isEmpty {
                EmptyStateView(title: L10n.t("Nothing here yet."), detail: L10n.t("Keep something private or share an Experience when you are ready."), action: (L10n.t("Share an experience"), { nav.push(.compose(nil)) }))
                    .listRowBackground(Color.clear)
            } else {
                if let error = model.error {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load(reload: true) } })).listRowBackground(Color.clear)
                }
                if !model.notes.isEmpty {
                    Section {
                        ForEach(model.notes) { note in
                            PrivateNoteRowView(note: note, open: { nav.push(.compose(.note(id: note.id))) }, delete: { deleting = note })
                                .listRowBackground(Color.clear)
                        }
                    } header: { Text(L10n.t("Private notes")).eyebrow() }
                }
                if !model.shared.isEmpty {
                    Section {
                        ForEach(model.shared) { exp in
                            SharedRowView(exp: exp, label: model.names.targetLabel(exp), busy: model.busyKey == model.key(for: exp), canRevoke: exp.status != .revoked && model.key(for: exp) != nil) {
                                revoking = model.key(for: exp)
                            }
                            .listRowBackground(Color.clear)
                        }
                    } header: { Text(L10n.t("Shared")).eyebrow() }
                }
                if !model.orphanKeys.isEmpty {
                    let n = model.orphanKeys.count
                    InlineStatusBanner(
                        text: n == 1 ? "1 stored post control no longer matches a post on the server." : "\(n) stored post controls no longer match a post on the server.",
                        tone: .warning,
                        action: ("Forget \(n > 1 ? "them" : "it")", { model.forgetOrphans() })
                    ).listRowBackground(Color.clear)
                }
                if !model.keys.isEmpty {
                    Section {
                        Button { nav.push(.settingsPrivacy) } label: {
                            EntityRow(title: L10n.t("Post controls on this iPhone"), caption: L10n.t("Manage"))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await model.load(reload: true) }
        .confirmationDialog("Remove this post?", isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }), titleVisibility: .visible) {
            Button("Remove post", role: .destructive) {
                if let key = revoking { Task { await model.revoke(key) } }
                revoking = nil
            }
            Button(L10n.t("Cancel"), role: .cancel) { revoking = nil }
        } message: {
            Text("The post disappears for everyone and its text is deleted. You can write a new one about this later. This cannot be undone.")
        }
        .confirmationDialog("Delete this private note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete note", role: .destructive) {
                if let note = deleting { Task { await model.deleteNote(note.id) } }
                deleting = nil
            }
            Button(L10n.t("Cancel"), role: .cancel) { deleting = nil }
        } message: {
            Text("The note exists only on this iPhone; deleting it cannot be undone.")
        }
    }
}

struct PrivateNoteRowView: View {
    let note: PrivateNote
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let remaining = (note.cooldown?.until ?? 0) - context.date.epochMillis
            let cooling = note.cooldown != nil && remaining > 0
            let paused = note.cooldown != nil && remaining <= 0
            VStack(alignment: .leading, spacing: HSpace.x2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.target.label).font(HType.meta.weight(.medium)).foregroundStyle(Color.honeySecondary).lineLimit(2)
                    Spacer()
                    Text(Formatters.coarseDate(note.updatedAt)).font(HType.micro).foregroundStyle(Color.honeyTertiary)
                }
                if let rating = note.rating { StarsView(value: rating) }
                Text(note.body).font(HType.reading).foregroundStyle(Color.honeyInk).lineLimit(6)
                HStack {
                    if cooling {
                        Text("\(L10n.t("Cooling · you can share this in")) \(Formatters.remaining(remaining))").foregroundStyle(Color.honeyWarning)
                    } else if paused {
                        Text(L10n.t("Pause over · ready to share")).foregroundStyle(Color.honeySuccess)
                    } else {
                        Text(L10n.t("Private · only on this iPhone")).foregroundStyle(Color.honeyTertiary)
                    }
                    Spacer()
                    Button(paused ? L10n.t("Share now") : cooling ? L10n.t("Edit") : L10n.t("Edit / share"), action: open)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .font(HType.meta)
            }
            .padding(.vertical, HSpace.x2)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: delete) { Label(L10n.t("Delete"), systemImage: "trash") }
        }
        .contextMenu {
            Button(L10n.t("Edit / share"), systemImage: "square.and.pencil", action: open)
            Button(L10n.t("Delete"), systemImage: "trash", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: L10n.t("Delete"), delete)
        .accessibilityAction(named: L10n.t("Edit / share"), open)
    }
}

struct SharedRowView: View {
    let exp: MyExperience
    let label: String
    let busy: Bool
    let canRevoke: Bool
    let revoke: () -> Void

    var body: some View {
        let meta = MineStatusCopy.meta(exp.status)
        VStack(alignment: .leading, spacing: HSpace.x2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(HType.meta.weight(.medium)).foregroundStyle(Color.honeySecondary).lineLimit(2)
                Spacer()
                Text(Formatters.coarseDate(exp.createdAt)).font(HType.micro).foregroundStyle(Color.honeyTertiary)
            }
            if let rating = exp.rating { StarsView(value: rating) }
            if let body = exp.body {
                Text(body).font(HType.reading).foregroundStyle(Color.honeyInk).lineLimit(6)
            } else {
                Text(exp.status == .revoked ? "(text deleted when you removed this post)" : "(no text)").font(HType.secondary).foregroundStyle(Color.honeySecondary)
            }
            if !meta.explain.isEmpty { Text(meta.explain).font(HType.meta).foregroundStyle(Color.honeySecondary) }
            if let detail = exp.statusDetail, !detail.isEmpty { Text(detail).font(HType.meta).foregroundStyle(Color.honeySecondary) }
            HStack {
                Text("\(meta.label) · \(ExperienceDisplay.provenanceLabel(exp.provenance))")
                    .font(HType.meta)
                    .foregroundStyle(meta.tone == .ok ? Color.honeySuccess : meta.tone == .danger ? Color.honeyDanger : Color.honeyTertiary)
                Spacer()
                if canRevoke {
                    Button(L10n.t("Remove…"), action: revoke).buttonStyle(.bordered).controlSize(.small).disabled(busy)
                }
            }
        }
        .padding(.vertical, HSpace.x2)
        .accessibilityElement(children: .combine)
    }
}
