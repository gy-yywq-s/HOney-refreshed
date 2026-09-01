//
//  SettingsView.swift
//  HOney — Account, School connection, Imported data, Experiences & privacy,
//  About — as identical stacked preference cards (legacy Prefs grammar).
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var consentTimetable = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        accountCard
                        schoolCard
                        importedDataCard
                        privacyCard
                        aboutCard
                    }
                    .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .onAppear { consentTimetable = model.profile?.consent.timetable ?? false }
            .task { await model.refreshProfile() }
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

    // MARK: - Cards

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            preferenceHeader("Account", detail: "who this device is signed in as.")

            if let profile = model.profile {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Name: \(profile.displayName)")
                    Text("HOney ID: \(profile.honeyId)")
                    if profile.isAdmin {
                        Text("Role: Admin")
                    }
                }
                .font(AppTheme.Typography.captionMedium)
                .foregroundStyle(Palette.navy.opacity(0.54))
            }

            Button {
                Task { await model.signOut(); dismiss() }
            } label: {
                Text("Sign out")
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                confirmDelete = true
            } label: {
                Text("Delete account")
                    .font(AppTheme.Typography.subheadlineSemibold)
                    .foregroundStyle(Palette.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .preferenceCard()
    }

    private var schoolCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            preferenceHeader("School Connection", detail: "HOney signs in with your OASIS school account. Access and the School Portal use this connection directly; it is kept separate from your HOney data.")

            let connection = model.profile?.connection
            VStack(alignment: .leading, spacing: 5) {
                Text("Status: \(schoolStatus(connection))")
                if let synced = connection?.lastSyncedAt {
                    Text("Last synced: \(synced.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            .font(AppTheme.Typography.captionMedium)
            .foregroundStyle(Palette.navy.opacity(0.54))

            if connection?.connected == true {
                Button {
                    Task { await model.disconnectSchool() }
                } label: {
                    Text("Disconnect school account")
                        .font(AppTheme.Typography.subheadlineSemibold)
                        .foregroundStyle(Palette.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .preferenceCard()
    }

    private func schoolStatus(_ c: HOneyConnection?) -> String {
        guard let c, c.connected else { return "Not connected" }
        return c.portalTokenValid ? "Connected" : "Reconnect needed"
    }

    private var importedDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            preferenceHeader("Imported Data", detail: "When on, HOney syncs your lessons so Timetable, History and the Next Lesson card work.")

            Toggle("Import my timetable", isOn: $consentTimetable)
                .font(AppTheme.Typography.subheadlineSemibold)
                .foregroundStyle(Palette.navy)
                .tint(Palette.ocean)
                .onChange(of: consentTimetable) { _, newValue in
                    Task { await model.updateConsent(timetable: newValue) }
                }
        }
        .preferenceCard()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            preferenceHeader("Experiences & Privacy", detail: "how anonymous posting actually works.")

            Text("Experiences are anonymous. HOney stores no author identity on the server — not even for you.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Palette.navy.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Text("The keys that let you see, re-confirm or revoke your own posts are stored only on this device. If you lose this device, those posts stay published but can no longer be managed.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .preferenceCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            preferenceHeader("About", detail: "HOney — a quiet app for school days.")

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(AppTheme.Typography.captionMedium)
                .foregroundStyle(Palette.navy.opacity(0.54))
        }
        .preferenceCard()
    }

    private func preferenceHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Typography.preferenceCardTitle)
                .foregroundStyle(Palette.navy)

            Text(detail)
                .font(AppTheme.Typography.captionMedium)
                .foregroundStyle(Palette.navy.opacity(0.58))
        }
    }
}
