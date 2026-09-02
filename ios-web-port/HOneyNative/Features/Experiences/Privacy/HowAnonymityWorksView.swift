// How anonymity works (spec §22): only claims the current server protocol
// supports, with the native storage story (Keychain, protected files)
// instead of browser caveats, and the control-key management row with
// export / import for device transfer.

import SwiftUI
import UniformTypeIdentifiers
import HOneyCore

struct HowAnonymityWorksView: View {
    @Environment(AppEnvironment.self) private var env
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
        List {
            Section {
                Text("The plain version: HOney checks you actually have the relevant experience, published posts are not attached to your school account, and this iPhone holds the control needed to remove your own post. The detail, honestly:")
                    .font(HType.body)
                    .foregroundStyle(Color.honeyInk)
                    .listRowBackground(Color.clear)
                ForEach(claims, id: \.0) { title, body in
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        Text(title).font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                        Text(body).font(HType.secondary).foregroundStyle(Color.honeySecondary)
                    }
                    .padding(.vertical, HSpace.x1)
                    .listRowBackground(Color.clear)
                }
            }
            Section {
                if let feedback {
                    InlineStatusBanner(text: feedback.text, tone: feedback.tone).listRowBackground(Color.clear)
                }
                VStack(alignment: .leading, spacing: HSpace.x2) {
                    Text("Control keys on this iPhone").font(HType.body).foregroundStyle(Color.honeyInk)
                    Text(keyCount == 0
                         ? "None yet — keys appear here when you publish an experience."
                         : "\(keyCount) key\(keyCount > 1 ? "s" : ""). Export a backup before deleting the app or moving to a new phone.")
                        .font(HType.meta).foregroundStyle(Color.honeySecondary)
                    HStack(spacing: HSpace.x3) {
                        if let exportURL {
                            ShareLink(item: exportURL) { Label("Export", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered)
                                .disabled(keyCount == 0)
                        }
                        Button { importing = true } label: { Label("Import…", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.bordered)
                    }
                    .controlSize(.small)
                    Text("Import accepts a HOney key export from the Web app or a device bundle with notes and keys.")
                        .font(HType.micro).foregroundStyle(Color.honeyTertiary)
                }
                .listRowBackground(Color.clear)
            } header: {
                Text(L10n.t("Post controls on this iPhone")).eyebrow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("How anonymity works"))
        .navigationBarTitleDisplayMode(.inline)
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
