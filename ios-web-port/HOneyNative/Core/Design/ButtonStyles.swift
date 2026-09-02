// Web-faithful buttons (components.css `.btn*`, `.iconbtn*`; fidelity spec
// v2 §4.1–4.2): ink fill = primary, ghost = outlined, danger fill, danger
// outline, the small variant, and the 44 × 44 icon control. Never
// `.borderedProminent`: the accent is not a button colour on the Web.

import SwiftUI

enum WebButtonKind {
    case primary, ghost, danger, dangerOutline
}

/// `.btn` — 44 min height, control radius, 15/600 label, 1 px line.
struct WebButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @Environment(\.isEnabled) private var isEnabled
    var kind: WebButtonKind = .ghost
    /// `.btn--small`: caption label, 12 pt radius, tighter padding (44 tall on touch).
    var small = false
    /// `.btn--block`: full width.
    var block = false
    /// `.login .btn`: the reading size.
    var reading = false

    func makeBody(configuration: Configuration) -> some View {
        let colors = Self.colors(kind: kind, enabled: isEnabled, theme: theme)
        configuration.label
            .font(ramp.font(reading ? .readingSemibold : small ? .captionSemibold : .secondarySemibold))
            .foregroundStyle(colors.text)
            .lineLimit(1)
            .padding(.horizontal, small ? HSpace.x3 : HSpace.x5)
            .frame(maxWidth: block ? .infinity : nil)
            .frame(minHeight: HSize.control)
            .background(colors.fill, in: RoundedRectangle(cornerRadius: small ? HRadius.field : HRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: small ? HRadius.field : HRadius.control, style: .continuous).strokeBorder(colors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: HRadius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }

    static func colors(kind: WebButtonKind, enabled: Bool, theme: HOneyTheme) -> (fill: Color, text: Color, border: Color) {
        // One disabled treatment for every button: transparent, muted, soft border.
        guard enabled else { return (.clear, theme.muted, theme.line) }
        switch kind {
        case .primary: return (theme.ink, theme.surface, theme.ink)
        case .ghost: return (.clear, theme.ink, theme.line)
        case .danger: return (theme.danger, theme.onDanger, theme.danger)
        case .dangerOutline: return (.clear, theme.danger, theme.danger)
        }
    }
}

extension ButtonStyle where Self == WebButtonStyle {
    static var webPrimary: WebButtonStyle { WebButtonStyle(kind: .primary) }
    static var webGhost: WebButtonStyle { WebButtonStyle(kind: .ghost) }
    static var webDanger: WebButtonStyle { WebButtonStyle(kind: .danger) }
    static var webDangerOutline: WebButtonStyle { WebButtonStyle(kind: .dangerOutline) }
    static var webSmallGhost: WebButtonStyle { WebButtonStyle(kind: .ghost, small: true) }
    static var webSmallPrimary: WebButtonStyle { WebButtonStyle(kind: .primary, small: true) }
    static var webSmallDangerOutline: WebButtonStyle { WebButtonStyle(kind: .dangerOutline, small: true) }
    static var webBlockPrimary: WebButtonStyle { WebButtonStyle(kind: .primary, block: true) }
    static var webBlockGhost: WebButtonStyle { WebButtonStyle(kind: .ghost, block: true) }
    static var webBlockDanger: WebButtonStyle { WebButtonStyle(kind: .danger, block: true) }
    static var webLoginPrimary: WebButtonStyle { WebButtonStyle(kind: .primary, block: true, reading: true) }
}

/// `.iconbtn` — 44 × 44, field radius, line border; `--primary` = ink fill.
struct WebIconButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: HSize.icon, weight: .regular))
            .foregroundStyle(primary ? theme.surface : theme.ink)
            .frame(width: HSize.control, height: HSize.control)
            .background(primary ? theme.ink : Color.clear, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(primary ? theme.ink : theme.line, lineWidth: 1))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == WebIconButtonStyle {
    static var webIcon: WebIconButtonStyle { WebIconButtonStyle() }
    static var webIconPrimary: WebIconButtonStyle { WebIconButtonStyle(primary: true) }
}

/// A plain text link in the accent (`a { color: var(--accent) }`), 44 pt tall.
struct WebLinkStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    var role: TypeRole = .captionSemibold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ramp.font(role))
            .foregroundStyle(theme.accent)
            .frame(minHeight: HSize.control)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == WebLinkStyle {
    static var webLink: WebLinkStyle { WebLinkStyle() }
    static var webLinkBody: WebLinkStyle { WebLinkStyle(role: .body) }
}

/// A row-shaped button that presses like a list cell (`.row:hover` → soft).
struct RowButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? theme.soft : Color.clear)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == RowButtonStyle {
    static var row: RowButtonStyle { RowButtonStyle() }
}
