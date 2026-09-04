//
//  LiveClassifierTests.swift
//  The remote half against the deployed route — opt in with the environment
//  variable SANITATION_LIVE=1 (scheme › Test › Arguments › Environment, or
//  `-testPlan`-less xcodebuild with the variable exported). Measures the
//  classification latency the spec targets (≈2 s preferred, ≤3 s acceptable)
//  and the verdicts over the whole fixture set.
//

import XCTest
@testable import SanitationLab

final class LiveClassifierTests: XCTestCase {
    func testLiveClassifierOverTheFixtureSet() async throws {
        guard ProcessInfo.processInfo.environment["SANITATION_LIVE"] == "1" else { throw XCTSkip("set SANITATION_LIVE=1 to hit the live route") }
        guard let loaded = FixtureManifest.load() else { throw XCTSkip("no fixtures") }
        let manifest = loaded.manifest, folder = loaded.folder
        let classifier = RemoteCredentialClassifier(baseURL: LabConfig.baseURL)

        var lines: [String] = []
        var latencies: [Int] = []
        var right = 0, judged = 0, unavailable = 0
        for item in manifest.items {
            let data = try XCTUnwrap(manifest.data(for: item, in: folder))
            let cg = try XCTUnwrap(AnalysisDerivative.normalised(try XCTUnwrap(UIImage(data: data))))
            let derivative = try XCTUnwrap(AnalysisDerivative.make(from: cg))
            let answer = await classifier.classify(jpeg: derivative.data)
            latencies.append(answer.latencyMs)
            if !answer.available { unavailable += 1 }
            if answer.available, item.expected != "UNCERTAIN" {
                judged += 1
                if answer.credentialLike == (item.expected == "SANITIZED") { right += 1 }
            }
            lines.append("\(item.id): expected \(item.expected) → \(answer.available ? (answer.credentialLike ? "credential" : "clean") : "UNAVAILABLE")\(answer.uncertain ? "?" : "") \(answer.latencyMs) ms \(answer.model ?? "")")
        }
        let sorted = latencies.sorted()
        let p50 = sorted[sorted.count / 2], p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
        let report = "valid \(manifest.items.count - unavailable)/\(manifest.items.count) · right \(right)/\(judged) · p50 \(p50) ms · p90 \(p90) ms · max \(sorted.last ?? 0) ms\n" + lines.joined(separator: "\n")
        let a = XCTAttachment(string: report)
        a.name = "live-classifier.txt"
        a.lifetime = .keepAlways
        add(a)
        print(report)

        XCTAssertLessThanOrEqual(unavailable, 2, "the route should answer")
        XCTAssertGreaterThanOrEqual(Double(right) / Double(max(1, judged)), 0.9, "accuracy on the definite fixtures")
        XCTAssertLessThanOrEqual(p90, 3000, "spec: ≤ 3 s acceptable for classification")
    }
}
