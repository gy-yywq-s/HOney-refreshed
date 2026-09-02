// Source Sans 3 (fidelity spec v2 §3.6–3.7): the Web's one humanist sans
// for Latin UI, display and reading roles, bundled as the variable font
// (Resources/Fonts, OFL). CJK falls to the system face, as on the Web. The
// ramp is the Web's in points, multiplied by the Text size choice, then
// handed to UIFontMetrics so Dynamic Type still applies on top.

import SwiftUI
import UIKit

/// One role on the Web type ramp (tokens.css `--fs-*`, foundations.css,
/// features.css), at Default text size and a 390 pt viewport.
struct TypeRole: Hashable {
    let size: CGFloat
    let weight: CGFloat
    let textStyle: Font.TextStyle
    /// `letter-spacing` in em.
    let tracking: CGFloat
    /// `line-height` as a multiple of the size.
    let lineHeight: CGFloat
    var italic = false

    // Ramp
    static let micro = TypeRole(size: 12, weight: 400, textStyle: .caption2, tracking: 0, lineHeight: 1.4)
    static let microSemibold = TypeRole(size: 12, weight: 600, textStyle: .caption2, tracking: 0.01, lineHeight: 1.4)
    static let microBold = TypeRole(size: 12, weight: 700, textStyle: .caption2, tracking: 0, lineHeight: 1.4)
    static let caption = TypeRole(size: 13, weight: 400, textStyle: .footnote, tracking: 0, lineHeight: 1.4)
    static let captionMedium = TypeRole(size: 13, weight: 500, textStyle: .footnote, tracking: 0, lineHeight: 1.4)
    static let captionSemibold = TypeRole(size: 13, weight: 600, textStyle: .footnote, tracking: 0, lineHeight: 1.4)
    static let captionBold = TypeRole(size: 13, weight: 700, textStyle: .footnote, tracking: 0, lineHeight: 1.4)
    static let secondary = TypeRole(size: 15, weight: 400, textStyle: .subheadline, tracking: 0, lineHeight: 1.5)
    static let secondaryMedium = TypeRole(size: 15, weight: 500, textStyle: .subheadline, tracking: 0, lineHeight: 1.5)
    static let secondarySemibold = TypeRole(size: 15, weight: 600, textStyle: .subheadline, tracking: 0, lineHeight: 1.5)
    static let body = TypeRole(size: 16, weight: 400, textStyle: .body, tracking: 0, lineHeight: 1.5)
    static let bodySemibold = TypeRole(size: 16, weight: 600, textStyle: .body, tracking: 0, lineHeight: 1.5)
    static let reading = TypeRole(size: 17, weight: 400, textStyle: .body, tracking: 0, lineHeight: 1.55)
    static let readingSemibold = TypeRole(size: 17, weight: 600, textStyle: .body, tracking: 0, lineHeight: 1.45)
    static let readingItalic = TypeRole(size: 17, weight: 400, textStyle: .body, tracking: 0, lineHeight: 1.55, italic: true)
    /// Short posts (`.post__body--feature`).
    static let feature = TypeRole(size: 20, weight: 400, textStyle: .title3, tracking: -0.008, lineHeight: 1.45)
    /// `.section-title`, `.picker__title`, `.daynav__date`.
    static let sectionTitle = TypeRole(size: 20, weight: 650, textStyle: .title3, tracking: -0.01, lineHeight: 1.2)
    static let title = TypeRole(size: 22, weight: 600, textStyle: .title2, tracking: -0.01, lineHeight: 1.2)
    /// `.modal__title` at 390 pt.
    static let modalTitle = TypeRole(size: 22, weight: 650, textStyle: .title2, tracking: -0.02, lineHeight: 1.15)
    /// `.compose-target__label` at 390 pt.
    static let composeTarget = TypeRole(size: 22, weight: 400, textStyle: .title2, tracking: -0.03, lineHeight: 1.2)
    /// `.page-title` at 390 pt (clamp(30px, 3.2vw, 34px)).
    static let pageTitle = TypeRole(size: 30, weight: 650, textStyle: .largeTitle, tracking: -0.015, lineHeight: 1.1)
    /// `.home-head__hi` at 390 pt (clamp(24px, 4vw, 32px)).
    static let greeting = TypeRole(size: 24, weight: 500, textStyle: .title, tracking: -0.01, lineHeight: 1.2)
    /// `.nextlesson__subject` at 390 pt (clamp(25px, 6vw, 29px)).
    static let lessonSubject = TypeRole(size: 25, weight: 600, textStyle: .title, tracking: -0.015, lineHeight: 1.12)
    /// The inline navigation-bar title (a pushed screen's `.page-title`, compacted).
    static let navTitle = TypeRole(size: 17, weight: 600, textStyle: .headline, tracking: -0.01, lineHeight: 1.2)
}

