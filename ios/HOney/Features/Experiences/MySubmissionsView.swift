//
//  MySubmissionsView.swift
//  HOney — the user's own contributions: server-side submissions (proved by
//  device-held ownership keys) merged with local private notes, mirroring the
//  web MinePage. Private notes are visually distinct; they never left this
//  device. Revoking keeps the ownership key so the row still shows as Revoked.
//

import SwiftUI

/// Status presentation for an own-submission row. A "mine" row only ever
/// exists for a post that was actually published — the check/publish split
/// means rejected drafts are never stored.
private struct StatusMeta {
    let chip: String
    let tint: Color
    let explain: String

    static func meta(for status: MyExperienceStatus) -> StatusMeta {
        switch status {
        case .published:
            return StatusMeta(chip: "Published", tint: Theme.Palette.accent, explain: "")
        case .blocked:
            return StatusMeta(
                chip: "Hidden",
                tint: Theme.Palette.danger,
                explain: "This was hidden after a re-check against the current community rules. You can revoke it to free your review slot for this target."
            )
        case .revoked:
            return StatusMeta(
                chip: "Revoked",
                tint: Theme.Palette.textSecondary,
                explain: "You removed this post; your review slot for this target is free again."
            )
        }
    }
}

struct MySubmissionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var experiences: [MyExperience] = []
    @State private var notes: [PrivateNote] = []
    @State private var keyByExperienceId: [String: String] = [:]
    @State private var names: [String: String] = [:]
    @State private var isLoading = true
    @State private var busyKey: String?
    @State private var revokingKey: String?
    @State private var feedback: (kind: BannerKind, text: String)?
    @State private var editingNote: PrivateNote?
    @State private var deletingNote: PrivateNote?

    private enum MineItem: Identifiable {
        case experience(MyExperience)
        case note(PrivateNote)

        var id: String {
            switch self {
            case .experience(let exp): return "exp-\(exp.id)"
            case .note(let note): return "note-\(note.id)"
            }
        }

        /// Sort instant in epoch milliseconds (web MinePage merge order).
        var at: Int {
            switch self {
            case .experience(let exp): return exp.createdAt
            case .note(let note): return Int(note.updatedAt.timeIntervalSince1970 * 1000)
            }
        }
    }

    private var items: [MineItem] {
        (experiences.map(MineItem.experience) + notes.map(MineItem.note))
            .sorted { $0.at > $1.at }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if experiences.isEmpty && notes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .screenBackground()
            .navigationTitle("My submissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .task { await load() }
            .sheet(item: $editingNote, onDismiss: { Task { await load() } }) { note in
                ComposeExperienceView(context: .note(note)).environment(model)
            }
            .alert("Revoke this experience?", isPresented: Binding(
                get: { revokingKey != nil },
                set: { if !$0 { revokingKey = nil } }
            )) {
                Button("Revoke post", role: .destructive) {
                    if let key = revokingKey { Task { await revoke(ownershipKey: key) } }
                }
                Button("Cancel", role: .cancel) { revokingKey = nil }
            } message: {
                Text("The post is removed for everyone and its text deleted. Your one-review slot for this target frees up again. This cannot be undone.")
            }
            .alert("Delete this private note?", isPresented: Binding(
                get: { deletingNote != nil },
                set: { if !$0 { deletingNote = nil } }
            )) {
                Button("Delete note", role: .destructive) {
                    if let note = deletingNote { Task { await deleteNote(note) } }
                }
                Button("Cancel", role: .cancel) { deletingNote = nil }
            } message: {
                Text("The note exists only on this device; deleting it cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Nothing here yet")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Published experiences are stored without an author ID. Each one hands this device a one-time ownership key — that key is the only control over the post that exists, and it is how this screen finds and revokes your posts. Private notes live here too, without ever leaving the device.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if !keyByExperienceId.isEmpty {
                    Banner(kind: .warning, message: "Your ownership keys exist only on this device. Losing this device permanently removes your control over these posts.")
                }
                if let feedback {
                    Banner(kind: feedback.kind, message: feedback.text)
                }
                ForEach(items) { item in
                    switch item {
                    case .experience(let exp):
                        experienceCard(exp)
                    case .note(let note):
                        noteCard(note)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Cards

    private func experienceCard(_ exp: MyExperience) -> some View {
        let meta = StatusMeta.meta(for: exp.status)
        let ownershipKey = keyByExperienceId[exp.id]
        return Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    chip(meta.chip, tint: meta.tint)
                    Text(exp.provenance.label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.accent)
                    Spacer()
                    Text(Date(timeIntervalSince1970: Double(exp.createdAt) / 1000), style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Text(targetLabel(exp))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let rating = exp.rating {
                    RatingStars(rating: rating)
                }
                if let body = exp.body {
                    Text(body)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                } else {
                    Text(exp.status == .revoked ? "(text deleted when you revoked this post)" : "(no text)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if !meta.explain.isEmpty {
                    Text(meta.explain)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if let detail = exp.statusDetail {
                    Text(detail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if let ownershipKey, exp.status != .revoked {
                    Button(role: .destructive) {
                        revokingKey = ownershipKey
                    } label: {
                        Label("Revoke…", systemImage: "trash")
                    }
                    .font(Theme.Typography.caption)
                    .disabled(busyKey == ownershipKey)
                }
            }
        }
    }

    /// Private notes are visually distinct: they never left this device.
    private func noteCard(_ note: PrivateNote) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    chip("Private — only on this device", tint: Theme.Palette.warning)
                    Spacer()
                    Text(note.updatedAt, style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Text(note.target.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if let rating = note.rating {
                    RatingStars(rating: rating)
                }
                Text(note.body)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack(spacing: Theme.Spacing.lg) {
                    Button("Edit / publish…") { editingNote = note }
                        .font(Theme.Typography.caption)
                    Button("Delete", role: .destructive) { deletingNote = note }
                        .font(Theme.Typography.caption)
                }
            }
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        notes = await model.services.privateNoteStore.list()
        let map = await model.services.ownershipKeyStore.map()
        keyByExperienceId = map
        await loadNames()
        guard !map.isEmpty else {
            experiences = []
            return
        }
        let response = try? await model.services.honeyAPI.myExperiences(keys: Array(map.values))
        experiences = response?.experiences ?? []
    }

    /// Directory ids + entity registry → display names (web NameMaps).
    private func loadNames() async {
        var resolved: [String: String] = names
        if let directory = try? await model.services.honeyAPI.directory() {
            for teacher in directory.teachers { resolved["teacher:\(teacher.id)"] = teacher.name }
            for course in directory.courses { resolved["course:\(course.id)"] = course.name }
            for room in directory.rooms { resolved["room:\(room.id)"] = room.name }
        }
        if let entities = try? await model.services.honeyAPI.entities(type: nil, query: nil) {
            for entity in entities.entities { resolved[entity.entityKey] = entity.name }
        }
        names = resolved
    }

    private func targetLabel(_ exp: MyExperience) -> String {
        if exp.entityKey.hasPrefix("lesson:") {
            var parts = ["Lesson experience"]
            if let courseId = exp.ctxCourseId, let name = names["course:\(courseId)"] { parts.append(name) }
            if let teacherId = exp.ctxTeacherId, let name = names["teacher:\(teacherId)"] { parts.append(name) }
            return parts.joined(separator: " · ")
        }
        return names[exp.entityKey] ?? exp.entityKey
    }

    private func revoke(ownershipKey: String) async {
        busyKey = ownershipKey
        feedback = nil
        defer { busyKey = nil }
        do {
            try await model.services.honeyAPI.revokeExperience(ownershipKey: ownershipKey)
            // The ownership key is KEPT: it still proves this row is yours, and
            // the row keeps showing as Revoked (web MinePage behavior).
            feedback = (.success, "Revoked. The post is gone and your review slot is free again.")
            revokingKey = nil
            await load()
        } catch {
            feedback = (.error, "Could not revoke. Please try again.")
        }
    }

    private func deleteNote(_ note: PrivateNote) async {
        await model.services.privateNoteStore.remove(id: note.id)
        deletingNote = nil
        await load()
    }
}
