//
//  RegionFinderTests.swift
//  The pure half: strings and rectangles in, regions out. No Vision.
//

import XCTest
import UIKit
import ImageIO
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
        XCTAssertFalse(result.labelWithoutValue)
        XCTAssertEqual(result.regions.map(\.detail), ["label-fallback"])
        XCTAssertEqual(result.regions.map(\.kind), [.number])
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
            line("出生：86.01.08", x: 100, y: 380),
        ]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        XCTAssertEqual(result.regions.filter { $0.kind == .personalText }.count, 6)
        XCTAssertFalse(result.regions.contains { $0.value?.contains("Zhang Wei") == true })
        XCTAssertFalse(result.regions.contains { $0.value?.contains("HUAYAO") == true })
        XCTAssertFalse(result.regions.contains { $0.value == "F" || $0.value == "Chinese" })
        XCTAssertFalse(result.labelWithoutValue)
    }

    func testAddressOnFollowingLinesIsHidden() {
        let lines = [
            line("Residential address:", x: 100, y: 100, w: 220),
            line("221B Baker Street", x: 340, y: 102, w: 260),
            line("London NW1 6XE", x: 340, y: 136, w: 230),
            line("Greater London", x: 340, y: 170, w: 230),
            line("United Kingdom", x: 340, y: 204, w: 230),
            line("Valid until: 2030-04", x: 100, y: 250),
        ]
        let result = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: size), credentialLike: true)
        let addresses = result.regions.filter { $0.detail == "address-block" }
        XCTAssertEqual(addresses.count, 1)
        XCTAssertEqual(addresses[0].value, "221B Baker Street London NW1 6XE Greater London United Kingdom")
        XCTAssertTrue(addresses[0].rect.contains(CGPoint(x: 350, y: 210)))
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
        let signature = try! XCTUnwrap(result.regions.first { $0.kind == .signature })
        XCTAssertTrue(signature.rect.contains(CGPoint(x: 180, y: 390)), "signature band must extend below its printed label")
    }

    func testVerificationIgnoresTheSameValueOutsideItsBlurRegion() {
        let region = SensitiveRegion(kind: .personalText, rect: CGRect(x: 100, y: 100, width: 200, height: 40), value: "Nederlandse", detail: nil)
        let heading = line("NEDERLANDSE IDENTITEITSKAART", x: 100, y: 20, w: 500)
        XCTAssertEqual(Sanitizer.valuesStillReadable(in: [heading], regions: [region]), [])

        let leakedField = line("Nederlandse", x: 120, y: 105, w: 150)
        XCTAssertEqual(Sanitizer.valuesStillReadable(in: [heading, leakedField], regions: [region]), ["Nederlandse"])
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

/// Local-only evaluation. No production behavior is changed; personal inputs
/// and every output remain in the ignored Fixtures/local directory.
final class LocalSanitationEvaluationTests: XCTestCase {
    func testAutomaticPageCropSignatureBoxUsesProductionBlur() throws {
        let local = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("SanitationLab/Fixtures/local")
        let folder = local.appendingPathComponent("signature-crops")
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("results.json")) else {
            throw XCTSkip("Optional local signature benchmark is absent")
        }
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let row = try XCTUnwrap(rows.first { ($0["model"] as? String) == "sanitation-signature"
            && ($0["case"] as? String) == "passport-automatic-0" && ($0["letterbox"] as? Bool) == true })
        let boxRows = try XCTUnwrap(row["boxes"] as? [[String: Any]])
        let b = try XCTUnwrap(boxRows.first?["box"] as? [Double])
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(folder.appendingPathComponent("passport-automatic-0-input.png") as CFURL, nil))
        let input = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let rawBox = CGRect(x: b[0], y: b[1], width: b[2]-b[0], height: b[3]-b[1])
        let rect = SensitiveRegionFinder.pad(rawBox, by: 0.18,
            in: CGRect(x: 0, y: 0, width: input.width, height: input.height))
        let region = SensitiveRegion(kind: .signature, rect: rect, value: nil, detail: "evaluation-model-signature")
        // Independently marked signature ink and printed-name areas, in this page crop.
        XCTAssertTrue(rect.contains(CGRect(x: 1750, y: 1200, width: 415, height: 160)))
        XCTAssertFalse(rect.intersects(CGRect(x: 840, y: 380, width: 520, height: 160)))
        let output = try XCTUnwrap(Sanitizer.sanitize(input, regions: [region]))
        let jpeg = try XCTUnwrap(UIImage(cgImage: output).jpegData(compressionQuality: 0.95))
        try jpeg.write(to: folder.appendingPathComponent("automatic-signature-production-blur.jpg"))
        XCTAssertNotEqual(jpeg, UIImage(cgImage: input).jpegData(compressionQuality: 0.95))
    }

    func testSplitAddressCounterexampleAndVerificationBlindSpot() {
        // Fictional strings, geometry reproducing a separate short label.
        let lines = [
            TextLine(string: "住址", rect: CGRect(x: 100, y: 100, width: 60, height: 30)),
            TextLine(string: "示例市青山路第一段", rect: CGRect(x: 220, y: 100, width: 320, height: 30)),
            TextLine(string: "花园小区二栋", rect: CGRect(x: 220, y: 135, width: 220, height: 42)),
            TextLine(string: "姓名：示例", rect: CGRect(x: 100, y: 40, width: 200, height: 30)),
        ]
        let input = RegionFinderInput(faces: [], codes: [], lines: lines, imageSize: CGSize(width: 1000, height: 600))
        let baseline = SensitiveRegionFinder.find(input, credentialLike: true)
        XCTAssertFalse(baseline.regions.contains { $0.rect.contains(CGPoint(x: 500, y: 110)) }, "Baseline should reproduce the missed first line")
        let candidate = Self.addressBlocks(lines, size: input.imageSize)
        XCTAssertTrue(candidate.contains { $0.rect.contains(CGRect(x: 220, y: 100, width: 320, height: 65)) })
        let block = SensitiveRegion(kind: .personalText, rect: CGRect(x: 200, y: 100, width: 350, height: 80),
                                    value: "示例市青山路第一段 花园小区二栋", detail: "address-block")
        XCTAssertEqual(Sanitizer.valuesStillReadable(in: [lines[1]], regions: [block]), [],
                       "Existing verifier misses a readable fragment of a multi-line value")

        let bilingual = SensitiveRegionFinder.find(RegionFinderInput(faces: [], codes: [], lines: [
            TextLine(string: "出生地点/Place of birth", rect: CGRect(x: 100, y: 100, width: 300, height: 30)),
            TextLine(string: "示例市/EXAMPLE CITY", rect: CGRect(x: 100, y: 140, width: 300, height: 30)),
        ], imageSize: input.imageSize), credentialLike: true)
        XCTAssertEqual(bilingual.regions.first?.value, "Place of birth", "Baseline mistakes the translated label for a value")
        XCTAssertFalse(bilingual.regions.contains { $0.rect.contains(CGPoint(x: 200, y: 155)) })

        let signatureLabel = CGRect(x: 100, y: 100, width: 30, height: 300)
        let misplaced = SensitiveRegionFinder.signatureFrame(around: signatureLabel,
            in: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        XCTAssertFalse(misplaced.contains(CGPoint(x: 70, y: 250)), "A rotated label needs expansion to the left, not screen-down")
    }

    func testSavedAddressAndSignatureCases() async throws {
        let local = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("SanitationLab/Fixtures/local")
        guard FileManager.default.fileExists(atPath: local.appendingPathComponent("20260905-104212/before.jpg").path) else {
            throw XCTSkip("Optional private evaluation cases are not present")
        }
        var summary: [[String: Any]] = []
        for id in ["20260905-104212", "20260905-104235"] {
            let dir = local.appendingPathComponent(id)
            let data = try Data(contentsOf: dir.appendingPathComponent("before.jpg"))
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            // This ablation tests known upright pixels versus camera EXIF
            // orientation. It does not claim automatic orientation is solved.
            let upright = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let original = try XCTUnwrap(AnalysisDerivative.normalised(try XCTUnwrap(UIImage(data: data))))
            for (variant, cg) in [("baseline", original), ("upright", upright)] {
                let start = Date()
                let d = await LocalDetectors().detect(cg)
                let input = RegionFinderInput(faces: d.faces, codes: d.codes, lines: d.lines,
                                             imageSize: CGSize(width: cg.width, height: cg.height))
                let found = SensitiveRegionFinder.find(input, credentialLike: true)
                let output = try XCTUnwrap(Sanitizer.sanitize(cg, regions: found.regions))
                try XCTUnwrap(UIImage(cgImage: output).jpegData(compressionQuality: 0.95))
                    .write(to: dir.appendingPathComponent("eval-\(variant).jpg"))
                let verification = await Sanitizer.verify(output, regions: found.regions, languages: LocalDetectors().recognitionLanguages)
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                let rows: [[String: Any]] = d.lines.map { ["text": $0.string, "x": $0.rect.minX, "y": $0.rect.minY, "w": $0.rect.width, "h": $0.rect.height] }
                try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
                    .write(to: dir.appendingPathComponent("eval-\(variant)-ocr.json"))
                try JSONEncoder().encode(found.regions).write(to: dir.appendingPathComponent("eval-\(variant)-regions.json"))
                summary.append(["case": id, "variant": variant, "localMs": elapsed, "detectMs": d.elapsedMs,
                                "regions": found.regions.count, "readable": verification.valuesStillReadable.count])

                if id == "20260905-104212", variant == "upright" {
                    let candidateStart = Date()
                    let added = Self.addressBlocks(d.lines, size: input.imageSize)
                    let candidateMs = Date().timeIntervalSince(candidateStart) * 1000
                    let regions = found.regions.filter { $0.detail?.hasPrefix("address") != true } + added
                    let candidate = try XCTUnwrap(Sanitizer.sanitize(cg, regions: regions))
                    try XCTUnwrap(UIImage(cgImage: candidate).jpegData(compressionQuality: 0.95))
                        .write(to: dir.appendingPathComponent("eval-candidate.jpg"))
                    try JSONEncoder().encode(regions).write(to: dir.appendingPathComponent("eval-candidate-regions.json"))
                    // Independently marked field area, not a box derived from the detector.
                    let addressInk = CGRect(x: 220, y: 1065, width: 320, height: 71)
                    XCTAssertTrue(added.contains { $0.rect.contains(addressInk) }, "Both address lines must be covered")
                    XCTAssertLessThan(added[0].rect.maxY, 1180, "Address block must stop before the separate ID row")
                    let preservedName = CGRect(x: 220, y: 878, width: 115, height: 34)
                    XCTAssertFalse(added.contains { $0.rect.intersects(preservedName) })
                    summary.append(["case": id, "variant": "candidate-address", "groupingMs": candidateMs,
                                    "regions": added.count])
                }
            }
        }
        try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
            .write(to: local.appendingPathComponent("evaluation-summary.json"))
    }

    /// Evaluation-only hypothesis: prefer every value fragment on the label's
    /// row before searching below; allow whitespace inside Chinese labels.
    static func addressBlocks(_ lines: [TextLine], size: CGSize) -> [SensitiveRegion] {
        let pattern = #"住\s*址|地\s*址|(?i:address)"#
        let boundary = #"^(姓名|性\s*别|性\s*別|出\s*生|公民身份|有效|Name|Sex|Date|Valid|Signature)"#
        var result: [SensitiveRegion] = []
        for label in lines {
            guard let match = label.string.range(of: pattern, options: .regularExpression) else { continue }
            var boxes: [CGRect] = []
            var values: [String] = []
            let tail = label.string[match.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty, let range = label.string.range(of: tail, options: .backwards) {
                boxes.append(label.subrect(range) ?? label.rect)
                values.append(tail)
            }
            let sameRow = lines.filter {
                $0.rect.minX > label.rect.maxX - 2 && abs($0.rect.midY - label.rect.midY) < max(label.rect.height, $0.rect.height) * 0.8
            }.sorted { $0.rect.minX < $1.rect.minX }
            boxes += sameRow.map(\.rect)
            values += sameRow.map(\.string)
            guard var block = boxes.reduce(nil as CGRect?, { $0?.union($1) ?? $1 }) else { continue }
            for line in lines.sorted(by: { $0.rect.minY < $1.rect.minY }) {
                guard line.rect.minY >= block.maxY - line.rect.height * 0.2,
                      line.rect.minY - block.maxY < line.rect.height * 1.4,
                      line.rect.maxX > block.minX, line.rect.minX < block.maxX else { continue }
                if line.string.range(of: boundary, options: [.regularExpression, .caseInsensitive]) != nil { break }
                block = block.union(line.rect)
                values.append(line.string)
            }
            result.append(SensitiveRegion(kind: .personalText,
                rect: SensitiveRegionFinder.pad(block, by: 0.18, in: CGRect(origin: .zero, size: size)),
                value: values.joined(separator: " "), detail: "eval-address-block"))
        }
        return result
    }
}
