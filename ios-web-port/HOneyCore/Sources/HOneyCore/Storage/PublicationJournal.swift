// The publication recovery journal (review 11d42e3 §3.3.3): a control key
// is written here, durably, the moment a post is public and BEFORE the
// draft is cleared or the Keychain is asked. If the process dies before the
// Keychain write succeeds, the next launch replays the journal, so a public
// post never loses its control. Per account, protected file, verified writes.

import Foundation

public struct PublicationRecord: Codable, Sendable, Equatable {
    public var experienceId: String
    public var ownershipKey: String
    public var targetKey: String
    public var createdAt: Int64

    public init(experienceId: String, ownershipKey: String, targetKey: String, createdAt: Int64) {
        self.experienceId = experienceId
        self.ownershipKey = ownershipKey
        self.targetKey = targetKey
        self.createdAt = createdAt
    }
}

public enum PublicationJournalError: Error, Sendable, Equatable {
    case noAccount
    case notWritten
}

public actor PublicationJournal {
    struct File: Codable {
        var version: Int
        var account: String
        var records: [PublicationRecord]
    }

    public static let version = 1
    private let directory: URL
    private let writeOptions: Data.WritingOptions
    private var account: String?

    public init(directory: URL, writeOptions: Data.WritingOptions = []) {
        self.directory = directory
        self.writeOptions = writeOptions.union(.atomic)
    }

    public func setAccount(_ honeyId: String?) {
        account = honeyId
    }

    public func pending() throws -> [PublicationRecord] {
        try read().records
    }

    /// Durable before returning: the bytes are read back and compared.
    public func write(_ record: PublicationRecord) throws {
        var file = try read()
        file.records.removeAll { $0.experienceId == record.experienceId }
        file.records.append(record)
        try persist(file)
    }

    public func remove(experienceId: String) throws {
        var file = try read()
        file.records.removeAll { $0.experienceId == experienceId }
        try persist(file)
    }

    public func clearAll() throws {
        let url = try fileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL() throws -> URL {
        guard let account else { throw PublicationJournalError.noAccount }
        return directory.appendingPathComponent("publications").appendingPathComponent("\(AccountFiles.safeName(account)).v\(Self.version).json")
    }

    private func read() throws -> File {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return File(version: Self.version, account: account ?? "", records: [])
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        guard file.version == Self.version, file.account == account else {
            return File(version: Self.version, account: account ?? "", records: [])
        }
        return file
    }

    private func persist(_ file: File) throws {
        let url = try fileURL()
        if file.records.isEmpty {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: writeOptions)
        guard (try? Data(contentsOf: url)) == data else { throw PublicationJournalError.notWritten }
    }
}
