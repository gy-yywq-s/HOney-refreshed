//
//  FixturePipelineTests.swift
//  The bundled test set through the real detectors and sanitizer, with the
//  classifier stubbed from the manifest — so this measures Vision and the
//  masking, not the network. Before/after images are attached to every
//  credential run for visual review (spec §11).
//
//  Strict assertions on the synthetic credential set (it has ground truth);
//  the edge and real groups are recorded and only checked for the one rule
//  that must never break: a credential is never returned CLEAN.
//

import XCTest
@testable import SanitationLab

final class FixturePipelineTests: XCTestCase {
    private var manifest: FixtureManifest!
    private var folder: URL!

    override func setUpWithError() throws {
        guard let loaded = FixtureManifest.load() else { throw XCTSkip("Fixtures folder not in any bundle") }
        manifest = loaded.manifest
        folder = loaded.folder
    }

    // MARK: - Clean set: bytes come back untouched

    func testCleanImagesAreReturnedUnchanged() async throws {
        for item in manifest.items where item.group == "clean" && item.id != "clean/bottle_background_faces" {
            let data = try XCTUnwrap(manifest.data(for: item, in: folder))
            let run = await SanitationPipeline(classifier: StubCredentialClassifier(credentialLike: false)).run(imageData: data, fixtureId: item.id)
            XCTAssertEqual(run.outcome, .clean, item.id)
            XCTAssertEqual(run.originalData, data, "\(item.id): CLEAN must be the original bytes")
            XCTAssertNil(run.outputData)
            XCTAssertEqual(run.record.decision, .classifierSaidClean)
        }
    }

    func testFacesAreSanitizedEvenWhenClassifierSaysClean() async throws {
        let item = try XCTUnwrap(manifest.items.first { $0.id == "clean/bottle_background_faces" })
        let data = try XCTUnwrap(manifest.data(for: item, in: folder))
        let run = await SanitationPipeline(classifier: StubCredentialClassifier(credentialLike: false)).run(imageData: data, fixtureId: item.id)
        XCTAssertEqual(run.outcome, .sanitized)
        XCTAssertEqual(run.record.decision, .classifierSaidCleanFacesFound)
        XCTAssertGreaterThanOrEqual(run.record.facesFound, 2)
        XCTAssertEqual(run.record.regions.filter { $0.kind == .portrait }.count, run.record.facesFound)
        XCTAssertNotNil(run.outputData)
    }

    // MARK: - Synthetic credentials: ground truth

    func testSyntheticCredentialsAreSanitizedWithTheRightRegions() async throws {
        var lines: [String] = []
        for item in manifest.items where item.group == "credential" {
            let data = try XCTUnwrap(manifest.data(for: item, in: folder))
            let run = await SanitationPipeline(classifier: StubCredentialClassifier(credentialLike: true)).run(imageData: data, fixtureId: item.id)
            attach(run, item)
            lines.append(summary(run))
            XCTAssertEqual(run.outcome, .sanitized, "\(item.id): \(run.record.reason?.rawValue ?? "")")
            guard run.outcome == .sanitized, let output = run.outputImage, let working = run.workingImage else { continue }
            XCTAssertNotEqual(run.outputData, data, "\(item.id): output must be a new encoding")

            let size = run.record.imageSize
            // Every must-hide box is mostly covered by regions.
            for (kind, box) in item.hideRects(in: size) {
                let coverage = Self.coverage(of: box, by: run.record.regions.map(\.rect))
                XCTAssertGreaterThanOrEqual(coverage, 0.6, "\(item.id): \(kind) box only \(Int(coverage * 100))% covered")
            }
            // Every must-keep box is (up to JPEG noise) untouched.
            for (kind, box) in item.keepRects(in: size) {
                let diff = Self.meanAbsDiff(working, output, in: box)
                XCTAssertLessThan(diff, 8, "\(item.id): \(kind) box changed (mean |Δ| \(Int(diff)))")
            }
            // Codes on the output must not decode; masked values must not read back.
            let codes = await LocalDetectors.codes(in: output)
            XCTAssertEqual(codes.count, 0, "\(item.id): a code still decodes")
            XCTAssertEqual(run.record.verification?.valuesStillReadable ?? [], [], item.id)
        }
        addText(lines.joined(separator: "\n"), named: "synthetic-credentials.txt")
    }

    // MARK: - Edge + real: record, and never CLEAN for an expected credential

    func testEdgeAndRealCredentialsAreNeverReturnedClean() async throws {
        var lines: [String] = []
        for item in manifest.items where item.group == "edge" || item.group == "real" {
            let data = try XCTUnwrap(manifest.data(for: item, in: folder))
            let stub = StubCredentialClassifier(credentialLike: item.expected != "CLEAN")
            let run = await SanitationPipeline(classifier: stub).run(imageData: data, fixtureId: item.id)
            attach(run, item)
            lines.append(summary(run))
            if item.expected == "SANITIZED" {
                XCTAssertNotEqual(run.outcome, .clean, "\(item.id): a credential came back CLEAN")
                if run.outcome == .sanitized, let output = run.outputImage {
                    let codes = await LocalDetectors.codes(in: output)
                    XCTAssertEqual(codes.count, 0, "\(item.id): a code still decodes")
                }
            }
        }
        addText(lines.joined(separator: "\n"), named: "edge-and-real.txt")
    }

