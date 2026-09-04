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
        // The Web's own keys (lib/theme.ts, lib/textSize.ts), so a future
        // device bundle can carry the choice across.
        static let background = "honey.theme.surface"
        static let accent = "honey.theme.accent"
        static let textSize = "honey.textsize"
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

    /// The chosen Background, or nil until the student chooses one (the Web
    /// boot script then follows the system's dark preference: Night or Stone).
    public var background: HOneyBackground? {
        get { defaults.string(forKey: Key.background).flatMap(HOneyBackground.init(rawValue:)) }
        set {
            if let newValue { defaults.set(newValue.rawValue, forKey: Key.background) } else { defaults.removeObject(forKey: Key.background) }
        }
    }

    public var accent: HOneyAccent {
        get { HOneyAccent(rawValue: defaults.string(forKey: Key.accent) ?? "") ?? .harbour }
        set { defaults.set(newValue.rawValue, forKey: Key.accent) }
    }

    public var textSize: HOneyTextSize {
        get { HOneyTextSize(rawValue: defaults.string(forKey: Key.textSize) ?? "") ?? .default }
        set { defaults.set(newValue.rawValue, forKey: Key.textSize) }
    }

    /// The Web boot rule: a saved choice wins; otherwise the system's dark
    /// preference picks Night, and Stone is the default.
    public func effectiveBackground(systemPrefersDark: Bool) -> HOneyBackground {
        background ?? (systemPrefersDark ? .night : .stone)
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

// MARK: - Reaction memory + deletion checklist (device-only state)

extension Preferences: ReactionMemory, DeletionChecklistStore {
    private enum V2Key {
        static let reactions = "honey.reactions.mine"
        static let reactors = "honey.reactor.registered"
        static let deletion = "honey.account-deletion"
        static let myPosts = "honey.posts.mine"
        static let noticesRead = "honey.notices.read"
    }

    private func dict(_ key: String) -> [String: Int] {
        guard let k = scoped(key), let data = defaults.data(forKey: k) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private func setDict(_ key: String, _ value: [String: Int]) {
        guard let k = scoped(key) else { return }
        defaults.set(try? JSONEncoder().encode(value), forKey: k)
    }

    /// The viewer's own reaction, remembered on this device (the feed carries none).
    public func myReaction(_ experienceId: String) -> Int {
        let v = dict(V2Key.reactions)[experienceId] ?? 0
        return v == 1 || v == -1 ? v : 0
    }

    public func setMyReaction(_ experienceId: String, _ value: Int) {
        var all = dict(V2Key.reactions)
        if value == 0 { all.removeValue(forKey: experienceId) } else { all[experienceId] = value }
        setDict(V2Key.reactions, all)
    }

    // The reader's own posts (Web: lib/community-v2 `myPosts`): the ids are
    // known on this device from the publish answer and the Mine listing —
    // never on the server. "Yours" is marked for the reader alone.
    public func isMyPost(_ experienceId: String) -> Bool { dict(V2Key.myPosts)[experienceId] == 1 }

    public func rememberMyPosts(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var all = dict(V2Key.myPosts)
        for id in ids { all[id] = 1 }
        setDict(V2Key.myPosts, all)
    }

    public func forgetMyPost(_ experienceId: String) {
        var all = dict(V2Key.myPosts)
        all.removeValue(forKey: experienceId)
        setDict(V2Key.myPosts, all)
    }

    // Which school notices this device has read (Web: lib/noticesRead.ts).
    // The portal has no per-student read flag; the fact lives here and is
    // never sent anywhere — nobody at school learns what a student opened.
    public func readNotices() -> Set<String> { Set(dict(V2Key.noticesRead).keys) }

    public func markNoticesRead(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var all = dict(V2Key.noticesRead)
        for id in ids { all[id] = 1 }
        // Bounded: the portal's own list is short and old ids can go.
        if all.count > 200 {
            for key in all.keys.sorted().prefix(all.count - 200) { all.removeValue(forKey: key) }
        }
        setDict(V2Key.noticesRead, all)
    }

    public func reactorRegistered(_ mark: String) -> Bool { dict(V2Key.reactors)[mark] == 1 }

    public func setReactorRegistered(_ mark: String) {
        var all = dict(V2Key.reactors)
        all[mark] = 1
        setDict(V2Key.reactors, all)
    }

    public func readChecklist() -> DeletionChecklist? {
        guard let k = scoped(V2Key.deletion), let data = defaults.data(forKey: k) else { return nil }
        return try? JSONDecoder().decode(DeletionChecklist.self, from: data)
    }

    public func writeChecklist(_ checklist: DeletionChecklist?) {
        guard let k = scoped(V2Key.deletion) else { return }
        if let checklist { defaults.set(try? JSONEncoder().encode(checklist), forKey: k) } else { defaults.removeObject(forKey: k) }
    }
}

// MARK: - Transfer bundle (Web → iPhone)

/// The versioned device bundle of private notes (post controls travel
/// through the Control Vault — pairing, passkey or recovery words — never a file).
public struct TransferBundle: Sendable, Equatable {
    public var accountHint: String?
    public var privateNotes: [PrivateNote]

    struct Wire: Decodable {
        var version: Int
        var accountHint: String?
        var privateNotes: [PrivateNote]?
    }

    public init(accountHint: String? = nil, privateNotes: [PrivateNote] = []) {
        self.accountHint = accountHint
        self.privateNotes = privateNotes
    }

    public static func decode(_ data: Data) throws -> TransferBundle {
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data), wire.version == 1 else {
            throw TransferBundleError.notABundle
        }
        return TransferBundle(accountHint: wire.accountHint, privateNotes: wire.privateNotes ?? [])
    }

    public struct ImportReport: Sendable, Equatable {
        public var notesAdded: Int
        public var failures: [String]
    }

    /// Writes notes to the note store; partial failures are reported, never hidden.
    public func apply(notes: PrivateNoteStore) async -> ImportReport {
        var report = ImportReport(notesAdded: 0, failures: [])
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

public enum TransferBundleError: Error, Sendable, Equatable {
    case notABundle
}
