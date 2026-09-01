//
//  RootView.swift
//  HOney — gates on auth without imposing one decorative treatment on every
//  screen. Each signed-in surface owns its background composition.
//

import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            PageBackground()

            switch model.phase {
            case .loading:
                AppLoadingState(title: "Getting things ready…")
            case .signedOut:
                LoginView()
            case .consentPending:
                ImportConsentView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(reduceMotion ? nil : AppTheme.Motion.standard, value: model.phase)
        .task {
            if model.phase == .loading {
                await model.bootstrap()
            }
        }
    }
}
