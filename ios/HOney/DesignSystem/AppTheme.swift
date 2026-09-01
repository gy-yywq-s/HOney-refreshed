//
//  AppTheme.swift
//  HOney
//
//  Editorial, content-first tokens. Compatibility aliases keep feature code
//  compiling while screens migrate away from the legacy visual grammar.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

typealias RGB = (CGFloat, CGFloat, CGFloat)

struct AdaptiveRGB {
    let light: RGB
    let dark: RGB
}

struct SurfacePaletteSpec {
    let canvas: AdaptiveRGB
    let surface: AdaptiveRGB
    let muted: AdaptiveRGB
    let ink: AdaptiveRGB
    let secondaryInk: AdaptiveRGB
    let accent: AdaptiveRGB
    let accentForeground: AdaptiveRGB
    let accentSoft: AdaptiveRGB
    let accentSecondary: AdaptiveRGB
    let accentTertiary: AdaptiveRGB
    let accentQuaternary: AdaptiveRGB
    let line: AdaptiveRGB
    let controlBorder: AdaptiveRGB
}

enum SurfacePalette: String, CaseIterable, Identifiable {
    static let storageKey = "appearance.surfacePalette"

    case paper
    case neutralWhite
    case coolMist
    case softGray
    case warmPaper
    case originalBlue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: return "Porcelain"
        case .neutralWhite: return "Clean White"
        case .coolMist: return "Blue Mist"
        case .softGray: return "Sage Gray"
        case .warmPaper: return "Warm Paper"
        case .originalBlue: return "Original Blue"
        }
    }

    static var current: SurfacePalette {
        SurfacePalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .paper
    }

    var spec: SurfacePaletteSpec {
        switch self {
        case .paper:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.961, 0.969, 0.973), dark: (0.059, 0.090, 0.129)),
                surface: .init(light: (0.988, 0.992, 0.992), dark: (0.082, 0.122, 0.169)),
                muted: .init(light: (0.914, 0.933, 0.945), dark: (0.110, 0.161, 0.212)),
                ink: .init(light: (0.078, 0.149, 0.239), dark: (0.918, 0.941, 0.961)),
                secondaryInk: .init(light: (0.294, 0.357, 0.431), dark: (0.682, 0.753, 0.812)),
                accent: .init(light: (0.141, 0.361, 0.573), dark: (0.459, 0.682, 0.882)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.043, 0.106, 0.169)),
                accentSoft: .init(light: (0.863, 0.914, 0.953), dark: (0.106, 0.220, 0.322)),
                accentSecondary: .init(light: (0.133, 0.408, 0.318), dark: (0.384, 0.722, 0.608)),
                accentTertiary: .init(light: (0.529, 0.329, 0.102), dark: (0.851, 0.655, 0.349)),
                accentQuaternary: .init(light: (0.408, 0.302, 0.510), dark: (0.718, 0.608, 0.831)),
                line: .init(light: (0.824, 0.859, 0.886), dark: (0.200, 0.286, 0.369)),
                controlBorder: .init(light: (0.392, 0.459, 0.525), dark: (0.471, 0.565, 0.639))
            )
        case .neutralWhite:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.980, 0.984, 0.988), dark: (0.051, 0.071, 0.102)),
                surface: .init(light: (1, 1, 1), dark: (0.078, 0.106, 0.145)),
                muted: .init(light: (0.941, 0.953, 0.965), dark: (0.106, 0.145, 0.192)),
                ink: .init(light: (0.063, 0.110, 0.169), dark: (0.941, 0.953, 0.969)),
                secondaryInk: .init(light: (0.282, 0.337, 0.416), dark: (0.710, 0.753, 0.804)),
                accent: .init(light: (0.192, 0.373, 0.604), dark: (0.518, 0.663, 0.875)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.035, 0.090, 0.149)),
                accentSoft: .init(light: (0.890, 0.922, 0.961), dark: (0.122, 0.208, 0.322)),
                accentSecondary: .init(light: (0.075, 0.431, 0.412), dark: (0.341, 0.753, 0.714)),
                accentTertiary: .init(light: (0.643, 0.318, 0.118), dark: (0.922, 0.631, 0.333)),
                accentQuaternary: .init(light: (0.439, 0.286, 0.557), dark: (0.761, 0.600, 0.882)),
                line: .init(light: (0.863, 0.886, 0.910), dark: (0.204, 0.259, 0.333)),
                controlBorder: .init(light: (0.408, 0.467, 0.541), dark: (0.510, 0.569, 0.643))
            )
        case .coolMist:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.933, 0.957, 0.969), dark: (0.047, 0.102, 0.137)),
                surface: .init(light: (0.976, 0.988, 0.992), dark: (0.071, 0.141, 0.184)),
                muted: .init(light: (0.875, 0.918, 0.941), dark: (0.098, 0.192, 0.243)),
                ink: .init(light: (0.063, 0.169, 0.239), dark: (0.906, 0.949, 0.965)),
                secondaryInk: .init(light: (0.271, 0.380, 0.443), dark: (0.675, 0.776, 0.820)),
                accent: .init(light: (0.129, 0.400, 0.518), dark: (0.447, 0.722, 0.816)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.027, 0.106, 0.141)),
                accentSoft: .init(light: (0.824, 0.906, 0.937), dark: (0.090, 0.231, 0.286)),
                accentSecondary: .init(light: (0.227, 0.365, 0.620), dark: (0.502, 0.690, 0.902)),
                accentTertiary: .init(light: (0.588, 0.357, 0.098), dark: (0.882, 0.667, 0.337)),
                accentQuaternary: .init(light: (0.451, 0.302, 0.537), dark: (0.749, 0.624, 0.847)),
                line: .init(light: (0.780, 0.851, 0.886), dark: (0.180, 0.318, 0.376)),
                controlBorder: .init(light: (0.345, 0.467, 0.529), dark: (0.431, 0.573, 0.624))
            )
        case .softGray:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.945, 0.961, 0.953), dark: (0.063, 0.106, 0.106)),
                surface: .init(light: (0.984, 0.988, 0.984), dark: (0.090, 0.149, 0.149)),
                muted: .init(light: (0.894, 0.925, 0.910), dark: (0.122, 0.200, 0.192)),
                ink: .init(light: (0.094, 0.188, 0.184), dark: (0.914, 0.949, 0.941)),
                secondaryInk: .init(light: (0.302, 0.396, 0.384), dark: (0.694, 0.776, 0.757)),
                accent: .init(light: (0.184, 0.416, 0.439), dark: (0.471, 0.729, 0.741)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.043, 0.102, 0.106)),
                accentSoft: .init(light: (0.843, 0.914, 0.910), dark: (0.110, 0.235, 0.243)),
                accentSecondary: .init(light: (0.208, 0.357, 0.573), dark: (0.498, 0.671, 0.847)),
                accentTertiary: .init(light: (0.565, 0.337, 0.118), dark: (0.867, 0.663, 0.373)),
                accentQuaternary: .init(light: (0.427, 0.310, 0.494), dark: (0.733, 0.620, 0.800)),
                line: .init(light: (0.796, 0.855, 0.839), dark: (0.192, 0.310, 0.298)),
                controlBorder: .init(light: (0.376, 0.475, 0.463), dark: (0.463, 0.565, 0.549))
            )
        case .warmPaper:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.973, 0.969, 0.953), dark: (0.071, 0.082, 0.098)),
                surface: .init(light: (0.995, 0.992, 0.980), dark: (0.105, 0.118, 0.137)),
                muted: .init(light: (0.941, 0.941, 0.918), dark: (0.137, 0.153, 0.173)),
                ink: .init(light: (0.075, 0.102, 0.153), dark: (0.925, 0.937, 0.945)),
                secondaryInk: .init(light: (0.300, 0.326, 0.357), dark: (0.690, 0.718, 0.745)),
                accent: .init(light: (0.102, 0.421, 0.486), dark: (0.365, 0.718, 0.765)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.055, 0.075, 0.090)),
                accentSoft: .init(light: (0.855, 0.918, 0.914), dark: (0.118, 0.235, 0.255)),
                accentSecondary: .init(light: (0.259, 0.369, 0.612), dark: (0.510, 0.675, 0.886)),
                accentTertiary: .init(light: (0.561, 0.341, 0.133), dark: (0.855, 0.667, 0.404)),
                accentQuaternary: .init(light: (0.439, 0.306, 0.510), dark: (0.741, 0.616, 0.816)),
                line: .init(light: (0.824, 0.831, 0.812), dark: (0.235, 0.255, 0.278)),
                controlBorder: .init(light: (0.392, 0.412, 0.420), dark: (0.490, 0.518, 0.553))
            )
        case .originalBlue:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.930, 0.970, 1.000), dark: (0.090, 0.090, 0.110)),
                surface: .init(light: (1.000, 1.000, 1.000), dark: (0.118, 0.125, 0.149)),
                muted: .init(light: (0.840, 0.930, 1.000), dark: (0.149, 0.180, 0.220)),
                ink: .init(light: (0.070, 0.190, 0.360), dark: (0.925, 0.945, 0.973)),
                secondaryInk: .init(light: (0.270, 0.357, 0.455), dark: (0.690, 0.753, 0.824)),
                accent: .init(light: (0.082, 0.400, 0.529), dark: (0.475, 0.733, 0.831)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.039, 0.098, 0.133)),
                accentSoft: .init(light: (0.820, 0.914, 0.969), dark: (0.106, 0.224, 0.294)),
                accentSecondary: .init(light: (0.220, 0.435, 0.690), dark: (0.529, 0.718, 0.933)),
                accentTertiary: .init(light: (0.643, 0.353, 0.122), dark: (0.914, 0.659, 0.361)),
                accentQuaternary: .init(light: (0.439, 0.310, 0.569), dark: (0.757, 0.616, 0.890)),
                line: .init(light: (0.800, 0.880, 0.950), dark: (0.235, 0.286, 0.357)),
                controlBorder: .init(light: (0.353, 0.467, 0.573), dark: (0.490, 0.588, 0.675))
            )
        }
    }
}

