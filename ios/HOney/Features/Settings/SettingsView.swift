//
//  SettingsView.swift
//  HOney — Account, School connection, Imported data, Experiences & privacy.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var consentTimetable = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                schoolSection
                importedDataSection
                privacySection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .onAppear { consentTimetable = model.profile?.consent.timetable ?? false }
            // Account deletion must surface the ownership-key consequence
            // (audit §3.6): the keys on this device are the ONLY control over
            // past anonymous posts. Deleting the account never has to destroy
            // them — that is a separate, explicit choice.
            .confirmationDialog("Delete your HOney account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account, keep post keys on this device") {
                    Task { await model.deleteAccount(eraseLocalData: false); dismiss() }
                }
                Button("Delete account and erase everything", role: .destructive) {
                    Task { await model.deleteAccount(eraseLocalData: true); dismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your account and imported data are removed from the server. Posts you published are anonymous — the ownership keys stored only on this device are the only control over them that exists. Keep the keys to stay able to revoke those posts later, or erase everything on this device too (post keys, private notes and drafts).")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let profile = model.profile {
                LabeledContent("Name", value: profile.displayName)
                LabeledContent("HOney ID", value: profile.honeyId)
                if profile.isAdmin {
                    LabeledContent("Role", value: "Admin")
                }
            }
            Button("Sign out") { Task { await model.signOut(); dismiss() } }
            Button("Delete account", role: .destructive) { confirmDelete = true }
        }
    }

    private var schoolSection: some View {
        Section {
            let connection = model.profile?.connection
            LabeledContent("Status", value: schoolStatus(connection))
            if let synced = connection?.lastSyncedAt {
                LabeledContent("Last synced", value: synced.formatted(date: .abbreviated, time: .shortened))
            }
            Text("HOney signs in with your OASIS school account. Access and the School Portal use this connection directly; it is kept separate from your HOney data.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            if connection?.connected == true {
                Button("Disconnect school account", role: .destructive) {
                    Task { await model.disconnectSchool() }
                }
            }
        } header: {
            Text("School connection")
        }
        .task { await model.refreshProfile() }
    }

    private func schoolStatus(_ c: HOneyConnection?) -> String {
        guard let c, c.connected else { return "Not connected" }
        return c.portalTokenValid ? "Connected" : "Reconnect needed"
    }

    private var importedDataSection: some View {
        Section {
            Toggle("Import my timetable", isOn: $consentTimetable)
                .onChange(of: consentTimetable) { _, newValue in
                    Task { await model.updateConsent(timetable: newValue) }
                }
            Text("When on, HOney syncs your lessons so Timetable, History and the Next Lesson card work.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        } header: {
            Text("Imported data")
        }
    }

    private var privacySection: some View {
        Section {
            Text("Experiences are anonymous. HOney stores no author identity on the server — not even for you.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("The keys that let you see, re-confirm or revoke your own posts are stored only on this device. If you lose this device, those posts stay published but can no longer be managed.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.warning)
        } header: {
            Text("Experiences & privacy")
        }
    }
}
