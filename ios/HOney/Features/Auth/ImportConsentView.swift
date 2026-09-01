//
//  ImportConsentView.swift
//  HOney — step 2 of first sign-in: a SEPARATE, active import-consent choice
//  (audit §3.2). Signing in and copying school data are different decisions,
//  and nothing is preselected. Mirrors the web LoginPage consent step.
//

import SwiftUI

struct ImportConsentView: View {
    @Environment(AppModel.self) private var model

    /// Which choice is in flight, for the button labels.
    @State private var busyChoice: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HOneyWordmark(size: 40)
                    Text("One more choice.")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("HOney can copy your timetable and lesson history from the school portal so your day and your History work here. Nothing is imported unless you turn it on, and you can switch it off any time in Settings.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(.top, Theme.Spacing.xxl)

                if let error = model.consentError {
                    Banner(kind: .error, message: error)
                }

                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        choose(true)
                    } label: {
                        Text(busyChoice == true ? "Importing…" : "Import my timetable")
                    }
                    .buttonStyle(HOneyPrimaryButtonStyle(enabled: busyChoice == nil))
                    .disabled(busyChoice != nil)

                    Button {
                        choose(false)
                    } label: {
                        Text(busyChoice == false ? "One moment…" : "Not now")
                    }
                    .buttonStyle(HOneySecondaryButtonStyle())
                    .disabled(busyChoice != nil)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
    }

    private func choose(_ importIt: Bool) {
        busyChoice = importIt
        Task {
            await model.completeImportConsent(importTimetable: importIt)
            busyChoice = nil
        }
    }
}
