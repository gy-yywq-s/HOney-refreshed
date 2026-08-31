//
//  RootView.swift
//  HOney — gates on auth: LoginView vs MainTabView.
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                LoadingView(label: "Getting things ready…")
                    .screenBackground()
            case .signedOut:
                LoginView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.standard), value: model.phase)
        .task {
            if model.phase == .loading {
                await model.bootstrap()
            }
        }
    }
}
