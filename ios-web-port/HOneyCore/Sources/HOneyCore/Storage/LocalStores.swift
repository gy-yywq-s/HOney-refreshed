// Small device-local stores: the transient composer draft (Web:
// lib/composerDraft.ts), recent Explore contexts (lib/recentContexts.ts),
// app preferences (saved-login wish, feed scope, language, appearance) and
// the Web → iPhone transfer bundle (spec §5.5).

import Foundation

// MARK: - Composer draft (one slot, keyed by target)

public struct ComposerDraft: Codable, Sendable, Equatable {
    /// lesson:<id> or the entity_key — the composer target this text belongs to.
    public var targetKey: String
    public var body: String
    public var rating: Int?
    public var updatedAt: Int64
}

/// Plaintext on purpose: the student's own working text, short-lived and
/// re-shown only to them. Written BEFORE any moderation call.
public final class ComposerDraftStore: @unchecked Sendable {
    private let url: URL
    private let writeOptions: Data.WritingOptions
    private let lock = NSLock()

    public init(directory: URL, writeOptions: Data.WritingOptions = []) {
        self.url = directory.appendingPathComponent("composer-draft.json")
        self.writeOptions = writeOptions.union(.atomic)
    }

    /// The saved draft for this target, or nil (another target's draft is ignored).
    public func get(_ targetKey: String) -> ComposerDraft? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url), let draft = try? JSONDecoder().decode(ComposerDraft.self, from: data) else { return nil }
        return draft.targetKey == targetKey ? draft : nil
    }

    public func save(targetKey: String, body: String, rating: Int?) {
        lock.lock(); defer { lock.unlock() }
        let draft = ComposerDraft(targetKey: targetKey, body: body, rating: rating, updatedAt: HOneyClock.now().epochMillis)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(draft).write(to: url, options: writeOptions)
    }

    /// Clear the slot, but only if it still holds this target's draft.
    public func clear(_ targetKey: String) {
        guard get(targetKey) != nil else { return }
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Preferences

public enum AppearanceChoice: String, Sendable, Codable, CaseIterable, Equatable {
    case system, light, dark
}

public struct RecentContext: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var name: String
    public var type: EntityType
    public var entityId: String
    public var id: String { "\(type.rawValue):\(entityId)" }
    public init(name: String, type: EntityType, entityId: String) {
        self.name = name
        self.type = type
        self.entityId = entityId
    }
}

/// UserDefaults-backed, non-secret preferences.
public final class Preferences: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let stayOff = "honey.school.stayOff"
        static let scope = "honey.exp.scope"
        static let language = "honey.lang"
        static let appearance = "honey.appearance"
        static let recent = "honey.exp.recent"
        static let exploreCategory = "honey.explore.category"
        static let firstPublishSeen = "honey.exp.firstPublishSeen"
    }

    /// Whether the student wants HOney to keep the school login on this
    /// iPhone: on unless they turned it off in Settings.
    public var stayConnectedWanted: Bool {
        get { !defaults.bool(forKey: Key.stayOff) }
        set { defaults.set(!newValue, forKey: Key.stayOff) }
    }

    public var feedScope: FeedScope {
        get { FeedScope(rawValue: defaults.string(forKey: Key.scope) ?? "") ?? .myClasses }
        set { defaults.set(newValue.rawValue, forKey: Key.scope) }
    }

    public var language: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    public var appearance: AppearanceChoice {
        get { AppearanceChoice(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    public var exploreCategory: EntityType {
        get { EntityType(rawValue: defaults.string(forKey: Key.exploreCategory) ?? "teacher") }
        set { defaults.set(newValue.rawValue, forKey: Key.exploreCategory) }
    }

    public var firstPublishDisclosureSeen: Bool {
        get { defaults.bool(forKey: Key.firstPublishSeen) }
        set { defaults.set(newValue, forKey: Key.firstPublishSeen) }
    }

    /// The last few entity pages opened (a convenience, never a signal).
    public var recentContexts: [RecentContext] {
        guard let data = defaults.data(forKey: Key.recent) else { return [] }
        return (try? JSONDecoder().decode([RecentContext].self, from: data)) ?? []
    }

    public func rememberContext(_ ctx: RecentContext, max: Int = 5) {
        let next = Array(([ctx] + recentContexts.filter { $0.id != ctx.id }).prefix(max))
        defaults.set(try? JSONEncoder().encode(next), forKey: Key.recent)
    }

    public func clearRecentContexts() {
        defaults.removeObject(forKey: Key.recent)
    }
}

// MARK: - Transfer bundle (Web → iPhone)

/// Either the Web's ownership-key export or the versioned device bundle.
public struct TransferBundle: Sendable, Equatable {
    public var accountHint: String?
    public var privateNotes: [PrivateNote]
    public var ownershipKeys: [StoredOwnershipKey]

    struct Wire: Decodable {
        var version: Int
        var accountHint: String?
        var privateNotes: [PrivateNote]?
        var ownershipKeys: [StoredOwnershipKey]?
        var keys: [StoredOwnershipKey]?
    }

    public init(accountHint: String? = nil, privateNotes: [PrivateNote] = [], ownershipKeys: [StoredOwnershipKey] = []) {
        self.accountHint = accountHint
        self.privateNotes = privateNotes
        self.ownershipKeys = ownershipKeys
    }

    public static func decode(_ data: Data) throws -> TransferBundle {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data), wire.version == 1 else {
            throw OwnershipKeyImportError.notAnExport
        }
        return TransferBundle(
            accountHint: wire.accountHint,
            privateNotes: wire.privateNotes ?? [],
            ownershipKeys: (wire.ownershipKeys ?? wire.keys ?? []).filter { $0.isValid }
        )
    }

    public struct ImportReport: Sendable, Equatable {
        public var keysAdded: Int
        public var notesAdded: Int
        public var failures: [String]
    }

    /// Writes keys to the key store and notes to the note store; partial
    /// failures are reported, never hidden.
    public func apply(keys: OwnershipKeyStoring, notes: PrivateNoteStore) async -> ImportReport {
        var report = ImportReport(keysAdded: 0, notesAdded: 0, failures: [])
        do {
            report.keysAdded = try keys.merge(ownershipKeys)
        } catch {
            report.failures.append("Control keys could not be stored in the Keychain.")
        }
        let existing = (try? await notes.list()) ?? []
        let have = Set(existing.map { "\($0.body)|\($0.target.label)" })
        for note in privateNotes where !have.contains("\(note.body)|\(note.target.label)") {
            do {
                try await notes.save(body: note.body, rating: note.rating, target: note.target, cooldown: .some(note.cooldown))
                report.notesAdded += 1
            } catch {
                report.failures.append("A private note could not be written to protected storage.")
            }
        }
        return report
    }
}
