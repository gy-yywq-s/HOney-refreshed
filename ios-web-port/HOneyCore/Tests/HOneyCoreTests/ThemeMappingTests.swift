// The Web stylesheet is the authority for every colour (fidelity spec v2
// §3.1–3.3). This test resolves `apps/web/src/styles/tokens.css` the way a
// browser would for each Background × Accent pair and checks the Swift
// palette against it, token by token.

import XCTest
@testable import HOneyCore

final class ThemeMappingTests: XCTestCase {
    /// `:root[...]` selector → declarations, in source order.
    private struct Block {
        let selector: String
        let declarations: [(String, String)]
    }

    private static func repoRoot() -> URL {
        // .../ios-web-port/HOneyCore/Tests/HOneyCoreTests/ThemeMappingTests.swift → repo root
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    private static func loadBlocks() throws -> [Block] {
        let url = repoRoot().appendingPathComponent("apps/web/src/styles/tokens.css")
        var css = try String(contentsOf: url, encoding: .utf8)
        // Strip comments.
        while let open = css.range(of: "/*"), let close = css.range(of: "*/", range: open.upperBound..<css.endIndex) {
            css.removeSubrange(open.lowerBound..<close.upperBound)
        }
        var blocks: [Block] = []
        var rest = Substring(css)
        while let brace = rest.firstIndex(of: "{"), let end = rest[brace...].firstIndex(of: "}") {
            let selector = rest[..<brace].trimmingCharacters(in: .whitespacesAndNewlines)
            let body = rest[rest.index(after: brace)..<end]
            var decls: [(String, String)] = []
            for line in body.split(separator: ";") {
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2, parts[0].hasPrefix("--") { decls.append((parts[0], parts[1])) }
            }
            blocks.append(Block(selector: selector, declarations: decls))
            rest = rest[rest.index(after: end)...]
        }
        return blocks
    }

    /// The cascade for one pair: base, then surface, then accent, then night+accent.
    private static func resolve(_ blocks: [Block], background: HOneyBackground, accent: HOneyAccent) -> [String: String] {
        var vars: [String: String] = [:]
        func apply(_ selector: String) {
            for block in blocks where block.selector == selector {
                for (k, v) in block.declarations { vars[k] = v }
            }
        }
        apply(":root")
        if background != .stone { apply(":root[data-surface=\"\(background.rawValue)\"]") }
        if accent != .harbour { apply(":root[data-accent=\"\(accent.rawValue)\"]") }
        if background == .night, accent != .harbour { apply(":root[data-surface=\"night\"][data-accent=\"\(accent.rawValue)\"]") }
        // var() indirection (only `--accent-2: var(--accent)` and `--reading/--display` use it).
        for (k, v) in vars where v.hasPrefix("var(") {
            let name = v.dropFirst(4).dropLast().trimmingCharacters(in: .whitespaces)
            if let target = vars[name] { vars[k] = target }
        }
        return vars
    }

    private func color(_ vars: [String: String], _ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> RGBA {
        let raw = try XCTUnwrap(vars[name], "\(name) missing", file: file, line: line)
        let parsed = raw.replacingOccurrences(of: "rgb(0 0 0 / 0.12)", with: "rgba(0,0,0,0.12)")
        return try XCTUnwrap(RGBA(css: parsed), "\(name) = \(raw) not parseable", file: file, line: line)
    }

    private func shadowColor(_ vars: [String: String]) throws -> RGBA {
        // `0 14px 40px rgba(22, 30, 34, 0.1)` → the colour part.
        let raw = try XCTUnwrap(vars["--shadow"])
        let start = try XCTUnwrap(raw.range(of: "rgba("))
        return try XCTUnwrap(RGBA(css: String(raw[start.lowerBound...])))
    }

    func testEveryBackgroundAccentPairMatchesTokensCSS() throws {
        let blocks = try Self.loadBlocks()
        XCTAssertGreaterThan(blocks.count, 10, "tokens.css parsed")
        for background in HOneyBackground.allCases {
            for accent in HOneyAccent.allCases {
                let vars = Self.resolve(blocks, background: background, accent: accent)
                let p = ThemePalette.resolve(background: background, accent: accent)
                let label = "\(background.rawValue)/\(accent.rawValue)"
                func check(_ name: String, _ value: RGBA) throws {
                    let expected = try color(vars, name)
                    XCTAssertTrue(value.approximatelyEquals(expected), "\(label) \(name): swift \(value) vs css \(expected) (\(vars[name] ?? "?"))")
                }
                try check("--surface", p.surface)
                try check("--surface-solid", p.surfaceSolid)
                try check("--cell", p.cell)
                try check("--card", p.card)
                try check("--soft", p.soft)
                try check("--ink", p.ink)
                try check("--ink-2", p.ink2)
                try check("--ink-3", p.ink3)
                try check("--muted", p.muted)
                try check("--line", p.line)
                try check("--wash", p.wash)
                try check("--accent", p.accent)
                try check("--accent-tint", p.accentTint)
                try check("--on-accent", p.onAccent)
                try check("--accent-2", p.accent2)
                try check("--glacier", p.glacier)
                try check("--danger", p.danger)
                try check("--ok", p.ok)
                let shadow = try shadowColor(vars)
                XCTAssertTrue(p.shadow.approximatelyEquals(shadow), "\(label) --shadow: \(p.shadow) vs \(shadow)")
            }
        }
    }

    func testSwatchesMatchThemeTS() throws {
        // lib/theme.ts ACCENT_OPTIONS swatch/night columns and THEME_COLORS.
        let url = Self.repoRoot().appendingPathComponent("apps/web/src/lib/theme.ts")
        let ts = try String(contentsOf: url, encoding: .utf8)
        for accent in HOneyAccent.allCases {
            let needle = "value: \"\(accent.rawValue)\", label: \"\(accent.label)\", swatch: \""
            let range = try XCTUnwrap(ts.range(of: needle), "\(accent.rawValue) in theme.ts")
            let after = ts[range.upperBound...]
            let swatch = String(after.prefix(7))
            let nightStart = try XCTUnwrap(after.range(of: "night: \""))
            let night = String(after[nightStart.upperBound...].prefix(7))
            XCTAssertEqual(RGBA(css: swatch), accent.swatch, accent.rawValue)
            XCTAssertEqual(RGBA(css: night), accent.nightSwatch, accent.rawValue)
        }
        for background in HOneyBackground.allCases {
            let needle = "\(background.rawValue): \""
            let range = try XCTUnwrap(ts.range(of: needle))
            XCTAssertEqual(RGBA(css: String(ts[range.upperBound...].prefix(7))), background.swatch, background.rawValue)
        }
    }

    func testTextScalesMatchTokensCSS() throws {
        let blocks = try Self.loadBlocks()
        func scale(_ size: HOneyTextSize) -> Double? {
            let selector = ":root[data-textsize=\"\(size.rawValue)\"]"
            return blocks.first { $0.selector == selector }?.declarations.first { $0.0 == "--text-scale" }.flatMap { Double($0.1) }
        }
        XCTAssertEqual(scale(.small), 0.92)
        XCTAssertEqual(scale(.large), 1.1)
        XCTAssertEqual(scale(.larger), 1.22)
        XCTAssertEqual(HOneyTextSize.small.scale, 0.92)
        XCTAssertEqual(HOneyTextSize.large.scale, 1.1)
        XCTAssertEqual(HOneyTextSize.larger.scale, 1.22)
        XCTAssertEqual(HOneyTextSize.default.scale, 1)
    }

    func testPreferencesFollowTheWebBootRule() {
        let defaults = UserDefaults(suiteName: "ThemeMappingTests.\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        XCTAssertNil(prefs.background)
        XCTAssertEqual(prefs.effectiveBackground(systemPrefersDark: false), .stone)
        XCTAssertEqual(prefs.effectiveBackground(systemPrefersDark: true), .night)
        prefs.background = .mist
        XCTAssertEqual(prefs.effectiveBackground(systemPrefersDark: true), .mist, "a saved choice wins")
        XCTAssertEqual(prefs.accent, .harbour)
        prefs.accent = .cobalt
        XCTAssertEqual(prefs.accent, .cobalt)
        XCTAssertEqual(prefs.textSize, .default)
        prefs.textSize = .larger
        XCTAssertEqual(prefs.textSize, .larger)
        XCTAssertEqual(defaults.string(forKey: "honey.theme.surface"), "mist", "the Web's own key")
    }

    func testCobaltPairsBlueActionsWithTheHarbourCompanion() {
        let light = ThemePalette.resolve(background: .stone, accent: .cobalt)
        XCTAssertEqual(light.accent, RGBA(hex: 0x3B5D9C))
        XCTAssertEqual(light.accent2, RGBA(hex: 0x33667C))
        XCTAssertNotEqual(light.accent, light.accent2)
        let night = ThemePalette.resolve(background: .night, accent: .cobalt)
        XCTAssertEqual(night.accent, RGBA(hex: 0x9DB9ED))
        XCTAssertEqual(night.accent2, RGBA(hex: 0x8FC2D4))
        let harbour = ThemePalette.resolve(background: .white, accent: .harbour)
        XCTAssertEqual(harbour.accent, harbour.accent2, "one hue unless a scheme pairs two")
    }
}
