//
//  RootView.swift
//  HOney — gates on auth: LoginView vs MainTabView.
//

import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                LoadingView(label: "Getting things ready…")
                    .screenBackground()
            case .signedOut:
                LoginView()
            case .consentPending:
                ImportConsentView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: Theme.Motion.standard), value: model.phase)
        .task {
            if model.phase == .loading {
                await model.bootstrap()
            }
        }
    }
}
