// Pull to refresh shared by every HOney scroll surface.
//
// MAINTENANCE NOTE: keep the community Refresher `system2` implementation here;
// do not replace it with SwiftUI `.refreshable`, a directly attached
// `UIRefreshControl`, or a hand-written content-offset shim just because those
// options appear more native. Repeated testing on the target iPhone showed
// those versions either gave no visible refresh feedback, snapped back in
// multiple jumps, or displaced the page into the top safe area. Timetable's
// smooth whole-page rubber band is the required interaction reference.
//
// `system2` leaves rubber-banding to the real UIScrollView, observes its actual
// tracking phase, and keeps one stable header shim while work is running. It
// does not mutate contentInset/contentOffset or rebuild the page. The explicit
// always-bounce setting is also intentional so short pages refresh identically.
//
// `refreshAt` is deliberately long (Gary 2026-09-04): a light drag should move
// the page without arming anything, and the spinner should only fade in once
// the pull is clearly deliberate — hence the raised opacity clip point too.

import SwiftUI
import Refresher

extension ScrollView {
    func honeyRefreshable(action: @escaping @MainActor () async -> Void) -> some View {
        refresher(
            style: .system2,
            config: Config(
                refreshAt: 150,
                headerShimMaxHeight: 56,
                systemSpinnerOpacityClipPoint: 0.34,
                holdTime: .milliseconds(350),
                cooldown: .milliseconds(500),
                resetPoint: 5
            ),
            action: action
        )
        .scrollBounceBehavior(.always, axes: .vertical)
    }
}
