// The editor (ComposePage.tsx + features.css `.compose-*`, `.nudge`;
// fidelity spec v2 §10.2–10.3): the page title, the About block (label,
// the target at 22 pt, its detail, Change), the field label "What was it
// like for you?", the Web textarea, the italic helper, the draft line, dish
// stars, banners, then the stacked actions — ink-filled Continue to share,
// ghost Keep private — and the privacy line. Outcomes replace the screen
// the way the Web does (Shared. / Kept private); the nudge and the cooling
// panel rise as sheets in the Web's `.nudge` surface. Nothing is ever
// auto-published.

import SwiftUI
import HOneyCore

struct ComposerView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let target: ComposeTarget

    @State private var model: ComposerViewModel?
    @State private var pauseRemaining: Int64?
    @State private var showNudge = false
    @State private var showCooldown = false
    @FocusState private var editing: Bool

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                LoadingPlaceholder(lines: 4).pageInset()
            }
        }
        .webScreen(title: L10n.t("Share an experience"))
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
        if case .published = model.status {
            outcome(title: L10n.t("Shared."), lead: ModerationCopy.sharedBody, note: "The post's control key derives from the root on this iPhone, so you can manage or remove it later from Your notes & posts. What you wrote may still make you recognisable to people who know the situation.")
        } else if case .postControlsRestoreNeeded = model.status {
            restoreNeeded(model)
        } else if model.keptPrivate {
            outcome(
                title: L10n.t(ModerationCopy.keptPrivateTitle),
                lead: model.keptAfterCheck ? ModerationCopy.keptPrivateAfterCheck : ModerationCopy.keptPrivateNeverSent,
                note: "It lives in protected app storage on this iPhone. Deleting the app removes it unless you export first."
            )
        } else if model.loading {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Share an experience"))
                LoadingPlaceholder(lines: 4)
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let error = model.loadError {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Share an experience"))
                InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load() } }))
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if model.unlisted {
            unlisted(model)
        } else {
            editor(model)
        }
    }

    /// The Web's `.card` with the sentence and one primary action.
    private func unlisted(_ model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x4) {
            PageTitle(text: L10n.t("Share an experience"))
            VStack(alignment: .leading, spacing: HSpace.x4) {
                Text(model.label.isEmpty
                     ? "Nothing is listed at this address, so nothing can be shared about it."
                     : "This entry is no longer listed, so nothing can be shared about it.")
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                if let survivor = model.survivor {
                    Button("Open the current entry for \(survivor.name)") {
                        nav.pop()
                        nav.push(.compose(.entity(key: survivor.entityKey)))
                    }
                    .buttonStyle(.webPrimary)
                } else {
                    Button(L10n.t("Find someone or something")) { nav.push(.explore) }.buttonStyle(.webPrimary)
                }
            }
            .webCard()
        }
        .pageInset()
        .padding(.top, HSpace.x2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// `Shared.` / `Kept private`: the page title, a hero card with the
    /// paragraph, the muted note and "Your notes & posts".
    private func outcome(title: String, lead: String, note: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: title)
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    Text(lead).hfont(.body).foregroundStyle(theme.ink).fixedSize(horizontal: false, vertical: true)
                    Text(note).hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.t("Your notes & posts")) { nav.pop(); nav.push(.mine) }
                        .buttonStyle(.webPrimary)
                }
                .webCard(hero: true)
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
    }

    /// A server vault exists that this iPhone has not restored: sharing waits, the draft stays.
    private func restoreNeeded(_ model: ComposerViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Restore your post controls first"))
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    Text(ModerationCopy.restoreNeeded)
                        .hfont(.body)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: HSpace.x2) {
                        Button(L10n.t("Open Post controls")) { nav.push(.settingsPostControls) }.buttonStyle(.webBlockPrimary)
                        Button(L10n.t("Back to the draft")) { model.backToEditing() }.buttonStyle(.webBlockGhost)
                    }
                }
                .webCard(hero: true)
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
    }

    @ViewBuilder
    private func editor(_ model: ComposerViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x3) {
                PageTitle(text: L10n.t("Share an experience"))
                aboutBlock(model)

                // `.field`: label, the textarea, the helper, the draft line.
                VStack(alignment: .leading, spacing: HSpace.x2) {
                    FieldLabel(text: L10n.t("What was it like for you?"))
                    ZStack(alignment: .topLeading) {
                        if model.body.isEmpty {
                            Text(L10n.t("Your own experience, in your own words"))
                                .font(ramp.font(.body))
                                .foregroundStyle(theme.muted)
                                .padding(.horizontal, HSpace.x3 + 5)
                                .padding(.vertical, HSpace.x3 + 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $model.body)
                            .font(ramp.font(.body))
                            .lineSpacing(ramp.lineSpacing(.reading))
                            .foregroundStyle(theme.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(HSpace.x2)
                            .focused($editing)
                            .disabled(model.checking)
                            .accessibilityLabel(L10n.t("What was it like for you?"))
                    }
                    .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
                    Text(L10n.t("A moment, a pattern, or just a feeling. Specific context can help, but it is not required."))
                        .font(ramp.font(TypeRole(size: 13, weight: 400, textStyle: .footnote, tracking: 0, lineHeight: 1.4, italic: true)))
                        .foregroundStyle(theme.muted)
                    if !model.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(draftLine(model)).hfont(.caption).foregroundStyle(draftFailed(model) ? theme.danger : theme.ink3)
                    }
                }

                if model.isDish {
                    VStack(alignment: .leading, spacing: HSpace.x2) {
                        FieldLabel(text: L10n.t("Rating (dishes only — optional)"))
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
                    noticeBanner(notice)
                }
                if let error = model.privateSaveError {
                    InlineStatusBanner(text: error, tone: .danger)
                }

                actions(model)
                privacyLine
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.body) { _, _ in Task { pauseRemaining = await model.pauseRemaining() } }
        .onChange(of: model.status) { _, status in
            switch status {
            case .nudge: showNudge = true
            case .cooldown: showCooldown = true
            default: break
            }
        }
        .sheet(isPresented: $showNudge) { nudgeSheet(model) }
        .sheet(isPresented: $showCooldown) { cooldownSheet(model) }
    }

    /// `.compose-target`: About · Change, the target at 22 pt, its detail, a rule.
    private func aboutBlock(_ model: ComposerViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x1) {
            HStack(alignment: .center) {
                Text(L10n.t("About")).sectionLabel()
                Spacer()
                if !model.isNote {
                    Button(L10n.t("Change")) {
                        if nav.currentPath.dropLast().last == .compose(nil) { nav.pop() } else { nav.push(.compose(nil)) }
                    }
                    .buttonStyle(.webLink)
                    .padding(.trailing, -HSpace.x2)
                }
            }
            Text(model.label).hfont(.composeTarget).foregroundStyle(theme.ink)
            if let detail = model.detail, !detail.isEmpty {
                Text(detail).hfont(.body).foregroundStyle(theme.muted)
            }
        }
        .padding(.vertical, HSpace.x3)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private func draftFailed(_ model: ComposerViewModel) -> Bool {
        if case .failed = model.saveState { return true }
        return false
    }

    private func draftLine(_ model: ComposerViewModel) -> String {
        switch model.saveState {
        case .saving: return L10n.t("Saving…")
        case .failed(let message): return message
        case .saved, .idle: return L10n.t("Draft saved on this device")
        }
    }

    private func noticeBanner(_ notice: ComposerNotice) -> some View {
        let reasons = ModerationCopy.describeReasons(notice.reasons)
        return VStack(alignment: .leading, spacing: HSpace.x2) {
            Text(notice.text).hfont(.body)
            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    ForEach(reasons, id: \.self) { Text("• \($0)").hfont(.body) }
                }
                .padding(.leading, HSpace.x2)
            }
            if notice.suggestKeepPrivate {
                Text("You can keep it as a private note instead.").hfont(.caption).foregroundStyle(theme.muted)
            }
        }
        .foregroundStyle(notice.tone == .danger ? theme.danger : theme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HSpace.x4)
        .padding(.vertical, HSpace.x3)
        .background(theme.tint(notice.tone == .danger ? theme.palette.danger : theme.palette.accent, 0.08), in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.tint(notice.tone == .danger ? theme.palette.danger : theme.palette.accent, 0.38), lineWidth: 1))
    }

    /// `.compose-actions` on phones: full-width, primary then ghost.
    private func actions(_ model: ComposerViewModel) -> some View {
        PrimaryBottomActionBar(
            primary: (primaryLabel(model), {
                editing = false
                Task { await model.continueToShare() }
            }),
            primaryEnabled: model.canAct && pauseRemaining == nil,
            secondary: (model.busySavingNote ? L10n.t("Saving…") : L10n.t("Keep private"), {
                editing = false
                Task { await model.keepPrivate() }
            }),
            secondaryEnabled: model.canAct && !model.busySavingNote
        )
        .padding(.top, HSpace.x3)
    }

    private var privacyLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.t(ModerationCopy.privacyLine)).hfont(.caption).foregroundStyle(theme.muted)
            Button(L10n.t("How anonymity works")) { nav.push(.settingsPrivacy) }
                .buttonStyle(WebLinkStyle(role: .caption))
                .frame(minHeight: 0)
        }
    }

    private func primaryLabel(_ model: ComposerViewModel) -> String {
        if model.checking { return L10n.t("Checking…") }
        if let remaining = pauseRemaining { return "\(L10n.t("Share in")) \(Formatters.remaining(remaining))" }
        if model.note?.cooldown != nil { return L10n.t("Share now") }
        return L10n.t("Continue to share")
    }

    // MARK: Decision surfaces (`.nudge`)

    private func nudgeSheet(_ model: ComposerViewModel) -> some View {
        NudgeSheet(label: L10n.t("Before you share")) {
            Text(L10n.t(ModerationCopy.nudgeQuestion)).hfont(.body).foregroundStyle(theme.ink)
            if case .nudge(let reasons) = model.status {
                let described = ModerationCopy.describeReasons(reasons)
                if !described.isEmpty {
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        ForEach(described, id: \.self) { Text("• \($0)").hfont(.body).foregroundStyle(theme.ink) }
                    }
                    .padding(.leading, HSpace.x2)
                }
            }
        } actions: {
            Button(L10n.t("Share as written")) { showNudge = false; Task { await model.shareAsWritten() } }.buttonStyle(.webBlockPrimary)
            Button(L10n.t("Add a little context")) { showNudge = false; Task { await model.addContext() } }.buttonStyle(.webBlockGhost)
            Button(L10n.t("Keep private")) { showNudge = false; Task { await model.keepPrivate() } }.buttonStyle(.webBlockGhost)
        }
        .interactiveDismissDisabled()
    }

    private func cooldownSheet(_ model: ComposerViewModel) -> some View {
        NudgeSheet(label: L10n.t(ModerationCopy.cooldownTitle)) {
            if case .cooldown(let retryAt, _) = model.status {
                if model.cooldownSaveFailed {
                    Text(ModerationCopy.cooldownSaveFailed).hfont(.body).foregroundStyle(theme.ink)
                    Text("You can share these words in \(Formatters.remaining(retryAt - HOneyClock.now().epochMillis)).").hfont(.body).foregroundStyle(theme.muted)
                } else {
                    Text("Your words are kept in your private notes on this iPhone. You can share them in \(Formatters.remaining(retryAt - HOneyClock.now().epochMillis)) — or edit them to say it differently and check again sooner.").hfont(.body).foregroundStyle(theme.ink)
                }
            }
            Text(L10n.t(ModerationCopy.cooldownNote)).hfont(.body).foregroundStyle(theme.muted)
        } actions: {
            if model.cooldownSaveFailed {
                Button("Try keeping it again") { showCooldown = false; Task { await model.keepPrivate() } }.buttonStyle(.webBlockPrimary)
                Button("Copy my words") { UIPasteboard.general.string = model.body }.buttonStyle(.webBlockGhost)
                Button("Stay in the editor") { showCooldown = false }.buttonStyle(.webBlockGhost)
            } else {
                Button(L10n.t("OK")) {
                    showCooldown = false
                    nav.pop()
                    nav.push(.mine)
                }.buttonStyle(.webBlockPrimary)
            }
        }
        .interactiveDismissDisabled()
    }
}

