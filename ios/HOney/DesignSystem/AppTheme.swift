//
//  AppTheme.swift
//  HOney
//
//  Edit this file first when tuning the app's visual style.
//  Ported verbatim from the legacy design system (reference/legacy-ios).
//

import SwiftUI

enum AppTheme {
    enum Colors {
        static let navy = Color(red: 0.07, green: 0.19, blue: 0.36)
        static let ocean = Color(red: 0.23, green: 0.69, blue: 0.82)
        static let sky = Color(red: 0.72, green: 0.88, blue: 1.0)
        static let mist = Color(red: 0.93, green: 0.97, blue: 1.0)
        static let mist_dark = Color(red: 0.09, green: 0.09, blue: 0.11)
        static let line = Color(red: 0.80, green: 0.88, blue: 0.95)
        static let page = Color.white
        static let softControl = Color(red: 0.95, green: 0.95, blue: 0.97)
        static let success = Color(red: 0.17, green: 0.56, blue: 0.30)
        static let warning = Color(red: 0.86, green: 0.42, blue: 0.14)
        static let error = Color(red: 0.86, green: 0.18, blue: 0.22)

        static let background = LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.98, blue: 1.0),
                Color(red: 0.84, green: 0.93, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 18
        static let xxLarge: CGFloat = 24
        static let pageHorizontal: CGFloat = 18
        static let loginHorizontal: CGFloat = 28
    }

    enum Radius {
        static let small: CGFloat = 7
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let loginMark: CGFloat = 34
    }

    enum Typography {
        static let loginTitleSize: CGFloat = 38
        static let loginFieldSize: CGFloat = 17
        static let loginButtonSize: CGFloat = 17
        static let loginMarkSize: CGFloat = 24
        static let loginControlHeight: CGFloat = 48
        static let scheduleHeaderSize: CGFloat = 23
        static let sectionTitleSize: CGFloat = 20

        // Change these first when tuning the app's font personality.
        static let titleDesign: Font.Design = .rounded
        static let bodyDesign: Font.Design = .default
        static let brandDesign: Font.Design = .serif
        static let numberDesign: Font.Design = .default

        static var loginTitle: Font { .system(size: loginTitleSize, weight: .semibold, design: brandDesign) }
        static var loginMark: Font { .system(size: loginMarkSize, weight: .semibold, design: brandDesign) }
        static var loginField: Font { .system(size: loginFieldSize, weight: .regular, design: bodyDesign) }
        static var loginButton: Font { .system(size: loginButtonSize, weight: .semibold, design: bodyDesign) }

        static var largeTitle: Font { .system(.title, design: titleDesign, weight: .bold) }
        static var screenTitle: Font { .system(.title2, design: titleDesign, weight: .bold) }
        static var sectionTitle: Font { .system(size: sectionTitleSize, weight: .bold, design: titleDesign) }
        static var cardTitle: Font { .system(.headline, design: titleDesign, weight: .bold) }
        static var headline: Font { .system(.headline, design: bodyDesign, weight: .regular) }
        static var headlineSemibold: Font { .system(.headline, design: bodyDesign, weight: .semibold) }
        static var headlineBold: Font { .system(.headline, design: bodyDesign, weight: .bold) }
        static var subheadline: Font { .system(.subheadline, design: bodyDesign, weight: .regular) }
        static var subheadlineMedium: Font { .system(.subheadline, design: bodyDesign, weight: .medium) }
        static var subheadlineSemibold: Font { .system(.subheadline, design: bodyDesign, weight: .semibold) }
        static var subheadlineBold: Font { .system(.subheadline, design: bodyDesign, weight: .bold) }
        static var caption: Font { .system(.caption, design: bodyDesign, weight: .regular) }
        static var captionMedium: Font { .system(.caption, design: bodyDesign, weight: .medium) }
        static var captionSemibold: Font { .system(.caption, design: bodyDesign, weight: .semibold) }
        static var captionBold: Font { .system(.caption, design: bodyDesign, weight: .bold) }
        static var caption2: Font { .system(.caption2, design: bodyDesign, weight: .regular) }
        static var caption2Medium: Font { .system(.caption2, design: bodyDesign, weight: .medium) }
        static var caption2Semibold: Font { .system(.caption2, design: bodyDesign, weight: .semibold) }
        static var caption2Bold: Font { .system(.caption2, design: bodyDesign, weight: .bold) }
        static var footnote: Font { .system(.footnote, design: bodyDesign, weight: .regular) }
        static var footnoteMedium: Font { .system(.footnote, design: bodyDesign, weight: .medium) }
        static var gateChoice: Font { .system(.title3, design: titleDesign, weight: .bold) }
        static var title3: Font { .system(.title3, design: bodyDesign, weight: .regular) }
        static var iconTitle: Font { .system(.title, design: bodyDesign, weight: .regular) }
        static var preferenceCardTitle: Font { .system(.headline, design: titleDesign, weight: .bold) }
        static var scheduleHeader: Font { .system(size: scheduleHeaderSize, weight: .bold, design: titleDesign) }
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

    enum Shadow {
        static let cardColor = Colors.navy.opacity(0.07)
        static let cardRadius: CGFloat = 18
        static let cardY: CGFloat = 10
    }

    enum Motion {
        static var fast: Animation? {
            AppConfig.enableAnimations ? .snappy(duration: 0.18) : nil
        }

        static var standard: Animation? {
            AppConfig.enableAnimations ? .snappy(duration: 0.24, extraBounce: 0.04) : nil
        }
    }
}

typealias Palette = AppTheme.Colors
