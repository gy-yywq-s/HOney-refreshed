// Settings › Post controls (Web: pages/settings/PostControlsPage.tsx +
// RecoveryWordsPage / PairDevicePage / RotateRootPage; spec §35–§40): one
// client-generated root controls every public post; this screen shows
// whether the root is on this iPhone, how it can be restored (another
// device · recovery words) and the advanced actions. Copy states only what
// the protocol provides; success appears only after a durable write was
// read back. Passkey (PRF) wrappers set up on the Web are listed; adding
// one from the iPhone is not offered in this build.

import SwiftUI
import HOneyCore

@MainActor
@Observable
final class PostControlsViewModel {
    private let env: AppEnvironment
    private(set) var status: PostControlsStatus?
    private(set) var error: String?
    private(set) var busy: String?
    var feedback: (tone: BannerTone, text: String)?

    init(env: AppEnvironment) { self.env = env }

    private var account: String { env.scope?.honeyId ?? "" }

    var wrappers: [VaultWrapper] {
        if case .ready(_, _, let wrappers) = status { return wrappers }
        return []
    }

    var hasWords: Bool { wrappers.contains { if case .recoveryPhrase = $0 { return true } else { return false } } }
    var passkeyLabels: [String] { wrappers.compactMap { if case .passkeyPrf(let w) = $0 { return w.label ?? "Passkey" } else { return nil } } }

    func load() async {
        error = nil
        do {
            status = try await env.postControls.status(account: account)
        } catch {
            self.error = APIErrorCopy.describe(error)
        }
    }

    private func epochs() async -> [SchoolEpoch] {
        var out: [SchoolEpoch] = []
        if let roots = try? await env.postControls.unlock(account: account) {
            out = await env.postControls.epochs(account: account, roots: roots)
        }
        if let session = try? await env.publish.communitySession(), !out.contains(session.scope.epoch) { out.append(session.scope.epoch) }
        return out
    }

    func run(_ key: String, _ work: () async throws -> Void) async {
        busy = key
        feedback = nil
        defer { busy = nil }
        do {
            try await work()
            await load()
        } catch let e as PostControlsError {
            feedback = (.danger, describe(e))
        } catch {
            feedback = (.danger, APIErrorCopy.describe(error))
        }
    }

    func describe(_ e: PostControlsError) -> String {
        switch e {
        case .vaultExists: return PostControlsCopy.restoreExplain
        case .noLocalRoots: return "There are no post controls on this iPhone yet."
        case .restoreNeeded: return PostControlsCopy.restoreExplain
        case .readbackFailed: return "The backup could not be verified after saving. Nothing changed."
        case .wrongWords: return PostControlsCopy.wordsWrong
        case .pairingExpired: return "That code has expired. Start again on the new device."
        }
    }

    func create() async {
        await run("create") {
            let epoch = try await env.publish.communitySession().scope.epoch
            _ = try await env.postControls.create(account: account, epoch: epoch)
            feedback = (.success, PostControlsCopy.createdLocal)
        }
    }

    /// Returns the 12 words only after the vault write was read back.
    func setupWords() async -> [String]? {
        var words: [String]?
        await run("words") {
            words = try await env.postControls.setupRecoveryWords(account: account, epochs: await epochs())
        }
        return words
    }

    func restore(words: String) async -> Bool {
        var ok = false
        await run("restore") {
            _ = try await env.postControls.restore(account: account, words: words)
            await env.feedStore.invalidateAll()
            ok = true
        }
        return ok
    }

    func beginPairing() async -> (offer: PairingOffer, privateKey: String)? {
        var out: (PairingOffer, String)?
        await run("pair") { out = try await env.postControls.beginPairing(account: account) }
        return out
    }

    func claim(pairingId: String, privateKey: String) async -> Bool? {
        do {
            let roots = try await env.postControls.claimPairing(account: account, pairingId: pairingId, privateKey: privateKey)
            if roots != nil {
                await load()
                await env.feedStore.invalidateAll()
                return true
            }
            return false
        } catch {
            feedback = (.danger, APIErrorCopy.describe(error))
            return nil
        }
    }

    func deliver(code: String) async {
        await run("deliver") {
            try await env.postControls.deliverPairing(account: account, pairingId: code.trimmingCharacters(in: .whitespaces).uppercased()) // case-allowed: the pairing code is relay data, not a label style
            feedback = (.success, "Delivered. The other device now has your post controls.")
        }
    }

    func rotate() async {
        await run("rotate") {
            _ = try await env.postControls.rotate(account: account, epochs: await epochs())
            feedback = (.success, "Replaced. New posts use the new root; older posts stay under your control.")
        }
    }

