// The live theme (fidelity spec v2 §3.1): one value built from the chosen
// Background × Accent × Text size, carrying every colour the Web derives
// from tokens.css and the type scale. Views read it from the environment;
// nothing draws a fixed Harbour or a fixed grey.

import SwiftUI
import UIKit
import HOneyCore

extension RGBA {
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    var color: Color { Color(uiColor: uiColor) }
}

struct HOneyTheme: Equatable {
    let palette: ThemePalette
    let textSize: HOneyTextSize

    init(background: HOneyBackground, accent: HOneyAccent, textSize: HOneyTextSize) {
        palette = ThemePalette.resolve(background: background, accent: accent)
        self.textSize = textSize
    }

    var background: HOneyBackground { palette.background }
    var accentChoice: HOneyAccent { palette.accentChoice }
    var isNight: Bool { palette.background.isNight }
    /// Night carries dark system chrome; the three light surfaces light chrome.
    var colorScheme: ColorScheme { isNight ? .dark : .light }
    var scale: CGFloat { CGFloat(textSize.scale) }

    // Surfaces
    var surface: Color { palette.surface.color }
    var surfaceSolid: Color { palette.surfaceSolid.color }
    var cell: Color { palette.cell.color }
    var card: Color { palette.card.color }
    var soft: Color { palette.soft.color }
    var wash: Color { palette.wash.color }
    // Ink
    var ink: Color { palette.ink.color }
    var ink2: Color { palette.ink2.color }
    var ink3: Color { palette.ink3.color }
    var muted: Color { palette.muted.color }
    var inkSoft: Color { palette.inkSoft.color }
    var line: Color { palette.line.color }
    var frame: Color { palette.frame.color }
    // Accent scheme
    var accent: Color { palette.accent.color }
    var accent2: Color { palette.accent2.color }
    var accentTint: Color { palette.accentTint.color }
    var onAccent: Color { palette.onAccent.color }
    var progressWash: Color { palette.progressWash.color }
    var breakBand: Color { palette.breakBand.color }
    var gridline: Color { palette.gridline.color }
    var todayColumn: Color { palette.todayColumn.color }
    // Semantic
    var danger: Color { palette.danger.color }
    var ok: Color { palette.ok.color }
    /// `.btn--danger` text: white, except on Night where ink passes AA.
    var onDanger: Color { isNight ? Color(uiColor: UIColor(red: 0x14 / 255, green: 0x17 / 255, blue: 0x1A / 255, alpha: 1)) : .white }
    var warn: Color { palette.warn.color }
    var shadow: Color { palette.shadow.color }
    var shadowCard: Color { palette.shadowCard.color }
    var shadowField: Color { palette.shadowField.color }
    /// `color-mix(in srgb, var(--danger) 8%, transparent)` etc. — banner grounds.
    func tint(_ base: RGBA, _ amount: Double) -> Color { base.withAlpha(amount).color }

    // UIKit-side colours for appearance proxies (tab bar, navigation bar).
    var uiSurface: UIColor { palette.surface.uiColor }
    var uiInk: UIColor { palette.ink.uiColor }
    var uiAccent: UIColor { palette.accent.uiColor }
    var uiMuted: UIColor { palette.muted.uiColor }
}

extension View {
    /// `--shadow-field`: the very small edge shadow an unfilled field or pill
    /// carries so it sits ON the surface (Gary 2026-09-04). A disabled
    /// control is flat — there is nothing to press.
    func fieldShadow(_ theme: HOneyTheme, enabled: Bool = true) -> some View {
        shadow(color: enabled ? theme.shadowField : .clear, radius: 1.5, y: 1)
    }

    /// `--shadow-card`: a card that sits on the surface — the soft edge
    /// (0 8px 22px) over the hairline lift.
    func cardShadow(_ theme: HOneyTheme) -> some View {
        shadow(color: theme.shadowField, radius: 1.5, y: 1)
            .shadow(color: theme.shadowCard, radius: 11, y: 8)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = HOneyTheme(background: .stone, accent: .harbour, textSize: .default)
}

extension EnvironmentValues {
    var theme: HOneyTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
