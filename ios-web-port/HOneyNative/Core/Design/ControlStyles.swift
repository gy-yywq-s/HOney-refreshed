// Web-faithful choice controls, reactions, fields and the switch (fidelity
// spec v2 §4.3–4.5): shape, selected fill, weight, border and spacing from
// components.css / features.css, themed live.

import SwiftUI

// MARK: - Scope switch (`.scope-switch`, the Stream header)

struct ScopeSwitch<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let options: [(Option, String)]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: HSpace.x1) {
            ForEach(options, id: \.0) { option, label in
                let on = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label)
                        .font(ramp.font(.secondary))
                        .foregroundStyle(on ? theme.onAccent : theme.ink2)
                        .padding(.horizontal, HSpace.x4)
                        .frame(minHeight: 34)
                        .background(on ? theme.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(HSpace.x1)
        .background(theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Mode pill (`.daynav__modes`: Day | Week)

struct ModePill<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let options: [(Option, String)]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option, label in
                let on = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label)
                        .font(ramp.font(.secondarySemibold))
                        .foregroundStyle(on ? theme.surface : theme.ink2)
                        .padding(.horizontal, HSpace.x4)
                        .frame(minHeight: 32)
                        .background(on ? theme.ink : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(theme.surfaceSolid, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Chip tabs (`.chip-tab`: Explore categories, Text size, Language)

struct ChipTab: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let label: String
    var count: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HSpace.x2) {
                Text(label).font(ramp.font(.secondarySemibold))
                if let count {
                    Text(count)
                        .font(ramp.font(.microSemibold))
                        .foregroundStyle(selected ? theme.surface.opacity(0.75) : theme.muted)
                }
            }
            .foregroundStyle(selected ? theme.surface : theme.ink2)
            .padding(.horizontal, HSpace.x4)
            .frame(minHeight: HSize.smallControl)
            .background(selected ? theme.ink : theme.surfaceSolid, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? theme.ink : theme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// `.cat-chips` and inline runs of links: every item visible, wrapping like
/// inline content, never clipped (rule 4f). An item wider than the row gets
/// the row's width and wraps inside itself (a long course name).
struct FlowLayout: Layout {
    var spacing: CGFloat = HSpace.x2
    var rowSpacing: CGFloat? = nil

    private func measure(_ subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        if ideal.width <= maxWidth { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let vGap = rowSpacing ?? spacing
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = measure(subview, maxWidth: width)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + vGap
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let vGap = rowSpacing ?? spacing
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = measure(subview, maxWidth: bounds.width)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + vGap
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Reaction pill (`.react-btn`)

enum ReactionPillPlacement {
    /// Standalone: line border, ink fill when on.
    case standalone
    /// In the stream footer (`.post__actions .react-btn`): no border, accent tint when on.
    case streamFooter
}

struct ReactionPill<Label: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let on: Bool
    var pending = false
    var placement: ReactionPillPlacement = .streamFooter
    var minWidth: CGFloat?
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    private var colors: (fill: Color, text: Color, border: Color) {
        switch (placement, on) {
        case (.standalone, true): return (theme.ink, theme.surface, theme.ink)
        case (.standalone, false): return (.clear, theme.muted, theme.line)
        case (.streamFooter, true): return (theme.accentTint, theme.accent, .clear)
        case (.streamFooter, false): return (.clear, theme.muted, .clear)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HSpace.x2) { label() }
                .font(ramp.font(.captionSemibold))
                .monospacedDigit()
                .foregroundStyle(colors.text)
                .padding(.horizontal, placement == .streamFooter ? HSpace.x2 : HSpace.x4)
                .frame(minWidth: minWidth, minHeight: HSize.control)
                .background(colors.fill, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(colors.border, lineWidth: 1))
                .contentShape(Rectangle())
                .opacity(pending ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

// MARK: - Fields (`.input`, `.search-box`)

/// `.input`: surface-solid ground, 1 px line, field radius, 44 min, 16 pt.
struct WebFieldStyle: TextFieldStyle {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(ramp.font(.body))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, HSpace.x3)
            .frame(minHeight: HSize.control)
            .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
    }
}

extension TextFieldStyle where Self == WebFieldStyle {
    static var web: WebFieldStyle { WebFieldStyle() }
}

/// `.field__label`: caption, 700, ink mixed toward muted.
struct FieldLabel: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text).hfont(.captionBold).foregroundStyle(theme.inkSoft)
    }
}

/// `.search-field`: the glyph at the left, the clear control at the right.
struct SearchField: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Binding var text: String
    let prompt: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(theme.muted)
                .frame(width: 40, alignment: .center)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(theme.muted))
                .font(ramp.font(.body))
                .foregroundStyle(theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(theme.muted)
                        .frame(width: HSize.control, height: HSize.control)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10nText.clear)
            } else {
                Color.clear.frame(width: HSize.control, height: HSize.control)
            }
        }
        .frame(minHeight: HSize.control)
        .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
    }
}

private enum L10nText {
    static let clear = "Clear search"
}

// MARK: - Switch (`.switch`)

/// 46 × 28, line border, soft ground; on = accent fill, knob 22 travels 18.
struct WebSwitchStyle: ToggleStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? theme.accent : theme.soft)
                    .overlay(Capsule().strokeBorder(configuration.isOn ? theme.accent : theme.line, lineWidth: 1))
                Circle()
                    .fill(theme.surfaceSolid)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .frame(width: 46, height: 28)
            .animation(.easeOut(duration: 0.2), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

extension ToggleStyle where Self == WebSwitchStyle {
    static var webSwitch: WebSwitchStyle { WebSwitchStyle() }
}

// MARK: - Option grid (`.option-grid`: Background / Accent choices)

struct OptionCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let label: String
    let swatch: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                Circle()
                    .fill(swatch)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
                    .frame(width: 23, height: 23)
                Text(label).font(ramp.font(.bodySemibold))
            }
            .foregroundStyle(selected ? theme.surface : theme.ink)
            .padding(HSpace.x3)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .background(selected ? theme.ink : theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(selected ? theme.ink : theme.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
