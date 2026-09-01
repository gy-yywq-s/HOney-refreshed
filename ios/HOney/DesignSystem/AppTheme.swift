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

        static let canvas = adaptive(light: (0.973, 0.969, 0.953), dark: (0.071, 0.082, 0.098))
        static let surface = adaptive(light: (0.995, 0.992, 0.980), dark: (0.105, 0.118, 0.137))
        static let surfaceMuted = adaptive(light: (0.941, 0.941, 0.918), dark: (0.137, 0.153, 0.173))
        static let ink = adaptive(light: (0.075, 0.102, 0.153), dark: (0.925, 0.937, 0.945))
        static let inkSecondary = adaptive(light: (0.300, 0.326, 0.357), dark: (0.690, 0.718, 0.745))
        static let accent = adaptive(light: (0.102, 0.421, 0.486), dark: (0.365, 0.718, 0.765))
        static let accentForeground = adaptive(light: (1.0, 1.0, 1.0), dark: (0.055, 0.075, 0.090))
        static let accentSoft = adaptive(light: (0.855, 0.918, 0.914), dark: (0.118, 0.235, 0.255))
        static let line = adaptive(light: (0.824, 0.831, 0.812), dark: (0.235, 0.255, 0.278))
        static let success = adaptive(light: (0.133, 0.475, 0.286), dark: (0.345, 0.745, 0.482))
        static let warning = adaptive(light: (0.500, 0.245, 0.020), dark: (0.933, 0.651, 0.286))
        static let error = adaptive(light: (0.710, 0.153, 0.192), dark: (0.949, 0.404, 0.435))

        // Compatibility names used by feature views.
        static let navy = ink
        static let ocean = accent
        static let mist = surfaceMuted
        static let background = canvas

        // Shallow Home-only atmosphere, never a card fill.
        static let homeAtmosphere = LinearGradient(
            colors: [accentSoft.opacity(0.56), canvas.opacity(0.02)],
            startPoint: .topTrailing,
            endPoint: UnitPoint(x: 0.36, y: 0.42)
        )
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
