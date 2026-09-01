//
//  ComposeExperienceView.swift
//  HOney — compose a lesson-linked or entity-linked experience. Dish entities
//  get an optional 1–5 rating; nothing else does. The Six Checks appear as
//  contextual hints, not checkboxes.
//
//  Publication is deliberate (audit §3.3/§3.4): the draft is preserved locally
//  before any network call, moderation runs synchronously as a preflight, and a
//  nudge asks the user to choose before anything is published — nothing is ever
//  auto-published. "Keep private" is a peer action alongside Share.
//

import SwiftUI
import UIKit

enum ComposeContext {
    case lesson(Lesson)
    case entity(EntityRef)
    /// Re-opening a private note for a later publish (the web noteId flow).
    case note(PrivateNote)

    /// Every reachable composer is attached to a concrete lesson or entity.
    var target: ComposerTarget? {
        switch self {
        case .lesson(let lesson):
            let detail = [
                lesson.startsAt.formatted(date: .abbreviated, time: .omitted),
                "\(lesson.startsAt.formatted(date: .omitted, time: .shortened))–\(lesson.endsAt.formatted(date: .omitted, time: .shortened))",
                lesson.teacherName ?? "",
                lesson.roomName ?? ""
            ].filter { !$0.isEmpty }.joined(separator: " · ")
            return ComposerTarget(label: lesson.subjectName, detail: detail, lessonId: lesson.id)
        case .entity(let entity):
            let detail: String
            switch entity.type {
            case .room: detail = "Place"
            case .dish: detail = "Food"
            case .teacher: detail = "Teacher"
            }
            return ComposerTarget(
                label: entity.name,
                detail: detail,
                entityKey: entity.entityKey,
                isDish: entity.type == .dish
            )
        case .note(let note):
            return ComposerTarget(
                label: note.target.label,
                lessonId: note.target.lessonId,
                entityKey: note.target.entityKey,
                isDish: note.target.entityType == "dish"
            )
        }
    }

    var seedNote: PrivateNote? {
        if case .note(let note) = self { return note }
        return nil
    }
}

struct ComposeExperienceView: View {
    let context: ComposeContext

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ComposeExperienceViewModel?
    @State private var copiedRecoveryKey = false

