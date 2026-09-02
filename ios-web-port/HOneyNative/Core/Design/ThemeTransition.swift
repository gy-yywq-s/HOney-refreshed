// The Web's theme crossfade (lib/theme.ts `withCrossfade`, foundations.css
// `.theme-anim`): ~400 ms on colours, skipped under Reduce Motion.

import SwiftUI
import UIKit

enum ThemeTransition {
    static let duration: Double = 0.4

    @MainActor
    static func crossfade(_ mutate: () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            mutate()
        } else {
            withAnimation(.easeInOut(duration: duration), mutate)
        }
    }
}
