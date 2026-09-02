// The five-slot tab bar in the Web's mobile grammar (components.css
// `.mobile-nav`; fidelity spec v2 §5.2, path B): a floating 54 pt bar,
// 12 pt in from the sides, 10 pt above the home indicator, 22 pt outer
// radius, 4 pt inner inset, an accent-tint pill under the selected slot,
// 21 pt line icons, 12 pt labels always visible, quiet line and shadow.
// The native TabView underneath keeps the navigation state.

import SwiftUI

struct HOneyTabBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selected: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: HSpace.x1) {
            ForEach(AppTab.allCases) { tab in
                let on = tab == selected
                Button {
                    if reduceMotion { selected = tab } else { withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.3)) { selected = tab } }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .regular))
                            .frame(width: HSize.tabIcon, height: HSize.tabIcon)
                        Text(tab.title)
                            .font(ramp.font(.microSemibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(on ? theme.accent : theme.muted)
                    .frame(maxWidth: .infinity, minHeight: HSize.control)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(theme.accentTint)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(HSpace.x1)
        .frame(minHeight: 54)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.surface.opacity(0.95)))
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
        .shadow(color: theme.shadow, radius: 20, y: 14)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Primary")
    }
}
