// The Web's appearance axes, as data (fidelity spec v2 §3.1–3.5): four
// Backgrounds, seven Accent SCHEMES and four Text sizes, with every colour
// copied from `apps/web/src/styles/tokens.css` at 9cbedf6. `ThemeMappingTests`
// parses that stylesheet and checks each of the 28 background × accent
// palettes against `ThemePalette.resolve`, so a Web token change cannot
// drift from the iPhone silently.

import Foundation

/// Settings › Appearance › Background — Stone / White / Mist / Night.
public enum HOneyBackground: String, Sendable, Codable, CaseIterable, Equatable {
    case stone, white, mist, night

    public var label: String {
        switch self {
        case .stone: return "Stone"
        case .white: return "White"
        case .mist: return "Mist"
        case .night: return "Night"
        }
    }

    /// Night is the one dark surface; it carries dark system chrome.
    public var isNight: Bool { self == .night }

    /// The theme-color / swatch of the surface.
    public var swatch: RGBA {
        switch self {
        case .stone: return RGBA(hex: 0xF4F6F7)
        case .white: return RGBA(hex: 0xFFFFFF)
        case .mist: return RGBA(hex: 0xEEF2F2)
        case .night: return RGBA(hex: 0x14171A)
        }
    }
}

/// Settings › Appearance › Accent — a scheme, not one colour.
public enum HOneyAccent: String, Sendable, Codable, CaseIterable, Equatable {
    case harbour, cobalt, moss, clay, plum, iris, amber

    public var label: String {
        switch self {
        case .harbour: return "Harbour"
        case .cobalt: return "Cobalt"
        case .moss: return "Moss"
        case .clay: return "Clay"
        case .plum: return "Plum"
        case .iris: return "Iris"
        case .amber: return "Amber"
        }
    }

    /// The light accent (the Web's `swatch`).
    public var swatch: RGBA {
        switch self {
        case .harbour: return RGBA(hex: 0x33667C)
        case .cobalt: return RGBA(hex: 0x3B5D9C)
        case .moss: return RGBA(hex: 0x43694B)
        case .clay: return RGBA(hex: 0x7E5340)
        case .plum: return RGBA(hex: 0x745170)
        case .iris: return RGBA(hex: 0x5E5981)
        case .amber: return RGBA(hex: 0x725B32)
        }
    }

    /// The Night lift (the Web's `night`).
    public var nightSwatch: RGBA {
        switch self {
        case .harbour: return RGBA(hex: 0x8FC2D4)
        case .cobalt: return RGBA(hex: 0x9DB9ED)
        case .moss: return RGBA(hex: 0x9FC4A5)
        case .clay: return RGBA(hex: 0xDAAE9A)
        case .plum: return RGBA(hex: 0xCFACCB)
        case .iris: return RGBA(hex: 0xB8B3DD)
        case .amber: return RGBA(hex: 0xCDB58E)
        }
    }

    /// The pale tint on light surfaces (`--accent-tint`).
    var lightTint: RGBA {
        switch self {
        case .harbour: return RGBA(hex: 0xDDE8EC)
        case .cobalt: return RGBA(hex: 0xDDE8EC) // Cobalt borrows the Harbour teal tint
        case .moss: return RGBA(hex: 0xE0E8E1)
        case .clay: return RGBA(hex: 0xEEE3DF)
        case .plum: return RGBA(hex: 0xEBE3EA)
        case .iris: return RGBA(hex: 0xE5E5EE)
        case .amber: return RGBA(hex: 0xEAE5DC)
        }
    }
}

/// Settings › Appearance › Text size — one scale on the whole ramp.
public enum HOneyTextSize: String, Sendable, Codable, CaseIterable, Equatable {
    case small, `default`, large, larger

    public var label: String {
        switch self {
        case .small: return "Small"
        case .default: return "Default"
        case .large: return "Large"
        case .larger: return "Larger"
        }
    }

    public var scale: Double {
        switch self {
        case .small: return 0.92
        case .default: return 1
        case .large: return 1.1
        case .larger: return 1.22
        }
    }
}

