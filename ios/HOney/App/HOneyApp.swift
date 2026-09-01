//
//  HOneyApp.swift
//  HOney — SwiftUI app entry point.
//

import SwiftUI

@main
struct HOneyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.ocean)
                .preferredColorScheme(.light)
        }
    }
}
