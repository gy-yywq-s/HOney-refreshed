// Small device-local stores: the transient composer draft (Web:
// lib/composerDraft.ts), recent Explore contexts (lib/recentContexts.ts),
// app preferences and the Web → iPhone transfer bundle (spec §5.5).
//
// Account boundary (review 11d42e3 §3.1): everything a second HOney account
// on the same iPhone must not see is keyed by the active account — drafts,
// recent contexts, the first-share disclosure, feed scope, Explore category.
// Appearance and language stay device-level. Signed out = no account = no
// reads and no writes.

import Foundation

// MARK: - Composer draft (one slot per account, keyed by target)

public struct ComposerDraft: Codable, Sendable, Equatable {
    /// lesson:<id> or the entity_key — the composer target this text belongs to.
    public var targetKey: String
    public var body: String
    public var rating: Int?
    public var updatedAt: Int64
}

public enum ComposerDraftStoreError: Error, Sendable, Equatable {
    case noAccount
    case notWritten
}

/// Plaintext on purpose: the student's own working text, short-lived and
/// re-shown only to them. Written BEFORE any moderation call; `save` throws
/// and verifies the bytes so "Saved" is never claimed for a write that did
/// not happen.
public final class ComposerDraftStore: @unchecked Sendable {
    private let directory: URL
    private let writeOptions: Data.WritingOptions
    private let lock = NSLock()
    private var account: String?

    public init(directory: URL, writeOptions: Data.WritingOptions = []) {
        self.directory = directory
        self.writeOptions = writeOptions.union(.atomic)
    }

    public func setAccount(_ honeyId: String?) {
        lock.lock(); defer { lock.unlock() }
        account = honeyId
    }

    private func url() throws -> URL {
        guard let account else { throw ComposerDraftStoreError.noAccount }
        return directory.appendingPathComponent("drafts").appendingPathComponent("\(AccountFiles.safeName(account)).json")
    }

    /// The saved draft for this target, or nil (another target's or account's
    /// draft, an unreadable file, or no account).
    public func get(_ targetKey: String) -> ComposerDraft? {
        lock.lock(); defer { lock.unlock() }
        guard let url = try? url(), let data = try? Data(contentsOf: url),
              let draft = try? JSONDecoder().decode(ComposerDraft.self, from: data) else { return nil }
        return draft.targetKey == targetKey ? draft : nil
    }

    public func save(targetKey: String, body: String, rating: Int?) throws {
        lock.lock(); defer { lock.unlock() }
        let url = try url()
        let draft = ComposerDraft(targetKey: targetKey, body: body, rating: rating, updatedAt: HOneyClock.now().epochMillis)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url, options: writeOptions)
        guard (try? Data(contentsOf: url)) == data else { throw ComposerDraftStoreError.notWritten }
    }

    /// Clear the slot, but only if it still holds this target's draft.
    public func clear(_ targetKey: String) throws {
        guard get(targetKey) != nil else { return }
        lock.lock(); defer { lock.unlock() }
        try FileManager.default.removeItem(at: try url())
    }
}

/// File names derived from a HOney id: alphanumerics only.
public enum AccountFiles {
    public static func safeName(_ account: String) -> String {
        account.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
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

/// UserDefaults-backed, non-secret preferences. Account-sensitive keys are
/// namespaced by the active HOney account; without one they read as
/// defaults and writes are dropped.
public final class Preferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var account: String?

    /// Bump when the first-share disclosure's content changes materially,
    /// so every account sees the new wording once.
    public static let disclosureVersion = 1

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func setAccount(_ honeyId: String?) {
        lock.lock(); defer { lock.unlock() }
        account = honeyId
    }

    private enum Key {
        static let stayOff = "honey.school.stayOff"
        static let language = "honey.lang"
        static let appearance = "honey.appearance"
        static let scope = "honey.exp.scope"
        static let recent = "honey.exp.recent"
        static let exploreCategory = "honey.explore.category"
        static let firstPublishSeen = "honey.exp.firstPublishSeen"
    }

    private func scoped(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let account else { return nil }
        return "\(key).\(AccountFiles.safeName(account))"
    }

    // Device-level

    /// Whether the student wants HOney to keep the school login on this
    /// iPhone: on unless they turned it off in Settings.
    public var stayConnectedWanted: Bool {
        get { !defaults.bool(forKey: Key.stayOff) }
        set { defaults.set(!newValue, forKey: Key.stayOff) }
    }

    public var language: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    public var appearance: AppearanceChoice {
        get { AppearanceChoice(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    // Account-scoped

    public var feedScope: FeedScope {
        get {
            guard let k = scoped(Key.scope) else { return .myClasses }
            return FeedScope(rawValue: defaults.string(forKey: k) ?? "") ?? .myClasses
        }
        set { if let k = scoped(Key.scope) { defaults.set(newValue.rawValue, forKey: k) } }
    }

    public var exploreCategory: EntityType {
        get {
            guard let k = scoped(Key.exploreCategory) else { return .teacher }
            return EntityType(rawValue: defaults.string(forKey: k) ?? "teacher")
        }
        set { if let k = scoped(Key.exploreCategory) { defaults.set(newValue.rawValue, forKey: k) } }
    }

    /// Seen for THIS account and THIS disclosure version.
    public var firstPublishDisclosureSeen: Bool {
        get {
            guard let k = scoped(Key.firstPublishSeen) else { return false }
            return defaults.integer(forKey: k) >= Self.disclosureVersion
        }
        set { if let k = scoped(Key.firstPublishSeen) { defaults.set(newValue ? Self.disclosureVersion : 0, forKey: k) } }
    }

    /// The last few entity pages opened (a convenience, never a signal).
    public var recentContexts: [RecentContext] {
        guard let k = scoped(Key.recent), let data = defaults.data(forKey: k) else { return [] }
        return (try? JSONDecoder().decode([RecentContext].self, from: data)) ?? []
    }

    public func rememberContext(_ ctx: RecentContext, max: Int = 5) {
        guard let k = scoped(Key.recent) else { return }
        let next = Array(([ctx] + recentContexts.filter { $0.id != ctx.id }).prefix(max))
        defaults.set(try? JSONEncoder().encode(next), forKey: k)
    }

    public func clearRecentContexts() {
        if let k = scoped(Key.recent) { defaults.removeObject(forKey: k) }
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
