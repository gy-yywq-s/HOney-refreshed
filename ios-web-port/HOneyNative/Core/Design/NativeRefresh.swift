// Pull to refresh shared by every HOney scroll surface. SwiftUI-Refresher's
// system2 style leaves the native rubber band in charge, observes the real
// UIScrollView tracking phase, and keeps one stable header shim while work is
// running. It does not mutate contentInset/contentOffset or rebuild the page.

import SwiftUI
import Refresher

extension ScrollView {
    func honeyRefreshable(action: @escaping @MainActor () async -> Void) -> some View {
        refresher(
            style: .system2,
            config: Config(
                refreshAt: 92,
                headerShimMaxHeight: 56,
                systemSpinnerOpacityClipPoint: 0.18,
                holdTime: .milliseconds(350),
                cooldown: .milliseconds(500),
                resetPoint: 5
            ),
            action: action
        )
        .scrollBounceBehavior(.always, axes: .vertical)
    }
}
