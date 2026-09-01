//
//  ImportConsentView.swift
//  HOney — explicit, separate permission for school-data import.
//

import SwiftUI

struct ImportConsentView: View {
    @Environment(AppModel.self) private var model
    @State private var busyChoice: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                BrandWordmarkPlaceholder()
                    .frame(width: 190, height: 64, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Bring in your school day?")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)

                    Text("This is separate from signing in. Nothing is imported until you choose it here.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 0) {
                    consentRow(icon: "calendar", title: "Timetable", detail: "See today and the next lesson on Home.")
                    Divider().padding(.leading, 42)
                    consentRow(icon: "clock.arrow.circlepath", title: "Past lessons", detail: "Choose a lesson when you want to share an experience.")
                    Divider().padding(.leading, 42)
                    consentRow(icon: "arrow.triangle.2.circlepath", title: "Your choice", detail: "Turn import off later in Settings.")
                }

                if let error = model.consentError {
                    AppBanner(text: error, style: .error)
                }

                VStack(spacing: 12) {
                    Button {
                        choose(true)
                    } label: {
                        Text(busyChoice == true ? "Importing…" : "Import timetable and lesson history")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(busyChoice != nil)

                    Button {
                        choose(false)
                    } label: {
                        Text(busyChoice == false ? "One moment…" : "Not now")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(busyChoice != nil)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.loginHorizontal)
            .padding(.top, 38)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(PageBackground())
    }

    private func consentRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
                .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.Typography.headlineSemibold)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(AppTheme.Typography.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
    }

    private func choose(_ importIt: Bool) {
        busyChoice = importIt
        Task {
            await model.completeImportConsent(importTimetable: importIt)
            busyChoice = nil
        }
    }
}
