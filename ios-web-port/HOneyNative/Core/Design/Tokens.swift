// Semantic tokens derived from the Web's quiet-humanist palette
// (tokens.css at 2d1b562), as dynamic colours with a tested dark side —
// not the Web's four-surface selector (spec §7.2). System typography and
// Dynamic Type replace the Web's fixed ramp (§7.3); the spacing ladder is
// the Web's (§7.4).

import SwiftUI
import UIKit
import HOneyCore

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }
}

extension Color {
    private static func tone(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: .dynamic(light: UIColor(hex: light, alpha: lightAlpha), dark: UIColor(hex: dark, alpha: darkAlpha)))
    }

    /// The page ground (stone / night).
    static let honeyCanvas = tone(0xF4F6F7, 0x14171A)
    /// Grouped surfaces: sheets, the Portal row, list cells.
    static let honeySurface = tone(0xFBFCFC, 0x1D2125)
    /// The lesson card and Week cells — white on the stone ground.
    static let honeyCell = tone(0xFFFFFF, 0x1D2125)
    /// A soft wash: pressed rows, free-period bands.
    static let honeySoft = tone(0x232B31, 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.06)
    static let honeyInk = tone(0x232B31, 0xE9EDEF)
    static let honeySecondary = tone(0x5C6770, 0xA6AFB5)
    static let honeyTertiary = tone(0x667079, 0x8B949B)
    static let honeyLine = tone(0x232B31, 0xE9EDEF, lightAlpha: 0.14, darkAlpha: 0.16)
    /// The lesson card's frame (ink at 28%).
    static let honeyFrame = tone(0x232B31, 0xE9EDEF, lightAlpha: 0.28, darkAlpha: 0.32)
    /// ONE muted blue-teal accent + its quiet tint.
    static let honeyAccent = tone(0x33667C, 0x8FC2D4)
    static let honeyAccentTint = tone(0xDDE8EC, 0x8FC2D4, darkAlpha: 0.16)
    static let honeyOnAccent = tone(0xFFFFFF, 0x10181C)
    static let honeyDanger = tone(0xB53844, 0xF2919A)
    static let honeyDangerTint = tone(0xB53844, 0xF2919A, lightAlpha: 0.1, darkAlpha: 0.16)
    static let honeySuccess = tone(0x2B7355, 0x83C9A8)
    static let honeySuccessTint = tone(0x2B7355, 0x83C9A8, lightAlpha: 0.1, darkAlpha: 0.16)
    static let honeyWarning = tone(0x8A5A00, 0xE9AC55)
    static let honeyWarningTint = tone(0x8A5A00, 0xE9AC55, lightAlpha: 0.1, darkAlpha: 0.16)
    /// The Day timeline's now-line.
    static let honeyNow = tone(0xB53844, 0xF2919A)
    /// Break bands (Lunch/Dinner) on the Day canvas: a pale green wash.
    static let honeyBreak = tone(0x2B7355, 0x83C9A8, lightAlpha: 0.08, darkAlpha: 0.12)
}

extension AppearanceChoice {
    /// System / Light / Dark → the scheme to force, or nil for the system's.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The Web's spacing ladder, in points.
enum HSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x7: CGFloat = 32
    static let x8: CGFloat = 44
    /// One page inset on phones.
    static let pageX: CGFloat = 20
}

enum HRadius {
    static let card: CGFloat = 16
    static let control: CGFloat = 14
    static let field: CGFloat = 12
}

/// Type roles on top of Dynamic Type (spec §7.3).
enum HType {
    static let greeting = Font.system(.largeTitle, design: .default).weight(.medium)
    static let pageTitle = Font.system(.title, design: .default).weight(.semibold)
    static let lessonSubject = Font.system(.title2, design: .default).weight(.semibold)
    static let sectionLabel = Font.system(.caption, design: .default).weight(.semibold)
    static let body = Font.body
    static let reading = Font.body
    static let feature = Font.title3
    static let secondary = Font.subheadline
    static let meta = Font.footnote
    static let micro = Font.caption
}

extension View {
    /// An uppercase eyebrow the way the Web sets section labels.
    func eyebrow() -> some View {
        self.font(HType.sectionLabel)
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(Color.honeySecondary)
    }
}
