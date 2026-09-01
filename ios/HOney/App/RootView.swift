//
//  RootView.swift
//  HOney — gates on auth without imposing one decorative treatment on every
//  screen. Each signed-in surface owns its background composition.
//

import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @AppStorage(SurfacePalette.storageKey) private var surfacePaletteRaw = SurfacePalette.paper.rawValue

    var body: some View {
        ZStack {
            PageBackground()

            switch model.phase {
            case .loading:
                AppLoadingState(title: "Getting things ready…")
            case .startupUnavailable:
                VStack(alignment: .leading, spacing: 14) {
                    Text("HOney is temporarily unavailable")
                        .font(AppTheme.Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.startupNotice ?? "Your saved sign-in could not be checked.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                    Button("Try again") {
                        Task { await model.bootstrap() }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(AppTheme.Spacing.pageHorizontal)
                .frame(maxWidth: 460)
            case .signedOut:
                LoginView()
            case .consentPending:
                ImportConsentView()
            case .signedIn:
                MainTabView()
            }
        }
        .id(surfacePaletteRaw)
        .animation(reduceMotion ? nil : AppTheme.Motion.standard, value: model.phase)
        .task {
            if model.phase == .loading {
                await model.bootstrap()
            }
        }
        .onChange(of: model.phase) { _, phase in
            if case .signedOut = phase {
                PortalWebController.shared.resetForAccountChange()
            }
        }
    }
}
