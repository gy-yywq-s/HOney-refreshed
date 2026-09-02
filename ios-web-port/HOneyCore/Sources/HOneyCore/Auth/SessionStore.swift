// Where the HOney session lives. The app supplies a Keychain-backed store;
// the package ships an in-memory one for tests and previews. The API client
// only ever sees this protocol — Views never touch tokens.

import Foundation

public protocol SessionStoring: Sendable {
    func load() throws -> SessionTokens?
    func save(_ tokens: SessionTokens) throws
    func clear() throws
}

public final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: SessionTokens?

    public init(_ tokens: SessionTokens? = nil) {
        self.tokens = tokens
    }

    public func load() throws -> SessionTokens? {
        lock.lock(); defer { lock.unlock() }
        return tokens
    }

    public func save(_ tokens: SessionTokens) throws {
        lock.lock(); defer { lock.unlock() }
        self.tokens = tokens
    }

    public func clear() throws {
        lock.lock(); defer { lock.unlock() }
        tokens = nil
    }
}

/// Generic secret slot used by the Keychain-backed stores (session, school
/// credentials, ownership keys). Kept abstract so the package can be tested
/// without the Security framework.
public protocol SecretStore: Sendable {
    func read(_ key: String) throws -> Data?
    func write(_ key: String, _ data: Data) throws
    func delete(_ key: String) throws
    /// Every stored key with the given prefix (ownership keys are namespaced).
    func keys(withPrefix prefix: String) throws -> [String]
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    /// Set to make every write fail, to exercise the partial-failure paths.
    public var failWrites = false

    public init() {}

    public func read(_ key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return items[key]
    }

    public func write(_ key: String, _ data: Data) throws {
        lock.lock(); defer { lock.unlock() }
        if failWrites { throw SecretStoreError.writeFailed }
        items[key] = data
    }

    public func delete(_ key: String) throws {
        lock.lock(); defer { lock.unlock() }
        items.removeValue(forKey: key)
    }

    public func keys(withPrefix prefix: String) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        return items.keys.filter { $0.hasPrefix(prefix) }.sorted()
    }
}

public enum SecretStoreError: Error, Sendable, Equatable {
    case writeFailed
    case unavailable
}

/// A session store on top of any SecretStore (the app passes the Keychain).
public final class SecretSessionStore: SessionStoring, @unchecked Sendable {
    private let store: SecretStore
    private let key: String

    public init(store: SecretStore, key: String = "honey.session") {
        self.store = store
        self.key = key
    }

    public func load() throws -> SessionTokens? {
        guard let data = try store.read(key) else { return nil }
        return try? WireCoding.decode(SessionTokens.self, from: data)
    }

    public func save(_ tokens: SessionTokens) throws {
        try store.write(key, try WireCoding.encode(tokens))
    }

    public func clear() throws {
        try store.delete(key)
    }
}
