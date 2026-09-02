// Settings (spec §20): native grouped lists, summary → detail. Account,
// School connection (with the imported data it produces), Experiences &
// privacy, Appearance (language, light/dark — no surface selector, no
// text-size steps), About, Admin when applicable.

import SwiftUI
import HOneyCore

struct SettingsRootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var nav
    @State private var stayConnected = true
    @State private var showSaveLogin = false

    private var connectionLine: String {
        guard let c = env.me?.connection else { return "" }
        if !c.connected { return L10n.t("Not connected") }
        if !c.portalTokenValid { return "\(L10n.t("Connected")) · \(L10n.t("portal session expired"))" }
        if let last = c.lastSyncedAt { return "\(L10n.t("Connected")) · \(L10n.t("synced")) \(Formatters.timeAgo(last))" }
        return "\(L10n.t("Connected")) · \(L10n.t("never synced"))"
    }

    var body: some View {
        List {
            if let notice = env.loginNotice {
                InlineStatusBanner(text: notice, tone: .warning, action: ("OK", { env.loginNotice = nil }))
                    .listRowBackground(Color.clear)
            }
            Section(L10n.t("Account")) {
                NavigationLink(value: AppRoute.settingsAccount) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(env.me?.displayName ?? "").font(HType.body)
                        Text("HOney ID \(env.me?.honeyId ?? "")").font(HType.meta).foregroundStyle(Color.honeySecondary)
                    }
                }
            }
            Section(L10n.t("School connection")) {
                NavigationLink(value: AppRoute.settingsConnection) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connectionLine).font(HType.body)
                        Text(L10n.t("Sync, saved login, imported data")).font(HType.meta).foregroundStyle(Color.honeySecondary)
                    }
                }
                StayConnectedToggle(stayConnected: $stayConnected, showSaveLogin: $showSaveLogin)
            }
            Section(L10n.t("Experiences & privacy")) {
                NavigationLink(value: AppRoute.mine) { Text(L10n.t("Your notes & post controls")) }
                NavigationLink(value: AppRoute.settingsPrivacy) { Text(L10n.t("How anonymity works")) }
            }
            Section(L10n.t("Appearance")) {
                NavigationLink(value: AppRoute.settingsAppearance) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(L10n.t("Language")) · \(L10n.t("Appearance"))").font(HType.body)
                        Text("\(languageLabel) · \(appearanceLabel)").font(HType.meta).foregroundStyle(Color.honeySecondary)
                    }
                }
            }
            Section(L10n.t("About")) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(L10n.t("Build")) \(env.config.buildLabel)").font(HType.body)
                    Text(env.config.honeyBaseURL.host ?? "").font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
                NavigationLink(value: AppRoute.why) { Text(L10n.t("Why this space exists")) }
            }
            if env.me?.isAdmin == true {
                Section(L10n.t("Admin")) {
                    Link(destination: env.config.dashURL) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("Open Dash")).font(HType.body).foregroundStyle(Color.honeyInk)
                            Text("\(L10n.t("The operational console for admins.")) Opens the Web Dash in Safari.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle("Settings")
        .task { stayConnected = env.prefs.stayConnectedWanted }
        .refreshable { await env.refreshMe() }
        .sheet(isPresented: $showSaveLogin) {
            SchoolLoginSheet(purpose: .save) { stayConnected = env.prefs.stayConnectedWanted }
        }
    }

    private var languageLabel: String {
        switch env.language {
        case .system: return L10n.t("System")
        case .en: return "English"
        case .zh: return "中文"
        }
    }

    private var appearanceLabel: String {
        switch env.appearance {
        case .system: return L10n.t("System")
        case .light: return L10n.t("Light")
        case .dark: return L10n.t("Dark")
        }
    }
}

/// "Stay connected on this iPhone": off deletes the Keychain school login;
/// on asks for it when none is stored yet.
struct StayConnectedToggle: View {
    @Environment(AppEnvironment.self) private var env
    @Binding var stayConnected: Bool
    @Binding var showSaveLogin: Bool

    var body: some View {
        Toggle(isOn: Binding(
            get: { stayConnected },
            set: { next in
                stayConnected = next
                Task {
                    await env.setStayConnected(next)
                    if next, !env.hasSavedSchoolLogin { showSaveLogin = true }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("Stay connected on this iPhone")).font(HType.body)
                Text(L10n.t("Reconnects automatically after routine portal time-outs.")).font(HType.meta).foregroundStyle(Color.honeySecondary)
            }
        }
    }
}

struct AccountView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmDelete = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(env.me?.displayName ?? "").font(HType.body)
                    Text("HOney ID \(env.me?.honeyId ?? "") — your name inside HOney; never shown on published experiences.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
                Button(L10n.t("Sign out"), role: .destructive) { Task { await env.signOut() } }
            }
            Section {
                if let error { InlineStatusBanner(text: error, tone: .danger).listRowBackground(Color.clear) }
                Text("Deletes your HOney account, your imported lessons and the school login saved on this iPhone. Shared teacher, course, room and lesson entries stay. Published Experiences stay — they carry no author ID and are controlled only by the keys on your devices. Private notes and control keys on this iPhone are kept unless you choose to erase them.")
                    .font(HType.meta).foregroundStyle(Color.honeySecondary)
                Button(L10n.t("Delete account…"), role: .destructive) { confirmDelete = true }.disabled(busy)
            } header: { Text("Delete account") }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("Account"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete your HOney account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account, keep notes and keys on this iPhone", role: .destructive) { delete(erase: false) }
            Button("Delete account and erase local notes and keys", role: .destructive) { delete(erase: true) }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            Text("This permanently removes your account and imported lessons. Published experiences stay (they carry no author ID). The school login saved on this iPhone is cleared. This cannot be undone.")
        }
    }

    private func delete(erase: Bool) {
        busy = true
        Task {
            do { _ = try await env.deleteAccount(eraseLocalData: erase) } catch { self.error = APIErrorCopy.describe(error) }
            busy = false
        }
    }
}

