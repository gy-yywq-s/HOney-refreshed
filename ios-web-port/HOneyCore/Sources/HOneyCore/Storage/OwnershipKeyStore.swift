// Ownership keys — the ONLY proof of authorship for anonymous posts. The
// server keeps a hash; the key itself lives here (Keychain on iPhone,
// namespaced by HOney account and experience id) and nowhere else. The
// export/import format is the Web's own file shape, so a browser export
// imports here unchanged (spec §5.5).

import Foundation

public struct StoredOwnershipKey: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var key: String
    public var experienceId: String
    public var createdAt: Int64
    /// Reserved for future kinds; today every key controls a public submission.
    public var kind: String

    public var id: String { key }

    public init(key: String, experienceId: String, createdAt: Int64, kind: String = "public") {
        self.key = key
        self.experienceId = experienceId
        self.createdAt = createdAt
        self.kind = kind
    }

    var isValid: Bool { !key.isEmpty && !experienceId.isEmpty && kind == "public" }
}

/// The Web's export file: `{ version: 1, keys: [...] }`.
public struct OwnershipKeyExport: Codable, Sendable, Equatable {
    public var version: Int
    public var keys: [StoredOwnershipKey]
    public init(version: Int = 1, keys: [StoredOwnershipKey]) {
        self.version = version
        self.keys = keys
    }
}

public enum OwnershipKeyImportError: Error, Sendable, Equatable {
    case notAnExport
}

public protocol OwnershipKeyStoring: Sendable {
    func list() throws -> [StoredOwnershipKey]
    func add(key: String, experienceId: String) throws
    func remove(key: String) throws
}

public extension OwnershipKeyStoring {
    func count() -> Int { (try? list().count) ?? 0 }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(OwnershipKeyExport(keys: try list()))
    }

    /// Merge keys from an exported file (dedup by key). Returns how many were new.
    @discardableResult
    func importJSON(_ data: Data) throws -> Int {
        guard let parsed = try? JSONDecoder().decode(OwnershipKeyExport.self, from: data), parsed.version == 1 else {
            throw OwnershipKeyImportError.notAnExport
        }
        return try merge(parsed.keys)
    }

    @discardableResult
    func merge(_ incoming: [StoredOwnershipKey]) throws -> Int {
        let have = Set(try list().map(\.key))
        var added = 0
        for k in incoming where k.isValid && !have.contains(k.key) {
            try add(key: k.key, experienceId: k.experienceId)
            added += 1
        }
        return added
    }
}

/// One Keychain item per key under `<prefix>.<account>.<experienceId>`.
public final class SecretOwnershipKeyStore: OwnershipKeyStoring, @unchecked Sendable {
    private let store: SecretStore
    private let prefix: String
    private let lock = NSLock()
    private var account: String

    public init(store: SecretStore, account: String, prefix: String = "honey.keys") {
        self.store = store
        self.account = account
        self.prefix = prefix
    }

    public func setAccount(_ account: String) {
        lock.lock(); defer { lock.unlock() }
        self.account = account
    }

    private var namespace: String {
        let safe = account.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return "\(prefix).\(safe)."
    }

    public func list() throws -> [StoredOwnershipKey] {
        lock.lock(); defer { lock.unlock() }
        var out: [StoredOwnershipKey] = []
        for name in try store.keys(withPrefix: namespace) {
            guard let data = try store.read(name), let k = try? JSONDecoder().decode(StoredOwnershipKey.self, from: data), k.isValid else { continue }
            out.append(k)
        }
        return out.sorted { $0.createdAt < $1.createdAt }
    }

    public func add(key: String, experienceId: String) throws {
        lock.lock(); defer { lock.unlock() }
        let entry = StoredOwnershipKey(key: key, experienceId: experienceId, createdAt: HOneyClock.now().epochMillis)
        try store.write(namespace + experienceId, try JSONEncoder().encode(entry))
    }

    public func remove(key: String) throws {
        let entries = try list()
        lock.lock(); defer { lock.unlock() }
        for e in entries where e.key == key {
            try store.delete(namespace + e.experienceId)
        }
    }
}
