//
//  SettingsView.swift
//  HOney — native, behaviorally precise account and privacy settings.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var consentTimetable = false
    @State private var revertingConsent = false
    @State private var isSavingConsent = false
    @State private var confirmDelete = false
    @State private var showSchoolReconnect = false
    @State private var settingsError: String?
    @AppStorage(SurfacePalette.storageKey) private var persistedSurfacePalette = SurfacePalette.paper.rawValue
    @State private var pendingSurfacePalette = SurfacePalette.current

    var body: some View {
        NavigationStack {
            List {
                if let settingsError {
                    Section {
                        AppBanner(text: settingsError, style: .error)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                appearanceSection
                accountSection
                schoolSection
                privacySection
                aboutSection
            }
            .textCase(nil)
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                consentTimetable = model.profile?.consent.timetable ?? false
                if SurfacePalette(rawValue: persistedSurfacePalette) == nil {
                    persistedSurfacePalette = SurfacePalette.paper.rawValue
                }
                pendingSurfacePalette = SurfacePalette(rawValue: persistedSurfacePalette) ?? .paper
            }
            .task {
                if await model.refreshProfile() {
                    consentTimetable = model.profile?.consent.timetable ?? false
                }
            }
            .confirmationDialog(
                "Delete your HOney account?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete account, keep data on this iPhone") {
                    deleteAccount(eraseLocalData: false)
                }
                Button("Delete account and erase data on this iPhone", role: .destructive) {
                    deleteAccount(eraseLocalData: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting removes your HOney account and imported server data. Anonymous posts remain published. Keeping device data preserves the saved school sign-in, private notes, saved draft and post-control keys. Erasing device data removes all of those from this iPhone.")
            }
            .sheet(isPresented: $showSchoolReconnect) {
                SchoolReconnectView().environment(model)
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            ForEach(SurfacePalette.allCases) { palette in
                Button {
                    pendingSurfacePalette = palette
                    persistedSurfacePalette = palette.rawValue
                } label: {
                    paletteOption(palette)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Every available surface is shown here, including the earlier color directions. Each has a small set of detail colors tuned for light and dark mode.")
        }
        .listRowBackground(Palette.surface)
    }

    private func paletteOption(_ palette: SurfacePalette) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                paletteSwatch(palette.spec.canvas)
                paletteSwatch(palette.spec.accent)
                paletteSwatch(palette.spec.accentSecondary)
                paletteSwatch(palette.spec.accentTertiary)
                paletteSwatch(palette.spec.accentQuaternary)
            }

            Text(palette.title)
                .font(AppTheme.Typography.subheadlineSemibold)
                .foregroundStyle(Palette.ink)

            Spacer()

            Image(systemName: pendingSurfacePalette == palette ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(pendingSurfacePalette == palette ? Palette.accent : Palette.inkSecondary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(palette.title)
        .accessibilityValue(pendingSurfacePalette == palette ? "Selected" : "Not selected")
    }

    private func paletteSwatch(_ value: AdaptiveRGB) -> some View {
        Circle()
            .fill(previewColor(value))
            .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }

    private func previewColor(_ value: AdaptiveRGB) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? value.dark : value.light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    private var accountSection: some View {
        Section {
            if let profile = model.profile {
                settingValue(title: "Name", value: profile.displayName)
                settingValue(title: "Account ID", value: profile.honeyId)
                if profile.isAdmin {
                    settingValue(title: "Role", value: "Admin")
                }
            }

            Button("Sign out of HOney") {
                Task {
                    await model.signOut()
                    dismiss()
                }
            }
            .foregroundStyle(Palette.ink)

            Button("Delete HOney account", role: .destructive) {
                confirmDelete = true
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Signing out keeps the saved school sign-in, private notes, saved draft and post-control keys on this iPhone.")
        }
        .listRowBackground(Palette.surface)
    }

    private var schoolSection: some View {
        Section {
            let connection = model.profile?.connection
            settingValue(title: "Connection", value: schoolStatus(connection))
            if let synced = connection?.lastSyncedAt {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(synced, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(Palette.inkSecondary)
                }
            }

            Toggle("Import timetable and lesson history", isOn: $consentTimetable)
                .tint(Palette.accent)
                .disabled(isSavingConsent)
                .onChange(of: consentTimetable) { oldValue, newValue in
                    if revertingConsent {
                        revertingConsent = false
                        return
                    }
                    saveConsent(previousValue: oldValue, newValue: newValue)
                }

            Button("Update school sign-in") {
                showSchoolReconnect = true
            }

            if connection?.connected == true {
                Button("Disconnect timetable sync", role: .destructive) {
                    Task {
                        if await model.disconnectSchool() {
                            settingsError = nil
                        } else {
                            settingsError = "Timetable sync was not disconnected. Try again."
                        }
                    }
                }
            }
        } header: {
            Text("School data")
        } footer: {
            Text("Disconnecting stops HOney’s school-data sync. It does not erase the school sign-in saved on this iPhone for Access.")
        }
        .listRowBackground(Palette.surface)
    }

    private var privacySection: some View {
        Section {
            Label("Published experiences store no author identity.", systemImage: "person.crop.circle.badge.questionmark")
            Label("Private notes and the saved draft stay on this iPhone.", systemImage: "iphone")
            Label("Post-control keys let this iPhone see and revoke your anonymous posts.", systemImage: "key")
        } header: {
            Text("Experiences and privacy")
        } footer: {
            Text("If these device-only keys are lost, the posts stay anonymous and published, but you can no longer revoke them.")
        }
        .listRowBackground(Palette.surface)
    }

    private var aboutSection: some View {
        Section {
            settingValue(title: "App", value: "HOney")
            settingValue(
                title: "Version",
                value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            )
        } header: {
            Text("About")
        }
        .listRowBackground(Palette.surface)
    }

    private func settingValue(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func schoolStatus(_ connection: HOneyConnection?) -> String {
        guard let connection, connection.connected else { return "Not connected" }
        return connection.portalTokenValid ? "Connected" : "Reconnect needed"
    }

    private func saveConsent(previousValue: Bool, newValue: Bool) {
        isSavingConsent = true
        settingsError = nil
        Task {
            let saved = await model.updateConsent(timetable: newValue)
            isSavingConsent = false
            if !saved {
                revertingConsent = true
                consentTimetable = previousValue
                settingsError = "The import setting was not updated. Check your connection and try again."
            }
        }
    }

    private func deleteAccount(eraseLocalData: Bool) {
        Task {
            switch await model.deleteAccount(eraseLocalData: eraseLocalData) {
            case .complete, .localCleanupIncomplete:
                dismiss()
            case .serverFailed:
                settingsError = "The HOney account was not deleted. No local data was erased."
            }
        }
    }
}

struct SchoolReconnectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var feedback: (AppBanner.Style, String)?
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    var body: some View {
        NavigationStack {
            Form {
                if let feedback {
                    Section { AppBanner(text: feedback.1, style: feedback.0) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("School account", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                    SecureField("School password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                } footer: {
                    Text("This replaces the school account and password saved on this iPhone for Access and School Portal. It does not change your HOney account or timetable-import choice.")
                }

                Section {
                    Button(isWorking ? "Checking…" : "Save and check connection") {
                        Task { await reconnect() }
                    }
                    .disabled(isWorking || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                }
            }
            .textCase(nil)
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle("School sign-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func reconnect() async {
        guard !isWorking else { return }
        isWorking = true
        feedback = nil
        focusedField = nil
        defer { isWorking = false }

        do {
            try await model.services.portalCoordinator.authorizeCredentials(PortalCredentials(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            ))
            await model.services.portalCoordinator.restore()
            switch await model.services.portalCoordinator.currentState() {
            case .authenticated:
                model.portalCredentialNotice = nil
                dismiss()
            case .temporarilyUnavailable:
                feedback = (.warning, "The school sign-in was saved, but the portal is temporarily unavailable, so HOney could not verify it yet.")
            case .userActionRequired:
                feedback = (.error, "The school did not accept this sign-in, or it requires a manual challenge.")
            case .incompatible:
                feedback = (.error, "The school portal changed and this version of HOney cannot reconnect yet.")
            case .noCredentials:
                feedback = (.error, "This iPhone could not save the school sign-in.")
            case .restoring:
                feedback = (.warning, "The school connection is still being checked. Try again in a moment.")
            }
        } catch {
            feedback = (.error, "This iPhone could not save the school sign-in.")
        }
    }
}
