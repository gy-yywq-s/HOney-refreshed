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
            .alert("Delete your HOney account?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { Task { await model.deleteAccount(); dismiss() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your account and imported data. Experiences you posted remain anonymous and are managed with device-only keys.")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let profile = model.profile {
                LabeledContent("Name", value: profile.displayName)
                LabeledContent("Honey ID", value: profile.honeyId)
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
            LabeledContent("Status", value: "Connected")
            Text("HOney signs in with your OASIS school account. Access and the School Portal use this connection directly; it is kept separate from your HOney data.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        } header: {
            Text("School connection")
        }
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
