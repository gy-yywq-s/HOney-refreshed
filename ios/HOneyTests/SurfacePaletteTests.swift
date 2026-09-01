//
//  SurfacePaletteTests.swift
//  HOneyTests — persisted selection and light/dark token contrast.
//

import XCTest
@testable import HOney

final class SurfacePaletteTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SurfacePalette.storageKey)
        super.tearDown()
    }

    func testSelectionPersistsByRawValue() {
        UserDefaults.standard.set(SurfacePalette.coolMist.rawValue, forKey: SurfacePalette.storageKey)
        XCTAssertEqual(SurfacePalette.current, .coolMist)
    }

    func testMissingOrInvalidSelectionFallsBackToPaper() {
        UserDefaults.standard.removeObject(forKey: SurfacePalette.storageKey)
        XCTAssertEqual(SurfacePalette.current, .paper)
        UserDefaults.standard.set("not-a-palette", forKey: SurfacePalette.storageKey)
        XCTAssertEqual(SurfacePalette.current, .paper)
    }

    func testEveryPalettePassesCoreTextAndAccentContrast() {
        for palette in SurfacePalette.allCases {
            let spec = palette.spec
            XCTAssertGreaterThanOrEqual(contrast(spec.ink.light, spec.canvas.light), 4.5, palette.title + " light ink")
            XCTAssertGreaterThanOrEqual(contrast(spec.secondaryInk.light, spec.canvas.light), 4.5, palette.title + " light secondary")
            XCTAssertGreaterThanOrEqual(contrast(spec.accentForeground.light, spec.accent.light), 4.5, palette.title + " light accent")
            XCTAssertGreaterThanOrEqual(contrast(spec.ink.dark, spec.canvas.dark), 4.5, palette.title + " dark ink")
            XCTAssertGreaterThanOrEqual(contrast(spec.secondaryInk.dark, spec.canvas.dark), 4.5, palette.title + " dark secondary")
            XCTAssertGreaterThanOrEqual(contrast(spec.accentForeground.dark, spec.accent.dark), 4.5, palette.title + " dark accent")
            XCTAssertGreaterThanOrEqual(contrast(spec.controlBorder.light, spec.canvas.light), 3.0, palette.title + " light border/canvas")
            XCTAssertGreaterThanOrEqual(contrast(spec.controlBorder.light, spec.surface.light), 3.0, palette.title + " light border/surface")
            XCTAssertGreaterThanOrEqual(contrast(spec.controlBorder.dark, spec.canvas.dark), 3.0, palette.title + " dark border/canvas")
            XCTAssertGreaterThanOrEqual(contrast(spec.controlBorder.dark, spec.surface.dark), 3.0, palette.title + " dark border/surface")
            XCTAssertGreaterThanOrEqual(contrast(spec.ink.light, spec.surface.light), 4.5, palette.title + " light wordmark")
            XCTAssertGreaterThanOrEqual(contrast(spec.ink.dark, spec.surface.dark), 4.5, palette.title + " dark wordmark")
            XCTAssertGreaterThanOrEqual(contrast(spec.accent.light, spec.accentSoft.light), 4.5, palette.title + " light accent/soft")
            XCTAssertGreaterThanOrEqual(contrast(spec.accent.dark, spec.accentSoft.dark), 4.5, palette.title + " dark accent/soft")
            assertStatusContrast(palette: palette, spec: spec, foreground: AppTheme.Colors.successRGB, name: "success")
            assertStatusContrast(palette: palette, spec: spec, foreground: AppTheme.Colors.warningRGB, name: "warning")
            assertStatusContrast(palette: palette, spec: spec, foreground: AppTheme.Colors.errorRGB, name: "error")
        }
    }

    private func assertStatusContrast(
        palette: SurfacePalette,
        spec: SurfacePaletteSpec,
        foreground: AdaptiveRGB,
        name: String
    ) {
        let lightBackground = composite(foreground.light, over: spec.canvas.light, alpha: 0.10)
        let darkBackground = composite(foreground.dark, over: spec.canvas.dark, alpha: 0.10)
        XCTAssertGreaterThanOrEqual(contrast(foreground.light, lightBackground), 4.5, palette.title + " light " + name)
        XCTAssertGreaterThanOrEqual(contrast(foreground.dark, darkBackground), 4.5, palette.title + " dark " + name)
    }

    private func composite(_ foreground: RGB, over background: RGB, alpha: Double) -> RGB {
        let inverse = 1 - alpha
        return (
            CGFloat(Double(foreground.0) * alpha + Double(background.0) * inverse),
            CGFloat(Double(foreground.1) * alpha + Double(background.1) * inverse),
            CGFloat(Double(foreground.2) * alpha + Double(background.2) * inverse)
        )
    }

    private func contrast(_ first: RGB, _ second: RGB) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ value: RGB) -> Double {
        let channels = [value.0, value.1, value.2].map { channel -> Double in
            let c = Double(channel)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
