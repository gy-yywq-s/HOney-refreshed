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

enum ComposeContext {
    case standalone
    case lesson(Lesson)
    case entity(EntityRef)
    /// Re-opening a private note for a later publish (the web noteId flow).
    case note(PrivateNote)

    /// The composer target, or nil when there is nothing to attach to yet.
    var target: ComposerTarget? {
        switch self {
        case .standalone:
            return nil
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
            case .course: detail = "Course"
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

    private static let rowBackground = Color.white.opacity(0.88)

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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
    }

    @ViewBuilder
    private func content(_ viewModel: ComposeExperienceViewModel) -> some View {
        if case .published = viewModel.status {
            publishedConfirmation
        } else if viewModel.savedNote != nil {
            keptPrivateConfirmation
        } else if viewModel.target == nil {
            noTargetGuidance
        } else {
            editor(viewModel)
        }
    }

    // MARK: - Terminal states

    private var publishedConfirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Published")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(Palette.navy)
                        Text("Your experience is live. It is stored without an author ID — the publish request carried no account identity, so nothing links the post back to you.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.navy.opacity(0.82))
                        Text("Your only control over it is an ownership key just saved to this device. Keep it: it is how you revoke the post later.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.navy.opacity(0.62))
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
                        .foregroundStyle(.white)
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
                        Text("The note stays only on this device — it was never sent anywhere. You can edit, delete or publish it later from My submissions.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.navy.opacity(0.82))
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
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 18)
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private var noTargetGuidance: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("An experience is about one of your own lessons, or a teacher, place or dish.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.navy.opacity(0.82))
                        Text("Pick a lesson from your Timetable or History, or open a teacher, place or dish from Experiences, and share from there.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.navy.opacity(0.62))
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
                                .foregroundStyle(Palette.navy.opacity(0.62))
                        }
                    }
                }
                .listRowBackground(Self.rowBackground)
            }

            Section("Your experience") {
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

            Section("A few things to keep in mind") {
                ForEach(SixChecks.all) { check in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                            .font(AppTheme.Typography.captionBold)
                            .foregroundStyle(Palette.ocean)
                        Text(check.prompt)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(Palette.navy.opacity(0.62))
                    }
                }
            }
            .listRowBackground(Self.rowBackground)

            Section {
                Text("Publishing runs a safety check first. Published posts carry no author ID; your only control is a key kept on this device. Private notes never leave this device.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.navy.opacity(0.62))
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
                    .foregroundStyle(Palette.navy.opacity(0.62))
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
                .foregroundStyle(Palette.navy.opacity(0.82))
            ForEach(reasons, id: \.self) { reason in
                Text("• \(reason)")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.navy.opacity(0.62))
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
                .foregroundStyle(Palette.navy.opacity(0.82))
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
            Button(viewModel.status == .checking ? "Checking…" : "Share") {
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
