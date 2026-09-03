// How anonymity works (SettingsPage.tsx privacy section; fidelity spec v2
// §15; Anonymous Control v2 spec §41): the muted lead paragraph, the claims
// as a bulleted list with a bold first sentence, then the row to Post
// controls and the private-notes bundle import. Only claims the current
// protocol supports, with the native storage story.

import SwiftUI
import UniformTypeIdentifiers
import HOneyCore

struct HowAnonymityWorksView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var importing = false
    @State private var feedback: (tone: BannerTone, text: String)?

    private let claims: [(String, String)] = [
        ("Published posts carry no account.",
         "A post is signed by a posting key that this iPhone derives from a control root it generated; the HOney server that knows your account never sees the post, and the process that stores posts has no account database at all. The words themselves can still make you recognisable to people who know the situation."),
        ("Eligibility is proven without being tracked.",
         "Before you share, HOney checks that you actually had the class or place and issues a blind token: it signs something it cannot read, so it cannot later tell which post came from which check."),
        ("Your control is a root on this iPhone.",
         "Every post gets its own control key derived from the root. The root lives in this iPhone's Keychain; an encrypted backup (the Control Vault) lets you restore it with your recovery words or from another device. HOney stores only ciphertext it cannot open."),
        ("Public dates are coarse.",
         "Posts show a calendar day only; exact timestamps are never published."),
        ("How moderation handles your text.",
         "When you run the pre-publish check, obvious rule-breaking wording is caught directly. Otherwise the draft text — the text only, never your identity — is sent once to an external moderation model and judged transiently; HOney stores neither the text nor the verdict at check time."),
        ("Private notes stay on this iPhone.",
         "They live in protected app storage, encrypted by the device while it is locked, and never leave the phone. Your school login (when you keep it) and your HOney session live in the Keychain, on this device only — nothing here syncs through iCloud Keychain."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("How anonymity works"))
                if let feedback {
                    InlineStatusBanner(text: feedback.text, tone: feedback.tone)
                }
                Text("The plain version: HOney checks you actually have the relevant experience, published posts are not attached to your school account, and this iPhone holds the control needed to remove your own post. The detail, honestly:")
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: HSpace.x2) {
                    ForEach(claims, id: \.0) { title, body in
                        HStack(alignment: .firstTextBaseline, spacing: HSpace.x2) {
                            Text("•")
                            (Text(title).fontWeight(.semibold) + Text(" " + body))
                        }
                        .hfont(.body)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, HSpace.x4)
                .padding(.bottom, HSpace.x3)

                RowList(label: L10n.t("Post controls"), first: false) {
                    Button { nav.push(.settingsPostControls) } label: {
                        SettingsRow(title: L10n.t("Post controls"), sub: L10n.t("Recovery words · another device · replace the root"))
                    }
                    .buttonStyle(.plain)
                }

                RowList(label: L10n.t("Private notes")) {
                    VStack(alignment: .leading, spacing: HSpace.x3) {
                        Text("Import a HOney notes bundle exported from another device. Post controls never travel as a file — restore them above.")
                            .font(ramp.font(.caption))
                            .foregroundStyle(theme.muted)
                        Button("Import notes…") { importing = true }.buttonStyle(.webSmallGhost)
                    }
                    .padding(.vertical, HSpace.x3)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("How anonymity works"))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            Task { await importFile(result) }
        }
    }

    private func importFile(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            feedback = (.danger, "That file could not be read.")
            return
        }
        guard let bundle = try? TransferBundle.decode(data) else {
            feedback = (.danger, "That file is not a HOney notes bundle.")
            return
        }
        if let hint = bundle.accountHint, let me = env.me, hint != me.honeyId {
            feedback = (.warning, "That bundle was exported from a different HOney account; nothing was imported.")
            return
        }
        let report = await bundle.apply(notes: env.notes)
        let added = "\(report.notesAdded) note\(report.notesAdded == 1 ? "" : "s") added"
        feedback = (report.failures.isEmpty ? .success : .warning, ([added] + report.failures).joined(separator: ". ") + ".")
    }
}
