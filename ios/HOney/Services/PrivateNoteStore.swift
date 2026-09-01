//
//  PrivateNoteStore.swift
//  HOney — first-class private notes (audit §3.5), device-only (Band 2/4).
//
//  Model mirrors the web PrivateNote shape (id, target, body, rating,
//  createdAt, updatedAt). Notes NEVER leave the device and never touch the
//  network; the file lives in Application Support with
//  `.completeFileProtection` — the iOS-appropriate equivalent of the web's
//  encrypted-at-rest note store. Sign-out does NOT delete notes; only account
//  deletion with the explicit "erase everything" choice does.
//

import Foundation

struct PrivateNoteTarget: Codable, Sendable, Equatable {
    /// Human-readable summary shown on the card ("Ms Lin — Maths, 12 Mar").
    let label: String
    var lessonId: String?
    var entityKey: String?
    /// Set when the target is a dish, so a later publish can offer stars.
    var entityType: String?
}

struct PrivateNote: Codable, Sendable, Identifiable, Equatable {
    let id: String
    var body: String
    var rating: Int?
    var target: PrivateNoteTarget
    let createdAt: Date
    var updatedAt: Date
}

actor PrivateNoteStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? ComposerDraftStore.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("honey-private-notes.json")
    }

    func list() -> [PrivateNote] {
        read()
    }

    func note(id: String) -> PrivateNote? {
        read().first { $0.id == id }
    }

    /// Create (`id == nil`) or update (existing id) a note. Updating keeps the
    /// original `createdAt` and refreshes `updatedAt`, like the web store.
    @discardableResult
    func save(id: String?, body: String, rating: Int?, target: PrivateNoteTarget) throws -> PrivateNote {
        var notes = read()
        let now = Date()
        if let id, let index = notes.firstIndex(where: { $0.id == id }) {
            var note = notes[index]
            note.body = body
            note.rating = rating
            note.target = target
            note.updatedAt = now
            notes[index] = note
            try write(notes)
            return note
        }
        let note = PrivateNote(
            id: UUID().uuidString,
            body: body,
            rating: rating,
            target: target,
            createdAt: now,
            updatedAt: now
        )
        notes.append(note)
        try write(notes)
        return note
    }

    func remove(id: String) {
        try? write(read().filter { $0.id != id })
    }

    /// Erase every note (account deletion with "erase everything" only).
    func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func read() -> [PrivateNote] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PrivateNote].self, from: data)) ?? []
    }

    private func write(_ notes: [PrivateNote]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(notes)
        try data.write(to: fileURL, options: HOneyFileStorage.writeOptions)
    }
}
