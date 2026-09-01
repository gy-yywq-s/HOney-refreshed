//
//  ImportConsentView.swift
//  HOney — step 2 of first sign-in: a SEPARATE, active import-consent choice
//  (audit §3.2). Signing in and copying school data are different decisions,
//  and nothing is preselected. Mirrors the web LoginPage consent step.
//  Styled as a legacy card with primary/secondary buttons.
//

import SwiftUI

struct ImportConsentView: View {
    @Environment(AppModel.self) private var model

    /// Which choice is in flight, for the button labels.
    @State private var busyChoice: Bool?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 70)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxLarge) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    HOneyLoginMark()
                        .frame(width: 48, height: 48)

                    Text("One more choice.")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(Palette.navy)
                }

                AppCard {
                    Text("HOney can copy your timetable and lesson history from the school portal so your day and your History work here. Nothing is imported unless you turn it on, and you can switch it off any time in Settings.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Palette.navy.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = model.consentError {
                    AppBanner(text: error, style: .error)
                }

                VStack(spacing: AppTheme.Spacing.medium) {
                    Button {
                        choose(true)
                    } label: {
                        Text(busyChoice == true ? "Importing…" : "Import my timetable")
                            .font(AppTheme.Typography.subheadlineSemibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                busyChoice == nil ? Palette.ocean : Palette.navy.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(busyChoice != nil)

                    Button {
                        choose(false)
                    } label: {
                        Text(busyChoice == false ? "One moment…" : "Not now")
                            .font(AppTheme.Typography.subheadlineSemibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.mist.opacity(0.88), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                    .stroke(Palette.line, lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.navy)
                    .disabled(busyChoice != nil)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.loginHorizontal)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.white, Palette.mist.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func choose(_ importIt: Bool) {
        busyChoice = importIt
        Task {
            await model.completeImportConsent(importTimetable: importIt)
            busyChoice = nil
        }
    }
}
