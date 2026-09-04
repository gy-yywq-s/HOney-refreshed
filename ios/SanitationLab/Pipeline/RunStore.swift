//
//  RunStore.swift
//  SanitationLab — keeps before/after and the record for every run, so a
//  failure can be looked at (spec §11). Documents/sanitation-lab/<run>/.
//

import Foundation
import UIKit

struct StoredRun: Identifiable, Equatable {
    var id: String { directory.lastPathComponent }
    var directory: URL
    var record: SanitationRecord

    var beforeURL: URL { directory.appendingPathComponent("before.jpg") }
    var afterURL: URL { directory.appendingPathComponent("after.jpg") }
    var hasAfter: Bool { FileManager.default.fileExists(atPath: afterURL.path) }
}

enum RunStore {
    static var root: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("sanitation-lab", isDirectory: true)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return f
    }()

    @discardableResult
    static func save(_ run: SanitationRun) -> StoredRun? {
        let name = "\(stamp.string(from: run.record.startedAt))-\(run.outcome.label.lowercased())"
        let dir = root.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try run.originalData.write(to: dir.appendingPathComponent("before.jpg"))
            if let after = run.outputData { try after.write(to: dir.appendingPathComponent("after.jpg")) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(run.record).write(to: dir.appendingPathComponent("record.json"))
            return StoredRun(directory: dir, record: run.record)
        } catch {
            return nil
        }
    }

    static func list() -> [StoredRun] {
        guard let dirs = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("record.json")),
                  let record = try? decoder.decode(SanitationRecord.self, from: data) else { return nil }
            return StoredRun(directory: dir, record: record)
        }
        .sorted { $0.record.startedAt > $1.record.startedAt }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: root)
    }
}