    // MARK: - Classifier down: local signals decide, and it is recorded

    func testClassifierDownFallsBackToLocalSignals() async throws {
        let card = try XCTUnwrap(manifest.items.first { $0.id == "credential/student_card_qr" })
        let calculator = try XCTUnwrap(manifest.items.first { $0.id == "clean/calculator" })
        let down = StubCredentialClassifier(credentialLike: false, available: false)
        let cardData = try XCTUnwrap(manifest.data(for: card, in: folder))
        let calculatorData = try XCTUnwrap(manifest.data(for: calculator, in: folder))

        let cardRun = await SanitationPipeline(classifier: down).run(imageData: cardData, fixtureId: card.id)
        XCTAssertNotEqual(cardRun.outcome, .clean, "the QR is a strong signal on its own")
        XCTAssertEqual(cardRun.record.decision, .localSignalsWithClassifierDown)
        XCTAssertFalse(cardRun.record.classifier.available)

        let calcRun = await SanitationPipeline(classifier: down).run(imageData: calculatorData, fixtureId: calculator.id)
        XCTAssertEqual(calcRun.outcome, .clean)
        XCTAssertEqual(calcRun.record.decision, .noSignalsWithClassifierDown)
    }

    // MARK: - Derivative

    func testDerivativeFitsTheEdgeBudget() throws {
        for item in manifest.items {
            let data = try XCTUnwrap(manifest.data(for: item, in: folder))
            let cg = try XCTUnwrap(AnalysisDerivative.normalised(try XCTUnwrap(UIImage(data: data))))
            let derivative = try XCTUnwrap(AnalysisDerivative.make(from: cg))
            XCTAssertLessThanOrEqual(derivative.data.count, AnalysisDerivative.byteBudget, item.id)
            let small = try XCTUnwrap(UIImage(data: derivative.data))
            XCTAssertLessThanOrEqual(max(small.size.width, small.size.height), AnalysisDerivative.longEdge + 1, item.id)
        }
    }

    // MARK: - Helpers

    private func summary(_ run: SanitationRun) -> String {
        let r = run.record
        let regions = r.regionCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " ")
        return "\(r.fixtureId ?? "?"): \(r.outcome)\(r.reason.map { "(\($0.rawValue))" } ?? "") faces=\(r.facesFound) codes=\(r.codesFound) lines=\(r.textLinesFound) [\(regions)] detect=\(r.detectionMs)ms hide=\(r.sanitationMs)ms"
    }

    private func addText(_ text: String, named name: String) {
        let a = XCTAttachment(string: text)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func attach(_ run: SanitationRun, _ item: FixtureManifest.Item) {
        let name = item.id.replacingOccurrences(of: "/", with: "__")
        if let before = UIImage(data: run.originalData) {
            let a = XCTAttachment(image: before)
            a.name = "\(name)-before"
            a.lifetime = .keepAlways
            add(a)
        }
        if let cg = run.outputImage {
            let a = XCTAttachment(image: UIImage(cgImage: cg))
            a.name = "\(name)-after"
            a.lifetime = .keepAlways
            add(a)
        }
        if let json = try? JSONEncoder().encode(run.record), let text = String(data: json, encoding: .utf8) {
            let a = XCTAttachment(string: text)
            a.name = "\(name)-record.json"
            a.lifetime = .keepAlways
            add(a)
        }
    }

    /// Fraction of `box` covered by the union of `rects` (grid sample).
    static func coverage(of box: CGRect, by rects: [CGRect]) -> Double {
        guard box.width > 0, box.height > 0 else { return 1 }
        let n = 20
        var hit = 0
        for i in 0..<n {
            for j in 0..<n {
                let p = CGPoint(x: box.minX + (CGFloat(i) + 0.5) / CGFloat(n) * box.width, y: box.minY + (CGFloat(j) + 0.5) / CGFloat(n) * box.height)
                if rects.contains(where: { $0.contains(p) }) { hit += 1 }
            }
        }
        return Double(hit) / Double(n * n)
    }

    /// Mean absolute RGB difference between two same-size images inside `box`.
    static func meanAbsDiff(_ a: CGImage, _ b: CGImage, in box: CGRect) -> Double {
        guard a.width == b.width, a.height == b.height, let pa = rgba(a), let pb = rgba(b) else { return 255 }
        let r = box.integral.intersection(CGRect(x: 0, y: 0, width: a.width, height: a.height))
        guard !r.isEmpty else { return 0 }
        var sum = 0, count = 0
        for y in Int(r.minY)..<Int(r.maxY) {
            for x in Int(r.minX)..<Int(r.maxX) {
                let i = (y * a.width + x) * 4
                sum += abs(Int(pa[i]) - Int(pb[i])) + abs(Int(pa[i + 1]) - Int(pb[i + 1])) + abs(Int(pa[i + 2]) - Int(pb[i + 2]))
                count += 3
            }
        }
        return count == 0 ? 0 : Double(sum) / Double(count)
    }

    private static func rgba(_ cg: CGImage) -> [UInt8]? {
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return pixels
    }
}