    func eraseLocal() async {
        await run("erase") {
            try await env.postControls.eraseLocal(account: account)
            feedback = (.success, "Removed from this iPhone.")
        }
    }
}

struct PostControlsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @State private var model: PostControlsViewModel?
    @State private var confirmErase = false

    var body: some View {
        Group {
            if let model { content(model) } else { LoadingPlaceholder(lines: 4).pageInset() }
        }
        .webScreen(title: L10n.t("Post controls"))
        .task {
            if model == nil { model = PostControlsViewModel(env: env) }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: PostControlsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Post controls"))
                if let feedback = model.feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone) }
                if let error = model.error {
                    InlineStatusBanner(text: error, tone: .danger, action: (L10n.t("Try again"), { Task { await model.load() } }))
                }
                switch model.status {
                case nil:
                    LoadingPlaceholder(lines: 3)
                case .none:
                    Text("One control root on this iPhone signs every experience you share and lets you remove it later. It is created the first time you share; you can also set it up now.")
                        .hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.t("Set up post controls")) { Task { await model.create() } }.buttonStyle(.webBlockPrimary).disabled(model.busy != nil)
                    RowList(label: L10n.t("Already have post controls?")) {
                        Button { nav.push(.settingsPairDevice) } label: { SettingsRow(title: L10n.t("Another device")) }.buttonStyle(.plain)
                        Button { nav.push(.settingsRecoveryWords) } label: { SettingsRow(title: L10n.t("12 recovery words")) }.buttonStyle(.plain)
                    }
                case .restoreNeeded:
                    Text(PostControlsCopy.restoreNeeded).hfont(.bodySemibold).foregroundStyle(theme.ink)
                    Text(PostControlsCopy.restoreExplain).hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    RowList(label: L10n.t("Restore with")) {
                        Button { nav.push(.settingsPairDevice) } label: { SettingsRow(title: L10n.t("Another device")) }.buttonStyle(.plain)
                        Button { nav.push(.settingsRecoveryWords) } label: { SettingsRow(title: L10n.t("12 recovery words")) }.buttonStyle(.plain)
                    }
                case .localOnly:
                    Text(PostControlsCopy.createdLocal).hfont(.bodySemibold).foregroundStyle(theme.ink)
                    Text("Not backed up yet. Set up your 12 recovery words so a new phone — or this one after a reinstall — can restore them.")
                        .hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.t("Set up recovery words")) { nav.push(.settingsRecoveryWords) }.buttonStyle(.webBlockPrimary)
                    advanced(model)
                case .ready:
                    Text(PostControlsCopy.ready).hfont(.bodySemibold).foregroundStyle(theme.ink)
                    RowList(label: L10n.t("Ways to restore")) {
                        Button { nav.push(.settingsRecoveryWords) } label: {
                            SettingsRow(title: L10n.t("12 recovery words"), sub: model.hasWords ? L10n.t("Set up") : L10n.t("Not set up"))
                        }
                        .buttonStyle(.plain)
                        Button { nav.push(.settingsPairDevice) } label: {
                            SettingsRow(title: L10n.t("Another device"), sub: L10n.t("Enter a code from a new device"))
                        }
                        .buttonStyle(.plain)
                        ForEach(model.passkeyLabels, id: \.self) { label in
                            SettingsRow(title: L10n.t("Passkey"), sub: label, trailing: .none)
                        }
                    }
                    advanced(model)
                }
            }
            .refreshAnchor()
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await model.load() }
        .sheet(isPresented: $confirmErase) {
            ConfirmSheet(
                title: "Remove post controls from this iPhone?",
                message: PostControlsCopy.eraseExplain,
                confirmLabel: "Remove from this iPhone",
                danger: true,
                busy: model.busy == "erase",
                onCancel: { confirmErase = false },
                onConfirm: { confirmErase = false; Task { await model.eraseLocal() } }
            )
        }
    }

    private func advanced(_ model: PostControlsViewModel) -> some View {
        RowList(label: L10n.t("Advanced")) {
            Button { nav.push(.settingsReplaceRoot) } label: { SettingsRow(title: L10n.t("Replace control root")) }.buttonStyle(.plain)
            ControlRow(title: L10n.t("Remove from this iPhone"), sub: PostControlsCopy.eraseExplain) {
                Button(L10n.t("Remove…")) { confirmErase = true }.buttonStyle(.webSmallDangerOutline).disabled(model.busy != nil)
            }
        }
    }
}

