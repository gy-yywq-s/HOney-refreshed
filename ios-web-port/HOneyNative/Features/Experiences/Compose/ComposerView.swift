// The editor (spec §15–16): a compact About row, the stable prompt, a
// TextEditor that fills the space, dish stars only for dishes, the privacy
// line, and a bottom action bar — Keep private / Continue to share, then
// Share as written after a nudge. Outcomes are native sheets. Nothing is
// ever auto-published.

import SwiftUI
import HOneyCore

struct ComposerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    let target: ComposeTarget

    @State private var model: ComposerViewModel?
    @State private var pauseRemaining: Int64?
    @State private var showDisclosure = false
    @State private var showNudge = false
    @State private var showCooldown = false
    @State private var showPublished = false
    @State private var showKeyUnsaved = false
    @State private var showKeptPrivate = false
    @FocusState private var editing: Bool

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("Share an experience"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if model == nil {
                let m = ComposerViewModel(env: env, target: target)
                model = m
                await m.load()
                pauseRemaining = await m.pauseRemaining()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: ComposerViewModel) -> some View {
        if model.loading {
            LoadingPlaceholder(lines: 4).pageInset()
        } else if let error = model.loadError {
            InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load() } }))
                .pageInset()
                .frame(maxHeight: .infinity, alignment: .top)
        } else if model.unlisted {
            unlisted(model)
        } else {
            editor(model)
        }
    }

    private func unlisted(_ model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            Text(model.label.isEmpty
                 ? "Nothing is listed at this address, so nothing can be shared about it."
                 : "This entry is no longer listed, so nothing can be shared about it.")
                .font(HType.body)
                .foregroundStyle(Color.honeyInk)
            if let survivor = model.survivor {
                Button("Open the current entry for \(survivor.name)") {
                    nav.pop()
                    nav.push(.compose(.entity(key: survivor.entityKey)))
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(L10n.t("Find someone or something")) { nav.push(.explore) }.buttonStyle(.borderedProminent)
            }
        }
        .pageInset()
        .padding(.top, HSpace.x4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func editor(_ model: ComposerViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                aboutRow(model)
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    Text(L10n.t("What was it like for you?"))
                        .font(HType.body.weight(.semibold))
                        .foregroundStyle(Color.honeyInk)
                    Text(L10n.t("A moment, a pattern, or just a feeling. Specific context can help, but it is not required."))
                        .font(HType.meta)
                        .foregroundStyle(Color.honeySecondary)
                }
                TextEditor(text: $model.body)
                    .font(HType.reading)
                    .foregroundStyle(Color.honeyInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(HSpace.x2)
                    .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).stroke(Color.honeyLine, lineWidth: 1))
                    .focused($editing)
                    .disabled(model.checking)
                    .accessibilityLabel(L10n.t("What was it like for you?"))
                if model.isDish {
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        Text(L10n.t("Rating (dishes only — optional)")).font(HType.meta).foregroundStyle(Color.honeySecondary)
                        StarInput(value: $model.rating)
                    }
                }
                if model.draftUnsavedBeforeCheck {
                    InlineStatusBanner(text: ModerationCopy.draftNotSaved, tone: .warning)
                }
                if let remaining = pauseRemaining, model.notice == nil {
                    InlineStatusBanner(text: "\(L10n.t("Cooling · you can share these words in")) \(Formatters.remaining(remaining)). \(L10n.t("Edit them to say it differently and check again now."))", tone: .warning)
                }
                if let notice = model.notice {
                    VStack(alignment: .leading, spacing: HSpace.x2) {
                        InlineStatusBanner(text: notice.text, tone: notice.tone == .danger ? .danger : .warning)
                        ForEach(ModerationCopy.describeReasons(notice.reasons), id: \.self) { reason in
                            Text("• \(reason)").font(HType.meta).foregroundStyle(Color.honeySecondary)
                        }
                        if notice.suggestKeepPrivate {
                            Text("You can keep it as a private note instead.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                        }
                    }
                }
                if let error = model.privateSaveError {
                    InlineStatusBanner(text: error, tone: .danger)
                }
                privacyLine
            }
            .pageInset()
            .padding(.vertical, HSpace.x4)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { actionBar(model) }
        .onChange(of: model.body) { _, _ in Task { pauseRemaining = await model.pauseRemaining() } }
        .onChange(of: model.status) { _, status in
            switch status {
            case .nudge: showNudge = true
            case .cooldown: showCooldown = true
            case .published:
                showKeyUnsaved = false
                showPublished = true
            case .publishedKeyUnsaved: showKeyUnsaved = true
            default: break
            }
        }
        .onChange(of: model.keptPrivate) { _, kept in if kept { showKeptPrivate = true } }
        .sheet(isPresented: $showDisclosure) {
            FirstPublicationDisclosureSheet {
                env.prefs.firstPublishDisclosureSeen = true
                Task { await model.continueToShare() }
            }
        }
        .sheet(isPresented: $showNudge) { nudgeSheet(model) }
        .sheet(isPresented: $showCooldown) { cooldownSheet(model) }
        .sheet(isPresented: $showPublished) { publishedSheet(model) }
        .sheet(isPresented: $showKeyUnsaved) { keyUnsavedSheet(model) }
        .sheet(isPresented: $showKeptPrivate) { keptPrivateSheet }
    }

    private func aboutRow(_ model: ComposerViewModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("About")).eyebrow()
                Text(model.label).font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                if let detail = model.detail, !detail.isEmpty {
                    Text(detail).font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
            }
            Spacer()
            if !model.isNote {
                Button(L10n.t("Change")) {
                    if nav.currentPath.dropLast().last == .compose(nil) { nav.pop() } else { nav.push(.compose(nil)) }
                }
                .font(HType.secondary)
            }
        }
        .padding(.vertical, HSpace.x2)
    }

    private var privacyLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t(ModerationCopy.privacyLine))
            Button(L10n.t("How anonymity works")) { nav.push(.settingsPrivacy) }
        }
        .font(HType.meta)
        .foregroundStyle(Color.honeySecondary)
    }

    private func actionBar(_ model: ComposerViewModel) -> some View {
        VStack(spacing: HSpace.x2) {
            switch model.saveState {
            case .saving: Text(L10n.t("Saving…")).font(HType.micro).foregroundStyle(Color.honeyTertiary)
            case .saved: Text(L10n.t("Saved on this iPhone")).font(HType.micro).foregroundStyle(Color.honeyTertiary)
            case .failed(let message): Text(message).font(HType.micro).foregroundStyle(Color.honeyDanger)
            case .idle: EmptyView()
            }
            PrimaryBottomActionBar(
                primary: (primaryLabel(model), {
                    editing = false
                    if !env.prefs.firstPublishDisclosureSeen {
                        showDisclosure = true
                    } else {
                        Task { await model.continueToShare() }
                    }
                }),
                primaryEnabled: model.canAct && pauseRemaining == nil,
                secondary: (model.busySavingNote ? L10n.t("Saving…") : L10n.t("Keep private"), {
                    editing = false
                    Task { await model.keepPrivate() }
                }),
                secondaryEnabled: model.canAct && !model.busySavingNote
            )
        }
        .padding(.horizontal, HSpace.pageX)
        .padding(.vertical, HSpace.x3)
        .background(.bar)
    }

    private func primaryLabel(_ model: ComposerViewModel) -> String {
        if model.checking { return L10n.t("Checking…") }
        if let remaining = pauseRemaining { return "\(L10n.t("Share in")) \(Formatters.remaining(remaining))" }
        if model.note?.cooldown != nil { return L10n.t("Share now") }
        return L10n.t("Continue to share")
    }

    // MARK: Outcome sheets (spec §16)

    private func nudgeSheet(_ model: ComposerViewModel) -> some View {
        OutcomeSheet(title: L10n.t("Before you share")) {
            Text(L10n.t(ModerationCopy.nudgeQuestion)).font(HType.body)
            if case .nudge(let reasons) = model.status {
                ForEach(ModerationCopy.describeReasons(reasons), id: \.self) { Text("• \($0)").font(HType.secondary).foregroundStyle(Color.honeySecondary) }
            }
        } actions: {
            Button(L10n.t("Add a little context")) { showNudge = false; Task { await model.addContext() } }.buttonStyle(.bordered)
            Button(L10n.t("Share as written")) { showNudge = false; Task { await model.shareAsWritten() } }.buttonStyle(.borderedProminent)
            Button(L10n.t("Keep private")) { showNudge = false; Task { await model.keepPrivate() } }.buttonStyle(.plain).foregroundStyle(Color.honeySecondary)
        }
        .interactiveDismissDisabled()
    }

    private func cooldownSheet(_ model: ComposerViewModel) -> some View {
        OutcomeSheet(title: L10n.t(ModerationCopy.cooldownTitle)) {
            if case .cooldown(let retryAt, _) = model.status {
                if model.cooldownSaveFailed {
                    Text(ModerationCopy.cooldownSaveFailed).font(HType.body)
                    Text("You can share these words in \(Formatters.remaining(retryAt - HOneyClock.now().epochMillis)).").font(HType.secondary).foregroundStyle(Color.honeySecondary)
                } else {
                    Text("Your words are kept in your private notes on this iPhone. You can share them in \(Formatters.remaining(retryAt - HOneyClock.now().epochMillis)) — or edit them to say it differently and check again sooner.").font(HType.body)
                }
            }
            Text(L10n.t(ModerationCopy.cooldownNote)).font(HType.secondary).foregroundStyle(Color.honeySecondary)
        } actions: {
            if model.cooldownSaveFailed {
                Button("Copy my words") { UIPasteboard.general.string = model.body }.buttonStyle(.bordered)
                Button("Try keeping it again") { showCooldown = false; Task { await model.keepPrivate() } }.buttonStyle(.borderedProminent)
                Button("Stay in the editor") { showCooldown = false }.buttonStyle(.plain).foregroundStyle(Color.honeySecondary)
            } else {
                Button(L10n.t("OK")) {
                    showCooldown = false
                    nav.pop()
                    nav.push(.mine)
                }.buttonStyle(.borderedProminent)
            }
        }
        .interactiveDismissDisabled()
    }

    private func publishedSheet(_ model: ComposerViewModel) -> some View {
        OutcomeSheet(title: L10n.t(ModerationCopy.sharedTitle)) {
            Text(ModerationCopy.sharedBody).font(HType.body)
        } actions: {
            Button(L10n.t("Your notes & posts")) { showPublished = false; nav.pop(); nav.push(.mine) }.buttonStyle(.bordered)
            Button(L10n.t("Done")) { showPublished = false; nav.pop() }.buttonStyle(.borderedProminent)
        }
        .interactiveDismissDisabled()
    }

    private func keyUnsavedSheet(_ model: ComposerViewModel) -> some View {
        OutcomeSheet(title: "Shared, but the control key was not stored") {
            if case .publishedKeyUnsaved(_, _, let journaled) = model.status, journaled {
                Text("The post is already public. This iPhone could not put its control key in the Keychain yet, but the key is kept in HOney's protected recovery file and will be stored again on the next launch. Copy it too, to be safe.").font(HType.body)
            } else {
                Text(ModerationCopy.keyUnsavedBody).font(HType.body)
            }
            if case .publishedKeyUnsaved(_, let key, _) = model.status {
                Text(key)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(HSpace.x3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.honeySoft, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                Button("Copy key") { UIPasteboard.general.string = key }.buttonStyle(.bordered)
            }
        } actions: {
            Button("Try storing again") { Task { await model.retryStoringKey() } }.buttonStyle(.borderedProminent)
            Button(L10n.t("Done")) { showKeyUnsaved = false; nav.pop() }.buttonStyle(.plain)
        }
        .interactiveDismissDisabled()
    }

    private var keptPrivateSheet: some View {
        OutcomeSheet(title: L10n.t(ModerationCopy.keptPrivateTitle)) {
            Text(model?.keptAfterCheck == true ? ModerationCopy.keptPrivateAfterCheck : ModerationCopy.keptPrivateNeverSent).font(HType.body)
            Text("It lives in protected app storage on this iPhone. Deleting the app removes it unless you export first.").font(HType.secondary).foregroundStyle(Color.honeySecondary)
        } actions: {
            Button(L10n.t("Your notes & posts")) { showKeptPrivate = false; nav.pop(); nav.push(.mine) }.buttonStyle(.bordered)
            Button(L10n.t("Done")) { showKeptPrivate = false; nav.pop() }.buttonStyle(.borderedProminent)
        }
    }
}