struct SchoolConnectionView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var stayConnected = true
    @State private var showSaveLogin = false
    @State private var showReconnect = false
    @State private var busy: String?
    @State private var feedback: (tone: BannerTone, text: String)?
    @State private var confirmDisconnect = false
    @State private var confirmDeleteData = false

    private var connection: Me.Connection? { env.me?.connection }

    var body: some View {
        List {
            if let feedback { InlineStatusBanner(text: feedback.text, tone: feedback.tone).listRowBackground(Color.clear) }
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusLine).font(HType.body)
                    if let c = connection, c.connected, !c.portalTokenValid {
                        Text("Reconnect to sync again.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                    }
                }
                if connection?.connected == true {
                    Button(busy == "sync" ? L10n.t("Syncing with school…") : L10n.t("Sync now")) { sync() }.disabled(busy != nil)
                    if connection?.portalTokenValid == false {
                        Button(L10n.t("Reconnect")) { showReconnect = true }
                    }
                    Button(L10n.t("Disconnect"), role: .destructive) { confirmDisconnect = true }.disabled(busy != nil)
                }
            } header: { Text("Status") }
            Section {
                StayConnectedToggle(stayConnected: $stayConnected, showSaveLogin: $showSaveLogin)
                Text("Your school login is kept in this iPhone's Keychain so routine Portal time-outs can reconnect automatically. It stays on this device only. Turn it off any time; you will re-enter your school password when the portal session ends.")
                    .font(HType.meta).foregroundStyle(Color.honeySecondary)
            } header: { Text("Saved login") }
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Timetable & lesson history")).font(HType.body)
                    Text("Imported from the school portal when your account is created, and again whenever you sync.").font(HType.meta).foregroundStyle(Color.honeySecondary)
                }
                Text("Used for your timetable and Now/Next on Home, your lesson history, and which classes count as yours when you share an Experience. Nothing is published from it.")
                    .font(HType.meta).foregroundStyle(Color.honeySecondary)
            } header: { Text(L10n.t("Imported data")) }
            Section {
                Text("Removes your imported lessons — your timetable and history. Shared teacher, course, room and lesson entries stay. You can import again with Sync now.")
                    .font(HType.meta).foregroundStyle(Color.honeySecondary)
                Button(L10n.t("Delete imported data…"), role: .destructive) { confirmDeleteData = true }.disabled(busy != nil)
            } header: { Text("Delete imported data") }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("School connection"))
        .navigationBarTitleDisplayMode(.inline)
        .task { stayConnected = env.prefs.stayConnectedWanted }
        .refreshable { await env.refreshMe() }
        .sheet(isPresented: $showSaveLogin) { SchoolLoginSheet(purpose: .save) { stayConnected = env.prefs.stayConnectedWanted } }
        .sheet(isPresented: $showReconnect) { SchoolLoginSheet(purpose: .reconnect) { sync() } }
        .confirmationDialog("Disconnect school account?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button(L10n.t("Disconnect"), role: .destructive) { run("disconnect", "School account disconnected.") { try await env.api.disconnectSchool(); try await env.portalCoordinator.forgetEverything() } }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: { Text("HOney will stop syncing until you reconnect. Imported data is kept.") }
        .confirmationDialog("Delete imported data?", isPresented: $confirmDeleteData, titleVisibility: .visible) {
            Button("Delete imported data", role: .destructive) { run("delete-data", "Imported data deleted.") { try await env.api.deleteImportedData(); await env.timetable.invalidateAll() } }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: { Text("Your imported lessons — timetable and history — are removed from HOney. Shared teacher, course, room and lesson entries stay. You can import again with Sync now.") }
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

struct AppearanceView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        Form {
            Section(L10n.t("Language")) {
                Picker(L10n.t("Language"), selection: $env.language) {
                    Text(L10n.t("System")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("中文").tag(AppLanguage.zh)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section(L10n.t("Appearance")) {
                Picker(L10n.t("Appearance"), selection: $env.appearance) {
                    Text(L10n.t("System")).tag(AppearanceChoice.system)
                    Text(L10n.t("Light")).tag(AppearanceChoice.light)
                    Text(L10n.t("Dark")).tag(AppearanceChoice.dark)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("Appearance"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One sheet, two purposes: reconnect after a portal time-out, or save the
/// school login when Stay connected is turned back on.
struct SchoolLoginSheet: View {
    enum Purpose { case reconnect, save }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let purpose: Purpose
    var onDone: () -> Void = {}
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    private var keep: Bool { purpose == .save ? true : env.prefs.stayConnectedWanted }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(purpose == .save
                         ? "Enter your school login once; it stays in this iPhone's Keychain so routine portal time-outs reconnect on their own."
                         : keep
                            ? "The portal session ended. Sign in again to restore it — your HOney data stays as it is, and the login is kept in this iPhone's Keychain (turn that off in Settings › School connection)."
                            : "The portal session ended. Sign in again to restore it — your HOney data stays as it is. Nothing is kept on this iPhone.")
                        .font(HType.secondary).foregroundStyle(Color.honeySecondary)
                }
                if let error { InlineStatusBanner(text: error, tone: .danger).listRowBackground(Color.clear) }
                Section {
                    TextField("School account", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("School password", text: $password).textContentType(.password)
                }
                Section {
                    Button(busy ? "Signing in…" : (purpose == .save ? "Save login" : L10n.t("Reconnect"))) { submit() }
                        .disabled(busy || username.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle(purpose == .save ? "Save school login" : "Reconnect school account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Cancel")) { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func submit() {
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
