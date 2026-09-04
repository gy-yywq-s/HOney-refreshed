//
//  FixtureManifest.swift
//  SanitationLab — the bundled test set (spec §8): synthetic cards with
//  ground-truth regions and real cards from Wikimedia Commons.
//

import CoreGraphics
import Foundation

struct FixtureManifest: Decodable {
    struct Item: Decodable, Identifiable {
        var id: String
        var file: String
        /// CLEAN, SANITIZED, or UNCERTAIN (record what happens, no strict expectation).
        var expected: String
        /// Kind → boxes as fractions of width/height (top-left origin).
        var mustHide: [String: [[Double]]]
        var mustKeep: [String: [[Double]]]
        var note: String
        var source: String?
        var license: String?

        var group: String { String(id.split(separator: "/").first ?? "") }

        func hideRects(in size: CGSize) -> [(kind: String, rect: CGRect)] {
            mustHide.flatMap { kind, boxes in boxes.map { (kind, Self.rect($0, in: size)) } }
        }
        func keepRects(in size: CGSize) -> [(kind: String, rect: CGRect)] {
            mustKeep.flatMap { kind, boxes in boxes.map { (kind, Self.rect($0, in: size)) } }
        }
        static func rect(_ f: [Double], in size: CGSize) -> CGRect {
            guard f.count == 4 else { return .zero }
            return CGRect(x: f[0] * size.width, y: f[1] * size.height, width: (f[2] - f[0]) * size.width, height: (f[3] - f[1]) * size.height)
        }
    }

    var version: Int
    var items: [Item]

    /// The folder reference "Fixtures" inside whichever bundle carries it
    /// (the app when tests run hosted, the test bundle otherwise).
    static func load() -> (manifest: FixtureManifest, folder: URL)? {
        for bundle in [Bundle.main] + Bundle.allBundles {
            if let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Fixtures"),
               let data = try? Data(contentsOf: url),
               let manifest = try? JSONDecoder().decode(FixtureManifest.self, from: data) {
                return (manifest, url.deletingLastPathComponent())
            }
        }
        return nil
    }

    func data(for item: Item, in folder: URL) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(item.file))
    }
}