enum AppTheme {
    enum Colors {
        #if canImport(UIKit)
        private static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> Color {
            Color(uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
            })
        }
        #else
        private static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> Color {
            Color(red: light.0, green: light.1, blue: light.2)
        }
        #endif

        private static var spec: SurfacePaletteSpec { SurfacePalette.current.spec }
        static var canvas: Color { adaptive(light: spec.canvas.light, dark: spec.canvas.dark) }
        static var surface: Color { adaptive(light: spec.surface.light, dark: spec.surface.dark) }
        static var surfaceMuted: Color { adaptive(light: spec.muted.light, dark: spec.muted.dark) }
        static var ink: Color { adaptive(light: spec.ink.light, dark: spec.ink.dark) }
        static var inkSecondary: Color { adaptive(light: spec.secondaryInk.light, dark: spec.secondaryInk.dark) }
        static var accent: Color { adaptive(light: spec.accent.light, dark: spec.accent.dark) }
        static var accentForeground: Color { adaptive(light: spec.accentForeground.light, dark: spec.accentForeground.dark) }
        static var accentSoft: Color { adaptive(light: spec.accentSoft.light, dark: spec.accentSoft.dark) }
        static var accentSecondary: Color { adaptive(light: spec.accentSecondary.light, dark: spec.accentSecondary.dark) }
        static var accentTertiary: Color { adaptive(light: spec.accentTertiary.light, dark: spec.accentTertiary.dark) }
        static var accentQuaternary: Color { adaptive(light: spec.accentQuaternary.light, dark: spec.accentQuaternary.dark) }
        static var line: Color { adaptive(light: spec.line.light, dark: spec.line.dark) }
        static var controlBorder: Color { adaptive(light: spec.controlBorder.light, dark: spec.controlBorder.dark) }
        static let successRGB = AdaptiveRGB(light: (0.055, 0.345, 0.175), dark: (0.345, 0.745, 0.482))
        static let warningRGB = AdaptiveRGB(light: (0.500, 0.245, 0.020), dark: (0.933, 0.651, 0.286))
        static let errorRGB = AdaptiveRGB(light: (0.710, 0.153, 0.192), dark: (0.949, 0.404, 0.435))
        static var success: Color { adaptive(light: successRGB.light, dark: successRGB.dark) }
        static var warning: Color { adaptive(light: warningRGB.light, dark: warningRGB.dark) }
        static var error: Color { adaptive(light: errorRGB.light, dark: errorRGB.dark) }

