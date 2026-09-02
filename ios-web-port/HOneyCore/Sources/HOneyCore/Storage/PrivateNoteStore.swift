// Private notes (Web: lib/ownershipKeys.ts PrivateNoteStore) — first-class,
// device-only. On iPhone they live in a protected file (the app passes
// `.completeFileProtection`), written atomically and read back before
// "Saved" is ever reported, namespaced per HOney account so one account's
// notes never appear under another. Sign-out keeps them; only account
// deletion with the explicit erase choice removes them.

import Foundation

public struct PrivateNoteTarget: Codable, Sendable, Equatable, Hashable {
    /// Human-readable summary shown on the row ("Ms Lin — Maths, 12 Mar").
    public var label: String
    public var lessonId: String?
    public var lessonDate: String?
    public var entityKey: String?
    /// "dish" when the target is a dish, so a later publish can offer stars.
    public var entityType: String?

    public init(label: String, lessonId: String? = nil, lessonDate: String? = nil, entityKey: String? = nil, entityType: String? = nil) {
        self.label = label
        self.lessonId = lessonId
        self.lessonDate = lessonDate
        self.entityKey = entityKey
        self.entityType = entityType
    }
}

public struct NoteCooldown: Codable, Sendable, Equatable, Hashable {
    /// When the check may run again (epoch ms).
    public var until: Int64
    /// The server's content-bound cooldown ticket for this exact text.
    public var ticket: String
    public init(until: Int64, ticket: String) {
        self.until = until
        self.ticket = ticket
    }
}

public struct PrivateNote: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var body: String
    public var rating: Int?
    public var target: PrivateNoteTarget
    /// Set when the pre-publish check put this text into a cooling-off period.
    public var cooldown: NoteCooldown?
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(id: String, body: String, rating: Int?, target: PrivateNoteTarget, cooldown: NoteCooldown?, createdAt: Int64, updatedAt: Int64) {
        self.id = id
        self.body = body
        self.rating = rating
        self.target = target
        self.cooldown = cooldown
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum PrivateNoteStoreError: Error, Sendable, Equatable {
    case notWritten
    case noAccount
}

public actor PrivateNoteStore {
    struct File: Codable {
        var version: Int
        var account: String
        var notes: [PrivateNote]
    }

    public static let version = 1

    private let directory: URL
    private let writeOptions: Data.WritingOptions
    private var account: String?

    /// `writeOptions` lets the app add `.completeFileProtection`; `.atomic` is always on.
    public init(directory: URL, writeOptions: Data.WritingOptions = []) {
        self.directory = directory
        self.writeOptions = writeOptions.union(.atomic)
    }

    /// Every operation is scoped to the signed-in HOney account.
    public func setAccount(_ honeyId: String?) {
        account = honeyId
    }

    public func list() throws -> [PrivateNote] {
        try read().notes
    }

    public func note(id: String) throws -> PrivateNote? {
        try read().notes.first { $0.id == id }
    }

    /// Create (`id == nil`) or update (existing id). Updating keeps the
    /// original `createdAt`. `cooldown`: `.some(nil)` clears, `nil` keeps.
    @discardableResult
    public func save(id: String? = nil, body: String, rating: Int?, target: PrivateNoteTarget, cooldown: NoteCooldown?? = nil, now: Date = HOneyClock.now()) throws -> PrivateNote {
        var file = try read()
        let nowMs = now.epochMillis
        let existing = id.flatMap { id in file.notes.first { $0.id == id } }
        let note = PrivateNote(
            id: existing?.id ?? UUID().uuidString,
            body: body,
            rating: rating,
            target: target,
            cooldown: cooldown == nil ? existing?.cooldown : cooldown!,
            createdAt: existing?.createdAt ?? nowMs,
            updatedAt: nowMs
        )
        if let index = file.notes.firstIndex(where: { $0.id == note.id }) {
            file.notes[index] = note
        } else {
            file.notes.append(note)
        }
        try write(file)
        return note
    }

    public func remove(id: String) throws {
        var file = try read()
        file.notes.removeAll { $0.id == id }
        try write(file)
    }

    /// Erase this account's notes (account deletion with "erase local data").
    public func clearAll() throws {
        let url = try fileURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Files

    private func fileURL() throws -> URL {
        guard let account else { throw PrivateNoteStoreError.noAccount }
        let safe = account.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return directory.appendingPathComponent("notes").appendingPathComponent("\(safe).v\(Self.version).json")
    }

    private func read() throws -> File {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return File(version: Self.version, account: account ?? "", notes: [])
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.version == Self.version, file.account == account else {
            return File(version: Self.version, account: account ?? "", notes: [])
        }
        return file
    }

    private func write(_ file: File) throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: writeOptions)
        // Never say "Saved" before the bytes are really there.
        let back = try Data(contentsOf: url)
        guard back == data else { throw PrivateNoteStoreError.notWritten }
    }
}
