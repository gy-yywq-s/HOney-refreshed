//
//  Theme.swift
//  HOney — design tokens as a Swift Theme (Band: DesignSystem).
//  Derived from design/tokens/tokens.json. Cool-blue, minimal, light + dark.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Color

    enum Palette {
        static let background = adaptive(light: 0xF2F7FC, dark: 0x0C1526)
        static let surface = adaptive(light: 0xFFFFFF, dark: 0x16233B)
        static let textPrimary = adaptive(light: 0x17294B, dark: 0xEAF2FB)
        static let textSecondary = adaptive(light: 0x46608A, dark: 0xA3B8D4)
        static let accent = adaptive(light: 0x1B6BC4, dark: 0x63A9F2)
        static let accentSoft = adaptive(light: 0xDCEBFA, dark: 0x1D3A5F)
        static let success = adaptive(light: 0x177A50, dark: 0x4FC792)
        static let warning = adaptive(light: 0x8A5A00, dark: 0xE9AC55)
        static let danger = adaptive(light: 0xC0362C, dark: 0xF08479)
        static let line = adaptive(light: 0xD8E3F0, dark: 0x27395A)

        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
            })
        }
    }

    // MARK: - Typography

    enum Typography {
        static let display = Font.system(size: 34, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)

        /// Brand wordmark font — a clean, non-serif system face. A generated
        /// wordmark asset replaces this later.
        static func wordmark(size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
    }

    // MARK: - Spacing (4-pt base)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Motion

    enum Motion {
        static let fast: Double = 0.12
        static let standard: Double = 0.24
        static let interactive: Animation = .spring(response: 0.35, dampingFraction: 0.9)
    }
}

// MARK: - Hex helper

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