/// A colour as the stylesheet states it: sRGB components + alpha.
public struct RGBA: Sendable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// `#rgb`, `#rrggbb`, `rgb(r, g, b)` or `rgba(r, g, b, a)` — the forms tokens.css uses.
    public init?(css: String) {
        let s = css.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasPrefix("#") {
            var hex = String(s.dropFirst())
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
            self.init(hex: value)
            return
        }
        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")"), s.hasPrefix("rgb") else { return nil }
        let parts = s[s.index(after: open)..<close].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4, let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) else { return nil }
        let a = parts.count == 4 ? Double(parts[3]) ?? 1 : 1
        self.init(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    /// `mix(with:)` in sRGB, the way `color-mix(in srgb, A p%, B)` blends.
    public func mixed(with other: RGBA, amount: Double) -> RGBA {
        RGBA(
            red: red * amount + other.red * (1 - amount),
            green: green * amount + other.green * (1 - amount),
            blue: blue * amount + other.blue * (1 - amount),
            alpha: alpha * amount + other.alpha * (1 - amount)
        )
    }

    public func withAlpha(_ a: Double) -> RGBA {
        RGBA(red: red, green: green, blue: blue, alpha: a)
    }

    /// Close enough to be the same stylesheet value (rounding across hex/rgba).
    public func approximatelyEquals(_ other: RGBA, tolerance: Double = 0.003) -> Bool {
        abs(red - other.red) <= tolerance && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance && abs(alpha - other.alpha) <= tolerance
    }
}

/// Every colour token the Web derives from one Background × Accent pair.
public struct ThemePalette: Sendable, Equatable {
    public var background: HOneyBackground
    public var accentChoice: HOneyAccent

    public var surface: RGBA
    public var surfaceSolid: RGBA
    public var cell: RGBA
    public var card: RGBA
    public var soft: RGBA
    public var ink: RGBA
    public var ink2: RGBA
    public var ink3: RGBA
    public var muted: RGBA
    public var line: RGBA
    public var wash: RGBA
    public var accent: RGBA
    public var accentTint: RGBA
    public var onAccent: RGBA
    public var accent2: RGBA
    public var glacier: RGBA
    public var danger: RGBA
    public var ok: RGBA
    /// `--warn` — warnings are orange, never the accent (Gary 2026-09-03).
    public var warn: RGBA
    /// The `--shadow` colour (its geometry lives with the component).
    public var shadow: RGBA
    /// `--shadow-card`'s larger layer (0 8px 22px): a card that sits ON the surface.
    public var shadowCard: RGBA
    /// `--shadow-field` (0 1px 2px): an unfilled field or pill lifts off the page (Gary 2026-09-04).
    public var shadowField: RGBA

