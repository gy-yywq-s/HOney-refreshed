//
//  HOneyApp.swift
//  HOney — SwiftUI app entry point.
//

import SwiftUI

@main
struct HOneyApp: App {
    @State private var model = AppModel()
    @AppStorage(SurfacePalette.storageKey) private var surfacePaletteRaw = SurfacePalette.paper.rawValue

    var body: some Scene {
        WindowGroup {
            let _ = surfacePaletteRaw
            RootView()
                .environment(model)
                .tint(Palette.accent)
        }
    }
}
