//
//  ComposerDraftStore.swift
//  HOney — the single composer draft slot (Band 2/4, no SwiftUI).
//
//  Mirrors the web composerDraft.ts semantics (audit §3.4): the draft is written
//  BEFORE any moderation call, so a rejected/failed check — or a crash — never
//  loses the user's own words. Every non-publish outcome returns the user to
//  this exact text; a successful publish clears it. One slot is enough (only
//  one composer is open at a time), keyed by target so switching targets never
//  surfaces stale text. Sign-out does NOT clear the slot — the draft is the
//  user's own device-local text, like ownership keys and private notes.
//

import Foundation

struct ComposerDraft: Codable, Sendable, Equatable {
    /// "lesson:<id>" or the entity_key — the composer target this text belongs to.
    let targetKey: String
    let body: String
    let rating: Int?
    let updatedAt: Date
}

actor ComposerDraftStore {
    private let fileURL: URL

    /// Default store: Application Support/honey-drafts.json with complete file
    /// protection — the iOS-appropriate equivalent of the web's device-local
    /// storage posture (the draft additionally never leaves the device).
    init(directory: URL? = nil) {
        let dir = directory ?? ComposerDraftStore.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("honey-drafts.json")
    }

    static func defaultDirectory() -> URL {
        (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
    }

    /// The saved draft for this target, or nil (a different target's draft is ignored).
    func get(_ targetKey: String) -> ComposerDraft? {
        guard let draft = read(), draft.targetKey == targetKey else { return nil }
        return draft
    }

    /// Single-slot replace: whatever the slot held before is overwritten.
    func save(targetKey: String, body: String, rating: Int?) {
        write(ComposerDraft(targetKey: targetKey, body: body, rating: rating, updatedAt: Date()))
    }

    /// Clear the slot, but only if it still holds this target's draft.
    func clear(_ targetKey: String) {
        guard get(targetKey) != nil else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Erase the slot unconditionally (account deletion with "erase everything").
    func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func read() -> ComposerDraft? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ComposerDraft.self, from: data)
    }

    private func write(_ draft: ComposerDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: HOneyFileStorage.writeOptions)
    }
}

/// Shared write options for HOney's device-local JSON stores.
enum HOneyFileStorage {
    /// `.completeFileProtection` keeps the file encrypted at rest while the
    /// device is locked (iOS Data Protection).
    static var writeOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtection]
        #else
        [.atomic]
        #endif
    }
}