/// Setup shows the 12 words and asks two back; restore takes them in.
struct RecoveryWordsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: PostControlsViewModel?
    @State private var words: [String]?
    @State private var quiz: (Int, Int)?
    @State private var answers = ["", ""]
    @State private var done = false
    @State private var input = ""
    @State private var restored = false

    private var restoreMode: Bool {
        if let status = model?.status {
            if case .restoreNeeded = status { return true }
            if case .none = status { return true }
        }
        return false
    }

    var body: some View {
        Group {
            if let model { content(model) } else { LoadingPlaceholder(lines: 4).pageInset() }
        }
        .webScreen(title: L10n.t("Recovery words"))
        .task {
            if model == nil { model = PostControlsViewModel(env: env) }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: PostControlsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Recovery words"))
                if let feedback = model.feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone) }
                if restoreMode {
                    restoreForm(model)
                } else if done {
                    Text(L10n.t("Recovery words ready")).hfont(.bodySemibold).foregroundStyle(theme.ok)
                    Text("The encrypted backup was saved and read back. Keep the words somewhere safe.").hfont(.body).foregroundStyle(theme.muted)
                    Button(L10n.t("Done")) { nav.pop() }.buttonStyle(.webBlockPrimary)
                } else if let words, let quiz {
                    quizForm(words: words, quiz: quiz)
                } else if let words {
                    wordsGrid(words)
                    Button(L10n.t("I've saved them")) { quiz = Self.pickQuiz() }.buttonStyle(.webBlockPrimary)
                } else {
                    Text(PostControlsCopy.wordsExplain).hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    if model.hasWords {
                        Text("Words are already set up. Generating new ones replaces the old ones.").hfont(.caption).foregroundStyle(theme.muted)
                    }
                    Button(model.hasWords ? L10n.t("Generate new words") : L10n.t("Show my 12 words")) {
                        Task { words = await model.setupWords() }
                    }
                    .buttonStyle(.webBlockPrimary)
                    .disabled(model.busy != nil)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
    }

    private func wordsGrid(_ words: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: HSpace.x2) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: HSpace.x1) {
                    Text("\(index + 1)").font(ramp.font(.caption)).foregroundStyle(theme.muted).frame(width: 22, alignment: .trailing)
                    Text(word).font(.system(.body, design: .monospaced)).foregroundStyle(theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HSpace.x2)
                .background(theme.soft, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            }
        }
        .accessibilityLabel(L10n.t("Recovery words"))
    }

    static func pickQuiz() -> (Int, Int) {
        let a = Int.random(in: 0..<12)
        var b = Int.random(in: 0..<11)
        if b >= a { b += 1 }
        return (min(a, b), max(a, b))
    }

    private func quizForm(words: [String], quiz: (Int, Int)) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            Text("Check two of them:").hfont(.body).foregroundStyle(theme.muted)
            ForEach(0..<2, id: \.self) { i in
                let position = i == 0 ? quiz.0 : quiz.1
                VStack(alignment: .leading, spacing: HSpace.x1) {
                    Text("Word \(position + 1)?").font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2)
                    TextField("", text: $answers[i]).textFieldStyle(WebFieldStyle()).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Button(L10n.t("Confirm")) {
                if answers[0].lowercased().trimmingCharacters(in: .whitespaces) == words[quiz.0], answers[1].lowercased().trimmingCharacters(in: .whitespaces) == words[quiz.1] {
                    done = true
                } else {
                    model?.feedback = (.danger, PostControlsCopy.wordsWrong)
                }
            }
            .buttonStyle(.webBlockPrimary)
            .disabled(answers.contains { $0.isEmpty })
            Button(L10n.t("Show the words again")) { self.quiz = nil }.buttonStyle(.webBlockGhost)
        }
    }

    private func restoreForm(_ model: PostControlsViewModel) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x3) {
            if restored {
                Text("Restored. Your post controls are on this iPhone.").hfont(.bodySemibold).foregroundStyle(theme.ok)
                Button(L10n.t("Done")) { nav.pop() }.buttonStyle(.webBlockPrimary)
            } else {
                Text("Enter your 12 recovery words, in order, separated by spaces.").hfont(.body).foregroundStyle(theme.muted)
                TextField("", text: $input, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(WebFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel(L10n.t("Recovery words"))
                let valid = RecoveryWords.secret(from: input) != nil
                Button(L10n.t("Restore")) { Task { restored = await model.restore(words: input) } }
                    .buttonStyle(.webBlockPrimary)
                    .disabled(!valid || model.busy != nil)
                if !input.isEmpty, !valid {
                    Text(PostControlsCopy.wordsWrong).hfont(.caption).foregroundStyle(theme.muted)
                }
            }
        }
    }
}