/// `.nudge` on phones: a bottom sheet on the solid surface — a section
/// label, the prose, the stacked actions. No grabber, no close: a decision.
struct NudgeSheet<Content: View, Actions: View>: View {
    @Environment(\.theme) private var theme
    let label: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x3) {
                Text(label).sectionLabel()
                content()
                VStack(spacing: HSpace.x2) { actions() }
                    .padding(.top, HSpace.x2)
            }
            .padding(.horizontal, HSpace.x4)
            .padding(.top, HSpace.x5)
            .padding(.bottom, HSpace.x5)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.surfaceSolid.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(HRadius.modal)
        .presentationBackground(theme.surfaceSolid)
    }
}

extension View {
    /// `.card` (line, 16 radius, card ground, 20 in) or `.card--hero`
    /// (solid ground, 18 radius, the shadow).
    func webCard(hero: Bool = false) -> some View { modifier(WebCardModifier(hero: hero)) }
}

private struct WebCardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let hero: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HSpace.x5)
            .background(hero ? theme.surfaceSolid : theme.card, in: RoundedRectangle(cornerRadius: hero ? HRadius.hero : HRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: hero ? HRadius.hero : HRadius.card, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
            .shadow(color: hero ? theme.shadow : .clear, radius: hero ? 20 : 0, y: hero ? 14 : 0)
    }
}
