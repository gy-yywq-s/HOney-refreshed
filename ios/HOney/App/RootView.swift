//
//  RootView.swift
//  HOney — gates on auth: LoginView vs MainTabView, over the fixed
//  diagonal gradient (legacy shell: the gradient is never hidden).
//

import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

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