        // Compatibility names used by feature views.
        static var navy: Color { ink }
        static var ocean: Color { accent }
        static var mist: Color { surfaceMuted }
        static var background: Color { canvas }

        static var detailAccents: [Color] { [accent, accentSecondary, accentTertiary, accentQuaternary] }
        static var interactiveAccent: Color { accent }
        static var communityMarker: Color { accentSecondary }
        static var accessMarker: Color { accentTertiary }
        static var portalMarker: Color { accentQuaternary }

        static func scheduleMarker(for stableKey: String) -> Color {
            let scalarTotal = stableKey.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            let colors = detailAccents
            return colors[scalarTotal % colors.count]
        }
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pageHorizontal: CGFloat = 20
        static let loginHorizontal: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
    }

    enum Typography {
        static let loginControlHeight: CGFloat = 52

        static let titleDesign: Font.Design = .default
        static let bodyDesign: Font.Design = .default
        static var loginField: Font { .system(.body, design: bodyDesign, weight: .regular) }
        static var screenTitle: Font { .system(.title, design: titleDesign, weight: .bold) }
        static var sectionTitle: Font { .system(.title3, design: titleDesign, weight: .semibold) }
        static var cardTitle: Font { .system(.headline, design: titleDesign, weight: .semibold) }
        static var headline: Font { .system(.headline, design: bodyDesign, weight: .regular) }
        static var headlineSemibold: Font { .system(.headline, design: bodyDesign, weight: .semibold) }
        static var subheadline: Font { .system(.subheadline, design: bodyDesign, weight: .regular) }
        static var subheadlineMedium: Font { .system(.subheadline, design: bodyDesign, weight: .medium) }
        static var subheadlineSemibold: Font { .system(.subheadline, design: bodyDesign, weight: .semibold) }
        static var subheadlineBold: Font { .system(.subheadline, design: bodyDesign, weight: .bold) }
        static var caption: Font { .system(.caption, design: bodyDesign, weight: .regular) }
        static var captionMedium: Font { .system(.caption, design: bodyDesign, weight: .medium) }
        static var captionSemibold: Font { .system(.caption, design: bodyDesign, weight: .semibold) }
        static var captionBold: Font { .system(.caption, design: bodyDesign, weight: .bold) }
        static var caption2: Font { .system(.caption2, design: bodyDesign, weight: .regular) }
        static var caption2Semibold: Font { .system(.caption2, design: bodyDesign, weight: .semibold) }
        static var caption2Bold: Font { .system(.caption2, design: bodyDesign, weight: .bold) }
        static var footnote: Font { .system(.footnote, design: bodyDesign, weight: .regular) }
        static var footnoteMedium: Font { .system(.footnote, design: bodyDesign, weight: .medium) }
        static var title3: Font { .system(.title3, design: bodyDesign, weight: .regular) }
        static var scheduleHeader: Font { .system(.title3, design: titleDesign, weight: .semibold) }
        static var lessonTitle: Font { .system(.subheadline, design: bodyDesign, weight: .semibold) }
        static var lessonCompactTitle: Font { .system(.caption, design: bodyDesign, weight: .semibold) }
        static var lessonMeta: Font { caption }
        static var lessonCompactMeta: Font { caption2 }

        static func lessonTimelineTitle(isCompact: Bool) -> Font {
            isCompact ? lessonCompactTitle : lessonTitle
        }

        static func lessonTimelineMeta(isCompact: Bool) -> Font {
            isCompact ? lessonCompactMeta : lessonMeta
        }
    }

    enum Motion {
        static var fast: Animation? {
            AppConfig.enableAnimations ? .snappy(duration: 0.16) : nil
        }

        static var standard: Animation? {
            AppConfig.enableAnimations ? .snappy(duration: 0.22, extraBounce: 0.02) : nil
        }
    }
}

typealias Palette = AppTheme.Colors