    /// The Web cascade: base (Stone + Harbour) → surface block → accent block
    /// → the night+accent pair, exactly the order tokens.css declares them.
    public static func resolve(background: HOneyBackground, accent: HOneyAccent) -> ThemePalette {
        var p = ThemePalette(
            background: background,
            accentChoice: accent,
            surface: RGBA(hex: 0xF4F6F7),
            surfaceSolid: RGBA(hex: 0xFBFCFC),
            cell: RGBA(hex: 0xFFFFFF),
            card: RGBA(hex: 0xFFFFFF, alpha: 0.72),
            soft: RGBA(hex: 0x232B31, alpha: 0.05),
            ink: RGBA(hex: 0x232B31),
            ink2: RGBA(hex: 0x5C6770),
            ink3: RGBA(hex: 0x667079),
            muted: RGBA(hex: 0x5C6770),
            line: RGBA(hex: 0x232B31, alpha: 0.14),
            wash: RGBA(hex: 0x232B31, alpha: 0.05),
            accent: RGBA(hex: 0x33667C),
            accentTint: RGBA(hex: 0xDDE8EC),
            onAccent: RGBA(hex: 0xFFFFFF),
            accent2: RGBA(hex: 0x33667C),
            glacier: RGBA(hex: 0xDDE8EC),
            danger: RGBA(hex: 0xB53844),
            ok: RGBA(hex: 0x2B7355),
            warn: RGBA(hex: 0xB0611A),
            shadow: RGBA(hex: 0x161E22, alpha: 0.1),
            shadowCard: RGBA(hex: 0x161E22, alpha: 0.07),
            shadowField: RGBA(hex: 0x161E22, alpha: 0.06)
        )
        switch background {
        case .stone:
            break
        case .white:
            p.surface = RGBA(hex: 0xFFFFFF)
            p.surfaceSolid = RGBA(hex: 0xFFFFFF)
            p.card = RGBA(hex: 0xFFFFFF)
            p.soft = RGBA(hex: 0xF2F4F5)
            p.line = RGBA(hex: 0x181E22, alpha: 0.13)
        case .mist:
            p.surface = RGBA(hex: 0xEEF2F2)
            p.surfaceSolid = RGBA(hex: 0xF7FAF9)
            p.card = RGBA(hex: 0xFFFFFF, alpha: 0.7)
            p.soft = RGBA(hex: 0x1F322F, alpha: 0.05)
            p.line = RGBA(hex: 0x1C2826, alpha: 0.14)
        case .night:
            p.surface = RGBA(hex: 0x14171A)
            p.surfaceSolid = RGBA(hex: 0x1D2125)
            p.cell = RGBA(hex: 0x1D2125)
            p.card = RGBA(hex: 0xFFFFFF, alpha: 0.045)
            p.soft = RGBA(hex: 0xFFFFFF, alpha: 0.06)
            p.ink = RGBA(hex: 0xE9EDEF)
            p.ink2 = RGBA(hex: 0xA6AFB5)
            p.ink3 = RGBA(hex: 0x8B949B)
            p.muted = RGBA(hex: 0xA6AFB5)
            p.line = RGBA(hex: 0xE9EDEF, alpha: 0.16)
            p.wash = RGBA(hex: 0xFFFFFF, alpha: 0.06)
            p.accent = RGBA(hex: 0x8FC2D4)
            p.accentTint = RGBA(hex: 0x8FC2D4, alpha: 0.16)
            p.onAccent = RGBA(hex: 0x10181C)
            p.glacier = RGBA(hex: 0x8FC2D4, alpha: 0.16)
            p.danger = RGBA(hex: 0xF2919A)
            p.ok = RGBA(hex: 0x83C9A8)
            p.warn = RGBA(hex: 0xF0B072)
            p.shadow = RGBA(hex: 0x000000, alpha: 0.4)
            p.shadowCard = RGBA(hex: 0x000000, alpha: 0.35)
            p.shadowField = RGBA(hex: 0x000000, alpha: 0.35)
        }
        // The accent block is written for light surfaces; the night pair follows.
        if accent != .harbour {
            p.accent = accent.swatch
            p.accentTint = accent.lightTint
            p.glacier = accent.lightTint
            if accent == .cobalt { p.accent2 = RGBA(hex: 0x33667C) }
            if background.isNight {
                p.accent = accent.nightSwatch
                p.accentTint = accent == .cobalt ? RGBA(hex: 0x8FC2D4, alpha: 0.16) : accent.nightSwatch.withAlpha(0.16)
                p.glacier = p.accentTint
                if accent == .cobalt { p.accent2 = RGBA(hex: 0x8FC2D4) }
            }
        }
        // `--accent-2: var(--accent)` unless a scheme pairs two hues.
        if accent != .cobalt { p.accent2 = p.accent }
        return p
    }

    // Derived mixes the stylesheet computes with color-mix(); the component
    // that uses each one names the source rule.

    /// `color-mix(in srgb, var(--ink) 28%, transparent)` — the lesson-card frame and the Home brand rule.
    public var frame: RGBA { ink.withAlpha(0.28) }
    /// `color-mix(in srgb, var(--accent-2) 22%, transparent)` — the Now/Next progress wash.
    public var progressWash: RGBA { accent2.withAlpha(0.22) }
    /// `color-mix(in srgb, var(--accent) 7%, transparent)` — Day canvas break bands.
    public var breakBand: RGBA { accent.withAlpha(0.07) }
    /// `color-mix(in srgb, var(--line) 55%, transparent)` — Day canvas gridlines.
    public var gridline: RGBA { line.withAlpha(line.alpha * 0.55) }
    /// `color-mix(in srgb, var(--accent-tint) 45%, transparent)` — Week today column.
    public var todayColumn: RGBA { accentTint.withAlpha(accentTint.alpha * 0.45) }
    /// `color-mix(in srgb, var(--ink) 86%, var(--muted))` — banner ink / field labels.
    public var inkSoft: RGBA { ink.mixed(with: muted, amount: 0.86) }
}
