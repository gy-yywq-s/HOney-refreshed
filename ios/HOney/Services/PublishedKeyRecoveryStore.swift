//
//  PublishedKeyRecoveryStore.swift
//  HOney — protected crash-safe journal for a published post whose key is not yet verified.
//

import Foundation

struct PublishedKeyRecoveryRecord: Codable, Sendable, Equatable {
    let experienceId: String
    let ownershipKey: String
    let targetKey: String
    let body: String
    let rating: Int?
    let createdAt: Date
}

actor PublishedKeyRecoveryStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let directory = directory ?? ComposerDraftStore.defaultDirectory()
        fileURL = directory.appendingPathComponent("honey-published-key-recovery.json")
    }

    func all() throws -> [String: PublishedKeyRecoveryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        return try JSONDecoder().decode([String: PublishedKeyRecoveryRecord].self, from: Data(contentsOf: fileURL))
    }

    func save(_ record: PublishedKeyRecoveryRecord) throws {
        var records = try all()
        records[record.experienceId] = record
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: HOneyFileStorage.writeOptions)
        guard try all()[record.experienceId] == record else { throw CocoaError(.fileWriteUnknown) }
    }

    func record(forTarget targetKey: String) throws -> PublishedKeyRecoveryRecord? {
        try all().values.sorted { $0.createdAt < $1.createdAt }.first { $0.targetKey == targetKey }
    }

    func clear(experienceId: String) throws {
        var records = try all()
        records.removeValue(forKey: experienceId)
        if records.isEmpty {
            try clearAll()
            return
        }
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: HOneyFileStorage.writeOptions)
    }

    func clearAll() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
