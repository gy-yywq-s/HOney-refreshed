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
    let line: AdaptiveRGB
    let controlBorder: AdaptiveRGB
}

enum SurfacePalette: String, CaseIterable, Identifiable {
    static let storageKey = "appearance.surfacePalette"

    case paper
    case neutralWhite
    case coolMist
    case softGray

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: return "Paper"
        case .neutralWhite: return "Neutral White"
        case .coolMist: return "Cool Mist"
        case .softGray: return "Soft Gray"
        }
    }

    static var current: SurfacePalette {
        SurfacePalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .paper
    }

    var spec: SurfacePaletteSpec {
        switch self {
        case .paper:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.973, 0.969, 0.953), dark: (0.071, 0.082, 0.098)),
                surface: .init(light: (0.995, 0.992, 0.980), dark: (0.105, 0.118, 0.137)),
                muted: .init(light: (0.941, 0.941, 0.918), dark: (0.137, 0.153, 0.173)),
                ink: .init(light: (0.075, 0.102, 0.153), dark: (0.925, 0.937, 0.945)),
                secondaryInk: .init(light: (0.300, 0.326, 0.357), dark: (0.690, 0.718, 0.745)),
                accent: .init(light: (0.102, 0.421, 0.486), dark: (0.365, 0.718, 0.765)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.055, 0.075, 0.090)),
                accentSoft: .init(light: (0.855, 0.918, 0.914), dark: (0.118, 0.235, 0.255)),
                line: .init(light: (0.824, 0.831, 0.812), dark: (0.235, 0.255, 0.278)),
                controlBorder: .init(light: (0.435, 0.455, 0.455), dark: (0.520, 0.555, 0.585))
            )
        case .neutralWhite:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.988, 0.988, 0.982), dark: (0.061, 0.069, 0.080)),
                surface: .init(light: (1, 1, 0.998), dark: (0.095, 0.105, 0.118)),
                muted: .init(light: (0.949, 0.951, 0.949), dark: (0.132, 0.144, 0.158)),
                ink: .init(light: (0.065, 0.082, 0.112), dark: (0.941, 0.945, 0.949)),
                secondaryInk: .init(light: (0.286, 0.306, 0.333), dark: (0.704, 0.722, 0.741)),
                accent: .init(light: (0.071, 0.388, 0.478), dark: (0.392, 0.737, 0.800)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.043, 0.061, 0.073)),
                accentSoft: .init(light: (0.847, 0.915, 0.925), dark: (0.105, 0.229, 0.267)),
                line: .init(light: (0.842, 0.850, 0.850), dark: (0.226, 0.244, 0.263)),
                controlBorder: .init(light: (0.445, 0.465, 0.480), dark: (0.515, 0.548, 0.580))
            )
        case .coolMist:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.953, 0.971, 0.975), dark: (0.052, 0.071, 0.086)),
                surface: .init(light: (0.987, 0.996, 0.998), dark: (0.083, 0.105, 0.122)),
                muted: .init(light: (0.898, 0.931, 0.938), dark: (0.116, 0.151, 0.173)),
                ink: .init(light: (0.050, 0.087, 0.122), dark: (0.921, 0.949, 0.957)),
                secondaryInk: .init(light: (0.274, 0.337, 0.373), dark: (0.682, 0.745, 0.773)),
                accent: .init(light: (0.035, 0.376, 0.486), dark: (0.404, 0.769, 0.831)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.035, 0.061, 0.075)),
                accentSoft: .init(light: (0.811, 0.906, 0.929), dark: (0.086, 0.229, 0.278)),
                line: .init(light: (0.782, 0.835, 0.847), dark: (0.196, 0.253, 0.282)),
                controlBorder: .init(light: (0.365, 0.455, 0.485), dark: (0.495, 0.570, 0.610))
            )
        case .softGray:
            return SurfacePaletteSpec(
                canvas: .init(light: (0.956, 0.960, 0.963), dark: (0.068, 0.073, 0.082)),
                surface: .init(light: (0.991, 0.992, 0.993), dark: (0.101, 0.108, 0.120)),
                muted: .init(light: (0.911, 0.918, 0.922), dark: (0.139, 0.149, 0.164)),
                ink: .init(light: (0.073, 0.083, 0.102), dark: (0.931, 0.936, 0.943)),
                secondaryInk: .init(light: (0.302, 0.318, 0.345), dark: (0.702, 0.718, 0.741)),
                accent: .init(light: (0.094, 0.369, 0.465), dark: (0.420, 0.733, 0.792)),
                accentForeground: .init(light: (1, 1, 1), dark: (0.047, 0.060, 0.073)),
                accentSoft: .init(light: (0.837, 0.897, 0.912), dark: (0.119, 0.219, 0.253)),
                line: .init(light: (0.803, 0.816, 0.826), dark: (0.230, 0.246, 0.269)),
                controlBorder: .init(light: (0.415, 0.440, 0.470), dark: (0.520, 0.545, 0.580))
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

        // Shallow Home-only atmosphere, never a card fill.
        static var homeAtmosphere: LinearGradient { LinearGradient(
            colors: [accentSoft.opacity(0.56), canvas.opacity(0.02)],
            startPoint: .topTrailing,
            endPoint: UnitPoint(x: 0.36, y: 0.42)
        ) }
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
