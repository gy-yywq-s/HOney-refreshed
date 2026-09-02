// Geometry tokens (tokens.css at 9cbedf6): the spacing ladder, the radii
// and the one page inset. Colours and type live in Theme.swift /
// Typography.swift and come from the environment, never from here.

import SwiftUI

/// The Web's spacing ladder, in points: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 44.
enum HSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x7: CGFloat = 32
    static let x8: CGFloat = 44
    /// One page inset on phones (`--page-x`).
    static let pageX: CGFloat = 20
}

enum HRadius {
    /// `--radius-card`
    static let card: CGFloat = 16
    /// `--radius-control`
    static let control: CGFloat = 14
    /// `--radius-field`
    static let field: CGFloat = 12
    /// `.card--hero`, the Day canvas
    static let hero: CGFloat = 18
    /// `.modal`
    static let modal: CGFloat = 20
    /// Genuine choice pills
    static let pill: CGFloat = 99
}

/// Minimum hit sizes the Web keeps everywhere (44) and its quiet controls (36/38).
enum HSize {
    static let control: CGFloat = 44
    static let smallControl: CGFloat = 36
    static let reaction: CGFloat = 38
    static let row: CGFloat = 56
    static let icon: CGFloat = 20
    static let tabIcon: CGFloat = 21
}