    private static let rowBackground = Palette.surface

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    AppLoadingState(title: "One moment")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.background.ignoresSafeArea())
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRecoveringKey {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = ComposeExperienceViewModel(
                        services: model.services,
                        target: context.target,
                        seedNote: context.seedNote
                    )
                    await viewModel?.hydrate()
                }
            }
        }
        .interactiveDismissDisabled(isRecoveringKey)
    }

    @ViewBuilder
    private func content(_ viewModel: ComposeExperienceViewModel) -> some View {
        if case .publishedKeyRecovery(let ownershipKey, let experienceId, let journalSaved) = viewModel.status {
            keyRecovery(
                ownershipKey: ownershipKey,
                experienceId: experienceId,
                journalSaved: journalSaved,
                viewModel: viewModel
            )
        } else if case .published = viewModel.status {
            publishedConfirmation
        } else if viewModel.savedNote != nil {
            keptPrivateConfirmation
        } else if viewModel.target == nil {
            AppBanner(text: "This draft has no valid lesson or school item. Close it and choose the lesson again.", style: .error)
                .padding(AppTheme.Spacing.pageHorizontal)
        } else {
            editor(viewModel)
        }
    }

    private var isRecoveringKey: Bool {
        guard let viewModel else { return false }
        if case .publishedKeyRecovery = viewModel.status { return true }
        return false
    }

    // MARK: - Terminal states

    private func keyRecovery(
        ownershipKey: String,
        experienceId: String,
        journalSaved: Bool,
        viewModel: ComposeExperienceViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppBanner(
                    text: viewModel.keyRecoveryError ?? "The post is public, but this iPhone could not save its post-control key.",
                    style: .error
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Protect control of this post")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text("Do not publish again. Copy this recovery key now, then retry saving it to this iPhone.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                    Text(ownershipKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        .accessibilityLabel("Post-control recovery key")
                    Text("Post ID: " + experienceId)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Button(copiedRecoveryKey ? "Recovery key copied" : "Copy recovery key") {
                    UIPasteboard.general.setItems(
                        [["public.utf8-plain-text": ownershipKey]],
                        options: [
                            .localOnly: true,
                            .expirationDate: Date().addingTimeInterval(5 * 60)
                        ]
                    )
                    copiedRecoveryKey = true
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(viewModel.isSavingRecoveryKey ? "Saving…" : "Retry saving to this iPhone") {
                    Task { await viewModel.retryOwnershipKeyStorage() }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isSavingRecoveryKey)

                if copiedRecoveryKey {
                    Button(journalSaved ? "I copied the recovery key — Close" : "I copied the key — Close anyway") { dismiss() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Text(journalSaved
                         ? "Closing keeps the protected recovery record and draft on this iPhone. Reopen the same lesson to retry later."
                         : "No protected recovery record was saved. The local-only clipboard expires in five minutes; save the copied key somewhere secure before closing.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(AppTheme.Spacing.pageHorizontal)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var publishedConfirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Shared")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(Palette.navy)
                        Text("Your school identity is not shown with this Experience. The public post is stored without an author field.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.ink)
                        Text("A private post-control key was saved on this iPhone so you can find and revoke the post later.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.inkSecondary)
                        if let warning = viewModel?.keyRecoveryError {
                            AppBanner(text: warning, style: .warning)
                        }
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(AppTheme.Typography.subheadlineSemibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Palette.ocean, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.accentForeground)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 18)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var keptPrivateConfirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Kept private")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(Palette.navy)
                        Text("The note stays only on this device — it was never sent anywhere. You can edit, delete or publish it later from My posts & notes.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.ink)
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(AppTheme.Typography.subheadlineSemibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Palette.ocean, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.accentForeground)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 18)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    // MARK: - Editor

    private func editor(_ viewModel: ComposeExperienceViewModel) -> some View {
        @Bindable var vm = viewModel
        let isNudge: Bool = {
            if case .nudge = viewModel.status { return true }
            return false
        }()
        return Form {
            if let target = viewModel.target {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.label)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(Palette.navy)
                        if let detail = target.detail, !detail.isEmpty {
                            Text(detail)
                                .font(AppTheme.Typography.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }
                .listRowBackground(Self.rowBackground)
            }

            Section {
                Text("What do you want to share about this experience?")
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.ink)
                Text("Specific context can help, but it is okay if what you have is only a feeling.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                TextEditor(text: $vm.body)
                    .frame(minHeight: 140)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.navy)
                    .scrollContentBackground(.hidden)
                    .disabled(isNudge)
            }
            .listRowBackground(Self.rowBackground)

            if viewModel.target?.isDish == true {
                Section("Rating (dishes only — optional)") {
                    Stepper(value: Binding(
                        get: { vm.rating ?? 0 },
                        set: { vm.rating = $0 == 0 ? nil : $0 }
                    ), in: 0...5) {
                        HStack {
                            Text(vm.rating.map { "\($0) / 5" } ?? "No rating")
                                .foregroundStyle(Palette.navy)
                            if let rating = vm.rating, rating > 0 {
                                RatingStars(rating: rating)
                            }
                        }
                    }
                }
                .listRowBackground(Self.rowBackground)
            }

            if let notice = viewModel.notice {
                Section {
                    noticeBanner(notice, viewModel: viewModel)
                }
                .listRowBackground(Self.rowBackground)
            }
            if let error = viewModel.keepPrivateError {
                Section { AppBanner(text: error, style: .error) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if let error = viewModel.localStorageError {
                Section { AppBanner(text: error, style: .error) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Group {
                switch viewModel.status {
                case .nudge(let reasons):
                    nudgeSection(reasons: reasons, viewModel: viewModel)
                case .cooldown(let retryAt, _):
                    cooldownSection(retryAt: retryAt, viewModel: viewModel)
                default:
                    actionsSection(viewModel)
                }
            }
            .listRowBackground(Self.rowBackground)

            Section {
                Text("Public sharing sends these words through HOney’s safety check and still requires your explicit action. Public posts have no author field; this device keeps the control key. Private notes stay on this device.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .listRowBackground(Self.rowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .tint(Palette.ocean)
    }

    private func noticeBanner(_ notice: ComposerNotice, viewModel: ComposeExperienceViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            AppBanner(text: notice.text, style: notice.tone == .danger ? .error : .warning)
            ForEach(notice.reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if notice.suggestKeepPrivate {
                Button("Keep as a private note") {
                    Task { await viewModel.keepPrivate() }
                }
                .disabled(viewModel.isSavingNote)
                .font(AppTheme.Typography.caption)
            }
        }
    }

    /// The nudge preflight: this CAN go public as is — the user chooses.
    private func nudgeSection(reasons: [String], viewModel: ComposeExperienceViewModel) -> some View {
        Section("Before you publish") {
            Text("This can go public as it is. A little more context often helps another student more than a verdict — but that is your call.")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(Palette.ink)
            ForEach(reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Button("Publish as is") {
                Task { await viewModel.publishAsIs() }
            }
            Button("Add context") {
                viewModel.backToEditing()
            }
            Button("Keep private") {
                Task { await viewModel.keepPrivate() }
            }
            .disabled(viewModel.isSavingNote)
        }
    }

    /// The cooling-off window: a pause, not a rejection.
    private func cooldownSection(retryAt: Int, viewModel: ComposeExperienceViewModel) -> some View {
        Section("Cooling off") {
            Text("The wording reads as very heated. Nothing was stored, and your draft is safe. You can publish the same words after a short cooling-off window — a pause, not a rejection.")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(Palette.ink)
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let remainingMs = retryAt - Int(timeline.date.timeIntervalSince1970 * 1000)
                let ready = remainingMs <= 0
                Button(ready ? "Publish now" : "Publish in \(Self.formatRemaining(remainingMs))") {
                    Task { await viewModel.recheckAfterCooldown() }
                }
                .disabled(!ready)
            }
            Button("Keep private meanwhile") {
                Task { await viewModel.keepPrivate() }
            }
            .disabled(viewModel.isSavingNote)
        }
    }

    /// Share and Keep private are peer actions (audit §3.5).
    private func actionsSection(_ viewModel: ComposeExperienceViewModel) -> some View {
        Section {
            Button(viewModel.status == .checking ? "Checking…" : "Share anonymously") {
                Task { await viewModel.publish() }
            }
            .disabled(!viewModel.canAct)
            Button("Keep private") {
                Task { await viewModel.keepPrivate() }
            }
            .disabled(viewModel.isSavingNote || viewModel.status == .checking
                      || viewModel.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    /// "3 h 12 min" style remaining-time label (web formatRemaining).
    static func formatRemaining(_ ms: Int) -> String {
        let totalMin = max(1, Int((Double(ms) / 60_000).rounded(.up)))
        let hours = totalMin / 60
        let minutes = totalMin % 60
        if hours == 0 { return "\(minutes) min" }
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }
}