/// The ramp bound to the current text scale, from the environment.
struct HTypeRamp {
    let scale: CGFloat

    func font(_ role: TypeRole) -> Font { HOneyFont.font(role: role, scale: scale) }
    func lineSpacing(_ role: TypeRole) -> CGFloat { HOneyFont.lineSpacing(role: role, scale: scale) }
    func tracking(_ role: TypeRole) -> CGFloat { role.tracking * role.size * scale }
}

private struct HTypeKey: EnvironmentKey {
    static let defaultValue = HTypeRamp(scale: 1)
}

extension EnvironmentValues {
    var hType: HTypeRamp {
        get { self[HTypeKey.self] }
        set { self[HTypeKey.self] = newValue }
    }
}

enum HOneyFont {
    static let family = "SourceSans3VF"
    private static let uprightName = "SourceSans3VF-ExtraLight" // the variable font's default instance
    private static let italicName = "SourceSans3VF-ExtraLightItalic"
    private static let weightAxis: Int = 0x7767_6874 // 'wght'

    /// Whether the bundled font registered (the tests assert it on the simulator).
    static var isAvailable: Bool { UIFont.familyNames.contains(family) }

    static func uiFont(role: TypeRole, scale: CGFloat) -> UIFont {
        let size = role.size * scale
        let variation: [NSNumber: NSNumber] = [NSNumber(value: weightAxis): NSNumber(value: Double(role.weight))]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: role.italic ? italicName : uprightName,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        let base = isAvailable ? UIFont(descriptor: descriptor, size: size) : fallback(role: role, size: size)
        return UIFontMetrics(forTextStyle: role.textStyle.uiTextStyle).scaledFont(for: base)
    }

    static func font(role: TypeRole, scale: CGFloat) -> Font {
        Font(uiFont(role: role, scale: scale))
    }

    /// Extra leading so the line box matches the Web's `line-height`.
    static func lineSpacing(role: TypeRole, scale: CGFloat) -> CGFloat {
        let font = uiFont(role: role, scale: scale)
        return max(0, role.lineHeight * font.pointSize - font.lineHeight)
    }

    private static func fallback(role: TypeRole, size: CGFloat) -> UIFont {
        let weight: UIFont.Weight = role.weight >= 650 ? .bold : role.weight >= 600 ? .semibold : role.weight >= 500 ? .medium : .regular
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        case .extraLargeTitle: return .extraLargeTitle
        case .extraLargeTitle2: return .extraLargeTitle2
        @unknown default: return .body
        }
    }
}

// MARK: - View helpers

private struct HFontModifier: ViewModifier {
    @Environment(\.hType) private var ramp
    let role: TypeRole

    func body(content: Content) -> some View {
        content
            .font(ramp.font(role))
            .tracking(ramp.tracking(role))
            .lineSpacing(ramp.lineSpacing(role))
    }
}

private struct SectionLabelModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp

    func body(content: Content) -> some View {
        // `.eyebrow` / `.overline` (foundations.css): the exact source
        // string, sentence case, caption size, 600, 0.01em, muted. Never
        // uppercased — Gary 2026-09-01, fidelity spec v2 §3.8.
        content
            .font(ramp.font(.captionSemibold))
            .tracking(0.01 * 13 * ramp.scale)
            .foregroundStyle(theme.muted)
    }
}

extension View {
    /// A Web type role: family, size × text scale, weight, tracking, leading.
    func hfont(_ role: TypeRole) -> some View { modifier(HFontModifier(role: role)) }

    /// A section label above a group of rows or previews.
    func sectionLabel() -> some View { modifier(SectionLabelModifier()) }
}

extension Text {
    /// `Text` keeps its concatenation ability when the font is applied directly.
    func hfont(_ role: TypeRole, _ ramp: HTypeRamp) -> Text {
        font(ramp.font(role)).tracking(ramp.tracking(role))
    }
}