/// Another device: this iPhone either receives (shows a code, waits) or
/// gives (enters the code from the new device).
struct PairDeviceView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var model: PostControlsViewModel?
    @State private var offer: (PairingOffer, String)?
    @State private var code = ""
    @State private var restored = false
    @State private var polling: Task<Void, Never>?

    private var receiving: Bool {
        if let status = model?.status {
            if case .restoreNeeded = status { return true }
            if case .none = status { return true }
        }
        return false
    }

    var body: some View {
        Group {
            if let model { content(model) } else { LoadingPlaceholder(lines: 4).pageInset() }
        }
        .webScreen(title: L10n.t("Another device"))
        .task {
            if model == nil { model = PostControlsViewModel(env: env) }
            await model?.load()
        }
        .onDisappear { polling?.cancel() }
    }

    @ViewBuilder
    private func content(_ model: PostControlsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Another device"))
                if let feedback = model.feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone) }
                if receiving {
                    if restored {
                        Text("Restored. Your post controls are on this iPhone.").hfont(.bodySemibold).foregroundStyle(theme.ok)
                        Button(L10n.t("Done")) { nav.pop() }.buttonStyle(.webBlockPrimary)
                    } else if let offer {
                        Text(PostControlsCopy.pairExplain).hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                        Text(offer.0.pairingId)
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(HSpace.x4)
                            .background(theme.soft, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                            .accessibilityLabel("Code \(offer.0.pairingId)")
                        Text("Waiting for the other device… the code works for a few minutes.").hfont(.caption).foregroundStyle(theme.muted)
                    } else {
                        Text("Get a code to show on the device that already has your post controls.").hfont(.body).foregroundStyle(theme.muted)
                        Button(L10n.t("Get a code")) { Task { await begin(model) } }.buttonStyle(.webBlockPrimary).disabled(model.busy != nil)
                    }
                } else {
                    Text("On the new device, open Settings › Post controls › Another device and get a code. Enter it here to send your post controls to it, sealed so only that device can open them.")
                        .hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                    TextField("Code", text: $code).textFieldStyle(WebFieldStyle()).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button(L10n.t("Send post controls")) { Task { await model.deliver(code: code) } }
                        .buttonStyle(.webBlockPrimary)
                        .disabled(code.trimmingCharacters(in: .whitespaces).count < 6 || model.busy != nil)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
    }

    private func begin(_ model: PostControlsViewModel) async {
        guard let started = await model.beginPairing() else { return }
        offer = started
        polling?.cancel()
        polling = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                if let ok = await model.claim(pairingId: started.offer.pairingId, privateKey: started.privateKey) {
                    if ok { restored = true; return }
                } else {
                    return
                }
                if HOneyClock.now().epochMillis > started.offer.expiresAt {
                    model.feedback = (.warning, "That code expired. Get a new one.")
                    offer = nil
                    return
                }
            }
        }
    }
}

struct ReplaceRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @State private var model: PostControlsViewModel?
    @State private var confirm = false

    var body: some View {
        Group {
            if let model {
                ScrollView {
                    VStack(alignment: .leading, spacing: HSpace.x4) {
                        PageTitle(text: L10n.t("Replace control root"))
                        if let feedback = model.feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone) }
                        Text(PostControlsCopy.replaceExplain).hfont(.body).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                        Text("Do this if you think the root on a device may have leaked. Posts already shared stay under your control through the retired root.")
                            .hfont(.caption).foregroundStyle(theme.muted).fixedSize(horizontal: false, vertical: true)
                        Button(L10n.t("Replace…")) { confirm = true }.buttonStyle(.webBlockDanger).disabled(model.busy != nil)
                    }
                    .pageInset()
                    .padding(.top, HSpace.x2)
                    .padding(.bottom, HSpace.x4)
                }
                .sheet(isPresented: $confirm) {
                    ConfirmSheet(
                        title: "Replace the control root?",
                        message: PostControlsCopy.replaceExplain,
                        confirmLabel: "Replace",
                        danger: true,
                        busy: model.busy == "rotate",
                        onCancel: { confirm = false },
                        onConfirm: { confirm = false; Task { await model.rotate() } }
                    )
                }
            } else {
                LoadingPlaceholder(lines: 3).pageInset()
            }
        }
        .webScreen(title: L10n.t("Replace control root"))
        .task {
            if model == nil { model = PostControlsViewModel(env: env) }
            await model?.load()
        }
    }
}
