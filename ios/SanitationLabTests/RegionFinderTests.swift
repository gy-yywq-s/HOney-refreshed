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

    func testLabelledPersonalDetailsAreHiddenButNameAndSchoolStay() {
        let lines = [
            line("Name: Zhang Wei", x: 100, y: 20),
            line("HUAYAO PUDONG SCHOOL", x: 100, y: 55),
            line("Address: 221B Baker Street", x: 100, y: 100, w: 500),
            line("Date of birth: 2008-04-03", x: 100, y: 140, w: 500),
            line("Sex: F", x: 100, y: 180),
            line("Nationality: Chinese", x: 100, y: 220),
            line("Phone: 138 0013 8000", x: 100, y: 260),
            line("Email: student@example.com", x: 100, y: 300, w: 500),
            line("Blood type: O+", x: 100, y: 340),
        ]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(result.regions.filter { $0.kind == .personalText }.count, 7)
        XCTAssertFalse(result.regions.contains { $0.value?.contains("Zhang Wei") == true })
        XCTAssertFalse(result.regions.contains { $0.value?.contains("HUAYAO") == true })
        XCTAssertFalse(result.labelWithoutValue)
    }

    func testAddressOnFollowingLinesIsHidden() {
        let lines = [
            line("Residential address:", x: 100, y: 100, w: 220),
            line("221B Baker Street", x: 340, y: 102, w: 260),
            line("London NW1 6XE", x: 340, y: 136, w: 230),
            line("Valid until: 2030-04", x: 100, y: 180),
        ]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(result.regions.filter { $0.kind == .personalText }.map(\.value), ["221B Baker Street", "London NW1 6XE"])
        XCTAssertFalse(result.labelWithoutValue)
    }

    func testSignatureAndMRZAreHidden() {
        let lines = [
            line("Holder's signature", x: 80, y: 280, w: 180),
            line("P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<", x: 60, y: 420, w: 820),
        ]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(Set(result.regions.map(\.kind)), Set([.signature, .personalText]))
        XCTAssertTrue(result.regions.contains { $0.detail == "mrz" })
    }

    func testStandaloneLongIdsOnlyWhenCredentialLike() {
        let lines = [line("LIB-0048821", x: 100, y: 50), line("ISBN 978-7-5320-1234-5", x: 100, y: 90)]
        let onCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(onCard.regions.map(\.value), ["LIB-0048821", "978-7-5320-1234-5"])
        let notCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: false)
        XCTAssertTrue(notCard.regions.isEmpty, "a long number on a non-credential is left alone")
    }

    func testFacesAreAlwaysPrivate() {
        let face = CGRect(x: 40, y: 130, width: 210, height: 270)
        let asCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [face], codes: [], lines: [], imageSize: size), credentialLike: true)
        XCTAssertEqual(asCard.regions.map(\.kind), [.portrait])
        XCTAssertTrue(asCard.regions[0].rect.contains(face))
        let notCard = SensitiveRegionFinder.find(RegionFinderInput(faces: [face], codes: [], lines: [], imageSize: size), credentialLike: false)
        XCTAssertEqual(notCard.regions.map(\.kind), [.portrait])
        XCTAssertTrue(notCard.strongSignal)
    }

    func testEveryDistinctPortraitGetsASeparateRegion() {
        let main = CGRect(x: 40, y: 100, width: 180, height: 220)
        let watermark = CGRect(x: 700, y: 160, width: 70, height: 90)
        let input = RegionFinderInput(faces: [main, watermark], codes: [], lines: [], imageSize: size)
        let result = SensitiveRegionFinder.find(input, credentialLike: true)
        XCTAssertEqual(result.regions.filter { $0.kind == .portrait }.count, 2)
        XCTAssertTrue(result.regions.contains { $0.rect.contains(main) })
        XCTAssertTrue(result.regions.contains { $0.rect.contains(watermark) })
    }

    func testPortraitMarginDoesNotReachNearbyName() {
        let face = CGRect(x: 80, y: 100, width: 120, height: 150)
        let region = SensitiveRegionFinder.portraitFrame(around: face, in: CGRect(origin: .zero, size: size))
        XCTAssertTrue(region.contains(face))
        XCTAssertFalse(region.contains(CGPoint(x: 300, y: 170)), "portrait blur must not expand into the text column")
    }

    func testFaceCandidateDedupKeepsSecondaryPortrait() {
        let main = CGRect(x: 80, y: 100, width: 120, height: 150)
        let sameMain = CGRect(x: 84, y: 104, width: 116, height: 146)
        let secondary = CGRect(x: 700, y: 160, width: 60, height: 75)
        let result = LocalDetectors.deduplicatedFaces([main, sameMain, secondary])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains(secondary))
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
