// Pull to refresh in the Web's grammar (components.css `.ptr__pill`,
// lib/refresh.ts): the scroll view's own rubber band IS the pull — nothing
// moves by hand and nothing jumps — and one pill floats in the frame
// reporting what is happening: "Pull to refresh" → "Release to refresh"
// (haptic) → "Refreshing…" (spinning) → "Updated". An explicit refresh
// button shows the same pill through `RefreshTrigger` (Gary 2026-09-02:
// 刷新要有反馈，不要一跳一跳).

import SwiftUI
import HOneyCore

/// Fires the pill and the action from a button (Access › refresh).
@MainActor
@Observable
final class RefreshTrigger {
    fileprivate var requests = 0
    func fire() { requests += 1 }
}

/// Put this first inside the ScrollView's content: it reports the pull.
struct RefreshAnchor: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: RefreshOffsetKey.self, value: geo.frame(in: .named(HoneyRefresh.space)).minY)
        }
        .frame(height: 0)
    }
}

private struct RefreshOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

enum HoneyRefresh {
    static let space = "honey.refresh"
    static let threshold: CGFloat = 72
}

extension View {
    /// Apply to the ScrollView whose content carries `.refreshAnchor()`.
    func honeyRefreshable(trigger: RefreshTrigger? = nil, action: @escaping () async -> Void) -> some View {
        modifier(HoneyRefreshModifier(trigger: trigger, action: action))
    }

    /// Apply to the ScrollView's content stack: reports its top edge without
    /// adding a child (and a stack spacing) to it.
    func refreshAnchor() -> some View {
        overlay(alignment: .top) { RefreshAnchor() }
    }
}

private struct HoneyRefreshModifier: ViewModifier {
    enum Phase: Equatable { case idle, pulling(CGFloat), armed, refreshing, done }

    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: RefreshTrigger?
    let action: () async -> Void
    @State private var phase: Phase = .idle
    @State private var offset: CGFloat = 0
    @State private var armedTaps = 0
    @State private var doneTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: HoneyRefresh.space)
            .onPreferenceChange(RefreshOffsetKey.self) { value in
                Task { @MainActor in handle(offset: value) }
            }
            .overlay(alignment: .top) { pill }
            .onChange(of: trigger?.requests ?? 0) { _, _ in
                if trigger != nil { Task { await run() } }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: armedTaps)
    }

    private func handle(offset y: CGFloat) {
        offset = y
        switch phase {
        case .idle:
            if y > 8 { phase = .pulling(y) }
        case .pulling:
            if y >= HoneyRefresh.threshold {
                phase = .armed
                armedTaps += 1
            } else if y <= 0 {
                phase = .idle
            } else {
                phase = .pulling(y)
            }
        case .armed:
            // The finger let go (or came back): the band shrinks past the threshold.
            if y < HoneyRefresh.threshold * 0.6 { Task { await run() } }
        case .refreshing, .done:
            break
        }
    }

    private func run() async {
        guard phase != .refreshing else { return }
        doneTask?.cancel()
        phase = .refreshing
        let started = Date()
        await action()
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 0.6 { try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000)) }
        phase = .done
        doneTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            phase = .idle
        }
    }

    private var label: String {
        switch phase {
        case .idle, .pulling: return L10n.t("Pull to refresh")
        case .armed: return L10n.t("Release to refresh")
        case .refreshing: return L10n.t("Refreshing…")
        case .done: return L10n.t("Updated")
        }
    }

    private var opacity: Double {
        switch phase {
        case .idle: return 0
        case .pulling(let y): return min(1, Double(y) / Double(HoneyRefresh.threshold))
        case .armed, .refreshing, .done: return 1
        }
    }

    private var spin: Angle {
        switch phase {
        case .pulling(let y): return .degrees(Double(y) / Double(HoneyRefresh.threshold) * 180)
        case .armed: return .degrees(180)
        default: return .zero
        }
    }

    @ViewBuilder
    private var pill: some View {
        let armed = phase == .armed
        HStack(spacing: HSpace.x2) {
            Group {
                if phase == .refreshing {
                    ProgressView().controlSize(.small).tint(theme.ink2)
                } else if phase == .done {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                } else {
                    Image(systemName: "arrow.down").font(.system(size: 13, weight: .semibold)).rotationEffect(spin)
                }
            }
            .frame(width: 16, height: 16)
            Text(label).font(ramp.font(.secondarySemibold))
        }
        .foregroundStyle(armed ? theme.surfaceSolid : theme.ink2)
        .padding(.horizontal, HSpace.x4)
        .padding(.vertical, HSpace.x2)
        .background(armed ? theme.accent : theme.surfaceSolid, in: Capsule())
        .overlay(Capsule().strokeBorder(armed ? theme.accent : theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 9, y: 6)
        .padding(.top, HSpace.x2)
        .opacity(opacity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: phase)
        .allowsHitTesting(false)
        .accessibilityHidden(phase == .idle)
        .accessibilityLabel(label)
    }
}
