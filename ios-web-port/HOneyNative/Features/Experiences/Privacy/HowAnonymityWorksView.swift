// How anonymity works (SettingsPage.tsx privacy section; fidelity spec v2
// §15): the muted lead paragraph, the five claims as a bulleted list with a
// bold first sentence, then the "Post controls on this device" row group
// with small ghost Export / Import. Only claims the current server protocol
// supports, with the native storage story instead of browser caveats.

import SwiftUI
import UniformTypeIdentifiers
import HOneyCore

struct HowAnonymityWorksView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var keyCount = 0
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var feedback: (tone: BannerTone, text: String)?

    private let claims: [(String, String)] = [
        ("Published posts are stored without an author ID.",
         "The publish request carries no ordinary account identity, so the stored post has nothing that says who wrote it — HOney provides no normal author lookup, for anyone, including admins. The words themselves can still make you recognisable to people who know the situation."),
        ("Your control is a key on this iPhone.",
         "Each publish returns a one-time control key stored in this iPhone's Keychain; the server keeps only a hash. Presenting the key is the only way to find or remove your post. Deleting or reinstalling the app removes local control unless you export the keys first."),
        ("Public dates are coarse.",
         "Posts show a calendar day only; exact timestamps are never published."),
        ("How moderation handles your text.",
         "When you run the pre-publish check, obvious rule-breaking wording is caught on the HOney server directly. Otherwise the draft text — the text only, never your identity — is sent once to an external moderation model and judged transiently; HOney stores neither the text nor the verdict at check time. The external provider processes the text under its own retention policy, so don't put things in a draft you wouldn't run through a moderation service."),
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

                RowList(label: L10n.t("Post controls on this iPhone"), first: false) {
                    VStack(alignment: .leading, spacing: HSpace.x3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Control keys on this iPhone").font(ramp.font(.bodySemibold)).foregroundStyle(theme.ink)
                            Text(keyCount == 0
                                 ? "None yet — keys appear here when you publish an experience."
                                 : "\(keyCount) key\(keyCount > 1 ? "s" : ""). Export a backup before deleting the app or moving to a new phone.")
                                .font(ramp.font(.caption))
                                .lineSpacing(ramp.lineSpacing(.caption))
                                .foregroundStyle(theme.muted)
                        }
                        HStack(spacing: HSpace.x2) {
                            if let exportURL {
                                ShareLink(item: exportURL) { Text("Export") }
                                    .buttonStyle(.webSmallGhost)
                                    .disabled(keyCount == 0)
                            } else {
                                Button("Export") {}.buttonStyle(.webSmallGhost).disabled(true)
                            }
                            Button("Import…") { importing = true }.buttonStyle(.webSmallGhost)
                        }
                        Text("Import accepts a HOney key export from the Web app or a device bundle with notes and keys.")
                            .font(ramp.font(.caption))
                            .foregroundStyle(theme.muted)
                    }
                    .padding(.vertical, HSpace.x3)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("How anonymity works"))
        .task { refresh() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            Task { await importFile(result) }
        }
    }

    private func refresh() {
        keyCount = env.keys.count()
        exportURL = nil
        guard let data = try? env.keys.exportJSON() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HOney-ownership-keys.json")
        if (try? data.write(to: url, options: [.atomic, .completeFileProtection])) != nil { exportURL = url }
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
            feedback = (.danger, "That file is not a HOney key export or device bundle.")
            return
        }
        if let hint = bundle.accountHint, let me = env.me, hint != me.honeyId {
            feedback = (.warning, "That bundle was exported from a different HOney account; nothing was imported.")
            return
        }
        let report = await bundle.apply(keys: env.keys, notes: env.notes)
        var parts: [String] = []
        parts.append(report.keysAdded == 0 ? "No new keys" : "Imported \(report.keysAdded) new key\(report.keysAdded > 1 ? "s" : "")")
        if !bundle.privateNotes.isEmpty { parts.append("\(report.notesAdded) note\(report.notesAdded == 1 ? "" : "s") added") }
        feedback = (report.failures.isEmpty ? .success : .warning, (parts + report.failures).joined(separator: ". ") + ".")
        refresh()
    }
}
