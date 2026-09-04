//
//  RegionFinderTests.swift
//  The pure half: strings and rectangles in, regions out. No Vision.
//

import XCTest
@testable import SanitationLab

final class RegionFinderTests: XCTestCase {
    private let size = CGSize(width: 1000, height: 600)

    private func line(_ s: String, x: CGFloat, y: CGFloat, w: CGFloat = 300, h: CGFloat = 30) -> TextLine {
        TextLine(string: s, rect: CGRect(x: x, y: y, width: w, height: h))
    }

    func testLabelledValueMasksOnlyTheValue() {
        let input = RegionFinderInput(faces: [], codes: [], lines: [line("Student ID: 20230188", x: 100, y: 100, w: 400)], imageSize: size)
        let result = SensitiveRegionFinder.find(input, credentialLike: true)
        XCTAssertEqual(result.regions.count, 1)
        let r = result.regions[0]
        XCTAssertEqual(r.kind, .number)
        XCTAssertEqual(r.value, "20230188")
        XCTAssertFalse(result.labelWithoutValue)
        // The label's own characters ("Student ID: ") stay outside the mask (linear estimate: 12 of 20 chars).
        XCTAssertGreaterThan(r.rect.minX, 100 + 400 * 0.5)
        XCTAssertEqual(result.labelsSeen, ["Student ID"])
    }

    func testChineseLabelOnItsOwnLineFindsTheValueToTheRight() {
        let lines = [line("学号：", x: 100, y: 100, w: 80), line("20230188", x: 200, y: 102, w: 160), line("姓名：张伟", x: 100, y: 50, w: 150)]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(result.regions.map(\.value), ["20230188"])
        XCTAssertEqual(result.regions[0].detail, "label-adjacent")
        XCTAssertFalse(result.labelWithoutValue)
    }

    func testLabelWithNoValueAnywhereIsReported() {
        let lines = [line("Student No.", x: 100, y: 100), line("Zhang Wei", x: 100, y: 50)]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertTrue(result.labelWithoutValue)
        XCTAssertTrue(result.regions.isEmpty)
    }

    func testNamesAndContextAreNeverRegions() {
        let lines = [line("Zhang Wei", x: 100, y: 50), line("Grade 11 · Class 3", x: 100, y: 90), line("Valid until 07/2027", x: 100, y: 130), line("HUAYAO PUDONG SCHOOL", x: 100, y: 10)]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertTrue(result.regions.isEmpty)
        XCTAssertTrue(result.labelsSeen.isEmpty)
    }

    func testStandaloneLongIdsOnlyWhenCredentialLike() {
        let lines = [line("LIB-0048821", x: 100, y: 50), line("ISBN 978-7-5320-1234-5", x: 100, y: 90)]
        let onCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(onCard.regions.map(\.value), ["LIB-0048821", "978-7-5320-1234-5"])
        let notCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: false)
        XCTAssertTrue(notCard.regions.isEmpty, "a long number on a non-credential is left alone")
    }

    func testFacesBlurOnlyOnCredentials() {
        let face = CGRect(x: 40, y: 130, width: 210, height: 270)
        let asCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [face], codes: [], lines: [], imageSize: size), credentialLike: true)
        XCTAssertEqual(asCard.regions.map(\.kind), [.portrait])
        XCTAssertTrue(asCard.regions[0].rect.contains(face))
        let notCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [face], codes: [], lines: [], imageSize: size), credentialLike: false)
        XCTAssertTrue(notCard.regions.isEmpty)
    }

    func testCodesAreAStrongSignalEvenWithoutTheClassifier() {
        let code = CodeDetection(rect: CGRect(x: 700, y: 360, width: 150, height: 150), symbology: "VNBarcodeSymbologyQR", payload: "HYPD-20230188")
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [code], lines: [], imageSize: size), credentialLike: false)
        XCTAssertTrue(result.strongSignal)
        XCTAssertEqual(result.regions.map(\.kind), [.code])
        XCTAssertTrue(result.regions[0].rect.contains(code.rect))
    }

    func testIdLikeTokens() {
        XCTAssertTrue(SensitiveRegionFinder.isIdLike("20230188"))
        XCTAssertTrue(SensitiveRegionFinder.isIdLike("T-10442"))
        XCTAssertTrue(SensitiveRegionFinder.isIdLike("LIB0048821"))
        XCTAssertFalse(SensitiveRegionFinder.isIdLike("2027"))
        XCTAssertFalse(SensitiveRegionFinder.isIdLike("Class-3"))
        XCTAssertFalse(SensitiveRegionFinder.isIdLike("Grade11"))
    }

    func testPaddingStaysInsideTheImage() {
        let padded = SensitiveRegionFinder.pad(CGRect(x: 0, y: 0, width: 100, height: 100), by: 0.5, in: CGRect(origin: .zero, size: size))
        XCTAssertEqual(padded.minX, 0)
        XCTAssertEqual(padded.minY, 0)
        XCTAssertEqual(padded.maxX, 150)
    }
}
