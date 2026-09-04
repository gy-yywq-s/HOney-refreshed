// Settings (SettingsPage.tsx + features.css `.rowlist`, `.row`, `.switch`,
// `.theme-dialog__section`, `.option-grid`, `.chip-tab`; fidelity spec v2
// §13): open row groups on the surface, each parted from the last by a
// rule above its sentence-case label — Account, School connection,
// Experiences & privacy, Appearance, About, Admin — and the Appearance
// page with every current Web choice: Background, Accent, Text size,
// Language. Settings stays the fifth tab.

import SwiftUI
import HOneyCore

struct SettingsRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @Environment(\.theme) private var theme
    @State private var stayConnected = true
    @State private var showSaveLogin = false
    /// What the app shows, as Dash set it (Web: lib/useFeatures.ts).
    @State private var features = FeatureFlags.defaults
    @State private var tellSchool = false

    private var connectionLine: String {
        guard let c = env.me?.connection else { return "" }
        if !c.connected { return L10n.t("Not connected") }
        if !c.portalTokenValid { return "\(L10n.t("Connected")) · \(L10n.t("portal session expired"))" }
        if let last = c.lastSyncedAt { return "\(L10n.t("Connected")) · \(L10n.t("synced")) \(Formatters.timeAgo(last))" }
        return "\(L10n.t("Connected")) · \(L10n.t("never synced"))"
    }

    var body: some View {
        let store = env.themeStore
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                        PageTitle(text: "Settings")
                        if let notice = env.loginNotice {
                            InlineStatusBanner(text: notice, tone: .warning, action: ("OK", { env.loginNotice = nil }))
                        }
                        RowList(label: L10n.t("Account"), first: true) {
                            Button { nav.push(.settingsAccount) } label: {
                                SettingsRow(title: env.me?.displayName ?? "", sub: "HOney ID \(env.me?.honeyId ?? "")")
                            }
                            .buttonStyle(.plain)
                        }
                        RowList(label: L10n.t("School connection")) {
                            Button { nav.push(.settingsConnection) } label: {
                                SettingsRow(title: connectionLine, sub: L10n.t("Sync, saved login, imported data"))
                            }
                            .buttonStyle(.plain)
                            StayConnectedRow(stayConnected: $stayConnected, showSaveLogin: $showSaveLogin)
                        }
                        // The student's own records at the school (Gary 2026-09-03):
                        // read live from the portal when opened, never stored by HOney.
                        RowList(label: L10n.t("At school")) {
                            Button { nav.push(.settingsCard) } label: { SettingsRow(title: L10n.t("Campus card"), sub: L10n.t("Balance, spending")) }.buttonStyle(.plain)
                            Button { nav.push(.settingsWeekend) } label: { SettingsRow(title: L10n.t("Weekend stay"), sub: L10n.t("Days on record")) }.buttonStyle(.plain)
                            if features.lessonFeedback {
                                Button { nav.push(.settingsLessonFeedback) } label: { SettingsRow(title: L10n.t("Lesson feedback"), sub: L10n.t("Lessons waiting for yours")) }.buttonStyle(.plain)
                            }
                            if features.schoolFeedback {
                                Button { tellSchool = true } label: { SettingsRow(title: L10n.t("Feedback to the school"), sub: L10n.t("Sent from your school account")) }.buttonStyle(.plain)
                            }
                            Button { nav.push(.settingsRecord) } label: { SettingsRow(title: L10n.t("School record"), sub: L10n.t("What the school has recorded")) }.buttonStyle(.plain)
                        }
                        RowList(label: L10n.t("Experiences & privacy")) {
                            Button { nav.push(.mine) } label: { SettingsRow(title: L10n.t("Your notes & posts")) }.buttonStyle(.plain)
                            Button { nav.push(.settingsPostControls) } label: { SettingsRow(title: L10n.t("Post controls"), sub: L10n.t("Recovery words · another device · replace the root")) }.buttonStyle(.plain)
                            Button { nav.push(.settingsPrivacy) } label: { SettingsRow(title: L10n.t("How anonymity works")) }.buttonStyle(.plain)
                        }
                        RowList(label: L10n.t("Appearance")) {
                            Button { nav.push(.settingsAppearance) } label: {
                                SettingsRow(
                                    title: "\(L10n.t("Background")) · \(L10n.t("Accent")) · \(L10n.t("Text size")) · \(L10n.t("Language"))",
                                    sub: "\(L10n.t(store.background.label)) · \(store.accent.label) · \(L10n.t(store.textSize.label)) · \(L10n.isChinese ? "中文" : "English")"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        RowList(label: L10n.t("About")) {
                            SettingsRow(title: "\(L10n.t("Build")) \(env.config.buildLabel)", sub: env.config.honeyBaseURL.host ?? "", trailing: .none)
                        }
                        if env.me?.isAdmin == true {
                            RowList(label: L10n.t("Admin")) {
                                Button { nav.push(.settingsDash) } label: {
                                    SettingsRow(title: L10n.t("Open Dash"), sub: "\(L10n.t("The operational console for admins.")) \(L10n.t("Opens here, already signed in."))")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
                .frame(minHeight: geo.size.height, alignment: .top)
                .pageInset()
                .padding(.top, HSpace.x2)
                .padding(.bottom, HSpace.x4)
            }
            .honeyRefreshable { await env.refreshMe() }
        }
        .surfaceBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle("Settings")
        .task {
            stayConnected = env.prefs.stayConnectedWanted && env.hasSavedSchoolLogin
            if let flags = try? await env.api.features() { features = flags }
        }
        .sheet(isPresented: $showSaveLogin) {
            SchoolLoginSheet(purpose: .save) { stayConnected = env.prefs.stayConnectedWanted && env.hasSavedSchoolLogin }
        }
        .sheet(isPresented: $tellSchool) { SchoolFeedbackSheet { tellSchool = false } }
    }
}

/// "Stay connected on this device" (`.row` + `.switch`): off deletes the
/// Keychain school login; on asks for it when none is stored yet.
struct StayConnectedRow: View {
    @Environment(AppEnvironment.self) private var env
    @Binding var stayConnected: Bool
    @Binding var showSaveLogin: Bool

    var body: some View {
        ControlRow(title: L10n.t("Stay connected on this device"), sub: L10n.t("Reconnects automatically after routine portal time-outs.")) {
            Toggle(isOn: Binding(
                get: { stayConnected },
                set: { next in
                    Task {
                        await env.setStayConnected(next)
                        if next, !env.hasSavedSchoolLogin {
                            stayConnected = false // on only once the login is really kept
                            showSaveLogin = true
                        } else {
                            stayConnected = next
                        }
                    }
                }
            )) { Text(L10n.t("Stay connected on this device")) }
                .toggleStyle(.webSwitch)
                .labelsHidden()
        }
    }
}

struct AccountView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("Account"))
                if let error { InlineStatusBanner(text: error, tone: .danger) }
                RowList(first: true) {
                    ControlRow(title: env.me?.displayName ?? "", sub: "HOney ID \(env.me?.honeyId ?? "") — your name inside HOney; never shown on published experiences.") {
                        Button(L10n.t("Sign out")) { Task { await env.signOut() } }.buttonStyle(.webSmallDangerOutline)
                    }
                }
                RowList(label: "Delete account and public content") {
                    Text("Removes every experience your post controls on this iPhone can prove is yours, deletes the encrypted backup of those controls, then deletes your HOney account, your imported lessons and the school login saved here. Shared teacher, course, room and lesson entries stay. Private notes on this iPhone are kept unless you choose to erase them.")
                        .hfont(.caption)
                        .foregroundStyle(theme.muted)
                        .padding(.top, HSpace.x1)
                        .padding(.bottom, HSpace.x3)
                    Button(L10n.t("Delete account…")) { confirmDelete = true }.buttonStyle(.webDanger).disabled(busy)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("Account"))
        .sheet(isPresented: $confirmDelete) {
            WebSheet(title: "Delete your HOney account?", onClose: { confirmDelete = false }) {
                Text("Your public experiences are removed first, by proof from this iPhone's post controls; if that cannot complete, nothing is deleted and you are told why. Then the account and imported lessons go, and the school login saved on this iPhone is cleared. This cannot be undone.")
                    .hfont(.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SheetActions {
                    Button("Delete account and public content, keep private notes") { confirmDelete = false; delete(erase: false) }.buttonStyle(.webBlockDanger)
                    Button("Delete account, public content and private notes") { confirmDelete = false; delete(erase: true) }.buttonStyle(.webBlockDanger)
                    Button(L10n.t("Cancel")) { confirmDelete = false }.buttonStyle(.webBlockGhost)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func delete(erase: Bool) {
        busy = true
        Task {
            do {
                let report = try await env.deleteAccount(eraseLocalData: erase)
                if let blocked = report.publicContentBlocked { self.error = blocked }
            } catch {
                self.error = APIErrorCopy.describe(error)
            }
            busy = false
        }
    }
}

struct SchoolConnectionView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var stayConnected = true
    @State private var showSaveLogin = false
    @State private var showReconnect = false
    @State private var busy: String?
    @State private var feedback: (tone: BannerTone, text: String)?
    @State private var confirmDisconnect = false
    @State private var confirmDeleteData = false

    private var connection: Me.Connection? { env.me?.connection }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x4) {
                PageTitle(text: L10n.t("School connection"))
                if let feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone) }
                RowList(first: true) {
                    SettingsRow(title: statusLine, sub: (connection?.connected == true && connection?.portalTokenValid == false) ? "Reconnect to sync again." : nil, trailing: .none)
                    if connection?.connected == true {
                        FlowLayout(spacing: HSpace.x2) {
                            Button(busy == "sync" ? L10n.t("Syncing with school…") : L10n.t("Sync now")) { sync() }.buttonStyle(.webPrimary).disabled(busy != nil)
                            if connection?.portalTokenValid == false {
                                Button(L10n.t("Reconnect")) { showReconnect = true }.buttonStyle(.webGhost)
                            }
                            Button(L10n.t("Disconnect")) { confirmDisconnect = true }.buttonStyle(.webGhost).disabled(busy != nil)
                        }
                        .padding(.vertical, HSpace.x3)
                    }
                }
                RowList {
                    StayConnectedRow(stayConnected: $stayConnected, showSaveLogin: $showSaveLogin)
                    DisclosureRow(summary: "How the saved login works") {
                        Text("Sync now signs in again with your saved school login if the portal session expired. Your school login is kept in this iPhone's Keychain — on this device only, never in iCloud Keychain. Turn it off any time; you will re-enter your school password when the portal session ends.")
                            .hfont(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                RowList(label: L10n.t("Imported data")) {
                    SettingsRow(title: L10n.t("Timetable & lesson history"), sub: "Imported from the school portal when your account is created, and again whenever you sync — Sync now, or Sync with school in the Timetable menu.", trailing: .none)
                    DisclosureRow(summary: "What the import is used for") {
                        Text("Your timetable and Now/Next on Home, your lesson history, and which classes count as yours when you share an Experience. Nothing is published from it.")
                            .hfont(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }
                RowList(label: "Delete imported data") {
                    Text("Removes your imported lessons — your timetable and history. Shared teacher, course, room and lesson entries stay. You can import again with Sync now.")
                        .hfont(.caption)
                        .foregroundStyle(theme.muted)
                        .padding(.top, HSpace.x1)
                        .padding(.bottom, HSpace.x3)
                    Button(L10n.t("Delete imported data…")) { confirmDeleteData = true }.buttonStyle(.webDanger).disabled(busy != nil)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .honeyRefreshable { await env.refreshMe() }
        .webScreen(title: L10n.t("School connection"))
        .task { stayConnected = env.prefs.stayConnectedWanted && env.hasSavedSchoolLogin }
        .sheet(isPresented: $showSaveLogin) { SchoolLoginSheet(purpose: .save) { stayConnected = env.prefs.stayConnectedWanted && env.hasSavedSchoolLogin } }
        .sheet(isPresented: $showReconnect) { SchoolLoginSheet(purpose: .reconnect) { sync() } }
        .sheet(isPresented: $confirmDisconnect) {
            ConfirmSheet(title: "Disconnect school account?", message: "HOney will stop syncing until you reconnect. Imported data is kept.", confirmLabel: L10n.t("Disconnect"), busy: busy == "disconnect", onCancel: { confirmDisconnect = false }) {
                confirmDisconnect = false
                run("disconnect", "School account disconnected.") { try await env.api.disconnectSchool(); try await env.portalCoordinator.forgetEverything() }
            }
        }
        .sheet(isPresented: $confirmDeleteData) {
            ConfirmSheet(title: "Delete imported data?", message: "Your imported lessons — timetable and history — are removed from HOney. Shared teacher, course, room and lesson entries stay. You can import again with Sync now.", confirmLabel: "Delete imported data", danger: true, busy: busy == "delete-data", onCancel: { confirmDeleteData = false }) {
                confirmDeleteData = false
                run("delete-data", "Imported data deleted.") { try await env.api.deleteImportedData(); await env.timetable.invalidateAll() }
            }
        }
    }

    private var statusLine: String {
        guard let c = connection else { return "" }
        if !c.connected { return L10n.t("Not connected") }
        if !c.portalTokenValid { return "\(L10n.t("Connected")) · \(L10n.t("portal session expired"))" }
        if let last = c.lastSyncedAt { return "\(L10n.t("Connected")) · \(L10n.t("synced")) \(Formatters.timeAgo(last))" }
        return "\(L10n.t("Connected")) · \(L10n.t("never synced"))"
    }

    private func sync() {
        busy = "sync"
        feedback = nil
        Task {
            do {
                let (result, _) = try await env.syncWithSchool()
                switch result.status {
                case .ok: feedback = (.success, "Synced \(result.lessons) lessons from the school portal.")
                case .portalReconnectRequired: showReconnect = true
                default: feedback = (.danger, "Could not sync right now.")
                }
            } catch {
                feedback = (.danger, APIErrorCopy.describe(error))
            }
            busy = nil
        }
    }

    private func run(_ key: String, _ success: String, _ work: @escaping () async throws -> Void) {
        busy = key
        feedback = nil
        Task {
            do {
                try await work()
                await env.refreshMe()
                feedback = (.success, success)
            } catch {
                feedback = (.danger, APIErrorCopy.describe(error))
            }
            busy = nil
        }
    }
}

/// Appearance (ThemeControls.tsx + the Settings page): Background,
/// Accent, Text size, Language — the same names, independent axes, visual
/// swatches, ink-filled selection, live preview.
struct AppearanceView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp

    var body: some View {
        let store = env.themeStore
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(text: L10n.t("Appearance")).padding(.bottom, HSpace.x4)

                themeSection(title: L10n.t("Background"), first: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HSpace.x2), count: 2), spacing: HSpace.x2) {
                        ForEach(HOneyBackground.allCases, id: \.self) { option in
                            OptionCard(label: L10n.t(option.label), swatch: option.swatch.color, selected: store.background == option) {
                                store.choose(background: option)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Background surface")
                }
                themeSection(title: L10n.t("Accent")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: HSpace.x2), count: 3), spacing: HSpace.x2) {
                        ForEach(HOneyAccent.allCases, id: \.self) { option in
                            OptionCard(label: option.label, swatch: (store.background.isNight ? option.nightSwatch : option.swatch).color, selected: store.accent == option) {
                                store.choose(accent: option)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Accent scheme")
                }
                RowList(label: L10n.t("Text size")) {
                    FlowLayout(spacing: HSpace.x2) {
                        ForEach(HOneyTextSize.allCases, id: \.self) { size in
                            ChipTab(label: L10n.t(size.label), selected: store.textSize == size) { store.choose(textSize: size) }
                        }
                    }
                    .padding(.vertical, HSpace.x3)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(L10n.t("Text size"))
                }
                RowList(label: L10n.t("Language")) {
                    FlowLayout(spacing: HSpace.x2) {
                        ChipTab(label: "English", selected: !L10n.isChinese) { store.choose(language: .en) }
                        ChipTab(label: "中文", selected: L10n.isChinese) { store.choose(language: .zh) }
                    }
                    .padding(.vertical, HSpace.x3)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Language")
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
        }
        .webScreen(title: L10n.t("Appearance"))
    }

    /// `.theme-dialog__section`: 20 pt of padding, a rule above all but the first, an h3.
    private func themeSection<Content: View>(title: String, first: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !first { HairlineDivider() }
            Text(title)
                .font(ramp.font(TypeRole(size: 15, weight: 700, textStyle: .subheadline, tracking: 0, lineHeight: 1.4)))
                .foregroundStyle(theme.ink)
                .padding(.top, first ? 0 : HSpace.x5)
                .padding(.bottom, HSpace.x3)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(.bottom, HSpace.x5)
    }
}

/// `ReconnectDialog`: one sheet, two named purposes — reconnect after a
/// portal time-out, or save the school login when Stay connected is turned
/// back on. Title, body and submit say what this opening does.
struct SchoolLoginSheet: View {
    enum Purpose { case reconnect, save }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    let purpose: Purpose
    var onDone: () -> Void = {}
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    private var keep: Bool { purpose == .save ? true : env.prefs.stayConnectedWanted }

    var body: some View {
        WebSheet(title: purpose == .save ? "Save school login" : "Reconnect school account", onClose: { dismiss() }) {
            Text(purpose == .save
                 ? "Enter your school login once; it stays in this iPhone's Keychain so routine portal time-outs reconnect on their own."
                 : keep
                    ? "The portal session ended. Sign in again to restore it — your HOney data stays as it is, and the login is kept in this iPhone's Keychain (turn that off in Settings › School connection)."
                    : "The portal session ended. Sign in again to restore it — your HOney data stays as it is. Nothing is kept on this iPhone.")
                .hfont(.body)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, HSpace.x3)
            if let error { InlineStatusBanner(text: error, tone: .danger).padding(.bottom, HSpace.x3) }
            SchoolLoginFields(username: $username, password: $password, onSubmit: submit)
            Button(busy ? "Signing in…" : (purpose == .save ? "Save login" : L10n.t("Reconnect"))) { submit() }
                .buttonStyle(.webBlockPrimary)
                .disabled(busy || username.isEmpty || password.isEmpty)
        }
        .presentationDetents([.large])
    }

    private func submit() {
        guard !busy, !username.isEmpty, !password.isEmpty else { return }
        busy = true
        error = nil
        Task {
            do {
                try await env.reconnectSchool(username: username, password: password, keep: keep)
                onDone()
                dismiss()
            } catch {
                self.error = error is SecretStoreError
                    ? "Signed in, but this iPhone could not store the school login in the Keychain."
                    : APIErrorCopy.describe(error)
                busy = false
            }
        }
    }
}

/// `SchoolLoginForm` fields: "School username" and "Password" as labelled
/// Web inputs, 12 pt apart.
struct SchoolLoginFields: View {
    @Environment(\.theme) private var theme
    @Binding var username: String
    @Binding var password: String
    var reading = false
    let onSubmit: () -> Void
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                FieldLabel(text: "School username")
                TextField("", text: $username)
                    .textFieldStyle(.web)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.next)
                    .focused($focus, equals: .username)
                    .onSubmit { focus = .password }
            }
            .padding(.bottom, HSpace.x1)
            VStack(alignment: .leading, spacing: HSpace.x2) {
                FieldLabel(text: "Password")
                SecureField("", text: $password)
                    .textFieldStyle(.web)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit(onSubmit)
            }
            .padding(.bottom, HSpace.x1)
        }
    }
}
