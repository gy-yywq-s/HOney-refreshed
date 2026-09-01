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
            return StatusMeta(chip: "Published", tint: Palette.ocean, explain: "")
        case .blocked:
            return StatusMeta(
                chip: "Hidden",
                tint: Palette.error,
                explain: "This was hidden after a re-check against the current community rules. Revoke it if you want to share about this lesson or school item again."
            )
        case .revoked:
            return StatusMeta(
                chip: "Revoked",
                tint: Palette.inkSecondary,
                explain: "You removed this post and can share about this lesson or school item again."
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
    @State private var feedback: (kind: AppBanner.Style, text: String)?
    @State private var editingNote: PrivateNote?
    @State private var deletingNote: PrivateNote?
    @State private var loadError: String?

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
                    AppLoadingState(title: "Loading your posts and private notes")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError, notes.isEmpty {
                    VStack(spacing: 12) {
                        AppBanner(text: loadError, style: .error)
                        Button("Try again") { Task { await load() } }
                            .buttonStyle(PrimaryActionButtonStyle())
                    }
                    .padding(AppTheme.Spacing.pageHorizontal)
                } else if experiences.isEmpty && notes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("My posts & notes")
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
                Text("The post is removed for everyone and its text deleted. You can then post about this lesson, teacher, place, or dish again. This cannot be undone.")
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
            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("Nothing here yet")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(Palette.navy)
                    Text("Published experiences are stored without an author ID. A post-control key saved only on this iPhone is how this screen finds and revokes each post. Private notes live here too, without ever leaving the device.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !keyByExperienceId.isEmpty {
                    AppBanner(text: "Your post-control keys exist only on this iPhone. Losing them permanently removes your control over these posts.", style: .warning)
                }
                if let feedback {
                    AppBanner(text: feedback.text, style: feedback.kind)
                }
                if let loadError {
                    AppBanner(text: loadError, style: .error)
                    Button("Try loading published posts again") { Task { await load() } }
                        .buttonStyle(SecondaryActionButtonStyle())
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
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Cards

    private func experienceCard(_ exp: MyExperience) -> some View {
        let meta = StatusMeta.meta(for: exp.status)
        let ownershipKey = keyByExperienceId[exp.id]
        return AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack(spacing: AppTheme.Spacing.small) {
                    chip(meta.chip, tint: meta.tint)
                    Text(exp.provenance.label)
                        .font(AppTheme.Typography.caption2Bold)
                        .foregroundStyle(Palette.ocean)
                    Spacer()
                    Text(Date(timeIntervalSince1970: Double(exp.createdAt) / 1000), style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Text(targetLabel(exp))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                if let rating = exp.rating {
                    RatingStars(rating: rating)
                }
                if let body = exp.body {
                    Text(body)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Palette.ink)
                } else {
                    Text(exp.status == .revoked ? "(text deleted when you revoked this post)" : "(no text)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                if !meta.explain.isEmpty {
                    Text(meta.explain)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                if let detail = exp.statusDetail {
                    Text(detail)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                if let ownershipKey, exp.status != .revoked {
                    Button(role: .destructive) {
                        revokingKey = ownershipKey
                    } label: {
                        Label("Revoke…", systemImage: "trash")
                            .font(AppTheme.Typography.captionBold)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.error)
                    .frame(minHeight: 44)
                    .disabled(busyKey == ownershipKey)
                }
            }
        }
    }

    /// Private notes are visually distinct: they never left this device.
    private func noteCard(_ note: PrivateNote) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                HStack(spacing: AppTheme.Spacing.small) {
                    chip("Private — only on this device", tint: Palette.warning)
                    Spacer()
                    Text(note.updatedAt, style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Text(note.target.label)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                if let rating = note.rating {
                    RatingStars(rating: rating)
                }
                Text(note.body)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: AppTheme.Spacing.large) {
                    Button("Edit / publish…") { editingNote = note }
                        .buttonStyle(.plain)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(Palette.ocean)
                        .frame(minHeight: 44)
                    Button("Delete", role: .destructive) { deletingNote = note }
                        .buttonStyle(.plain)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(Palette.error)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(AppTheme.Typography.caption2Bold)
            .padding(.horizontal, AppTheme.Spacing.small)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        notes = await model.services.privateNoteStore.list()
        let map: [String: String]
        do {
            map = try await model.services.ownershipKeyStore.map()
        } catch {
            experiences = []
            keyByExperienceId = [:]
            loadError = "HOney could not read post-control keys. Published posts are hidden until the keys are available."
            return
        }
        keyByExperienceId = map
        await loadNames()
        guard !map.isEmpty else {
            experiences = []
            return
        }
        do {
            let response = try await model.services.honeyAPI.myExperiences(keys: Array(map.values))
            experiences = response.experiences
        } catch {
            experiences = []
            loadError = "Published posts could not be loaded. Your private notes are still available below."
        }
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
            feedback = (.success, "Revoked. The post is gone, and you can share here again.")
            revokingKey = nil
            await load()
        } catch {
            feedback = (.error, "Could not revoke. Please try again.")
        }
    }

    private func deleteNote(_ note: PrivateNote) async {
        do {
            try await model.services.privateNoteStore.remove(id: note.id)
            deletingNote = nil
            await load()
        } catch {
            deletingNote = nil
            feedback = (.error, "Private note was not deleted. Try again.")
        }
    }
}