/// A native decision sheet: title, prose, stacked actions, medium detent.
struct OutcomeSheet<Content: View, Actions: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            Text(title).font(HType.pageTitle).foregroundStyle(Color.honeyInk)
            content().foregroundStyle(Color.honeyInk)
            Spacer(minLength: 0)
            VStack(spacing: HSpace.x2) { actions() }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .pageInset()
        .padding(.top, HSpace.x6)
        .padding(.bottom, HSpace.x4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// One short sheet before the first public share (spec §22.3).
struct FirstPublicationDisclosureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let proceed: () -> Void

    var body: some View {
        OutcomeSheet(title: "Before your first share") {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                Text("1. HOney verifies you had the relevant class or place.")
                Text("2. Your text gets a check before it can be published — obvious rule problems on HOney's server, otherwise once through an external text-moderation model, without your identity.")
                Text("3. The public post stores no ordinary author field.")
                Text("4. This iPhone keeps a control key so you can remove it later.")
                Text("5. What you write may still identify the situation to people who know it.")
            }
            .font(HType.body)
        } actions: {
            Button(L10n.t("Continue to share")) { dismiss(); proceed() }.buttonStyle(.borderedProminent)
            Button(L10n.t("Cancel")) { dismiss() }.buttonStyle(.plain).foregroundStyle(Color.honeySecondary)
        }
    }
}
