// What a screen already knows, kept for the life of the process.
//
// Gary 2026-09-04: 很多页面点进去都要加载，再点进去又要加载. A pushed screen's
// @State dies when it is popped and a tab's `.task` runs again on every
// re-appearance, so each visit started from an empty screen even when the
// answer from thirty seconds ago was still on hand. Two small pieces fix that
// without a disk cache: a gate that says whether a load is even due, and an
// in-memory box holding the last answer so the screen paints immediately and
// refreshes behind what the student is already reading.
//
// Nothing here is persisted: it lives and dies with the process, and an
// account change clears it (`clear()`), so no answer for one student can ever
// be shown to another.

import Foundation

/// "Has this been loaded recently enough to skip the network?"
@MainActor
public final class LoadGate {
    private var lastLoaded: Date?
    private let maxAge: TimeInterval

    public init(maxAge: TimeInterval = 90) {
        self.maxAge = maxAge
    }

    /// True while the last load is young enough that re-entering the screen
    /// should show what is already there instead of loading again.
    public var isFresh: Bool {
        guard let lastLoaded else { return false }
        return HOneyClock.now().timeIntervalSince(lastLoaded) < maxAge
    }

    public func markLoaded() { lastLoaded = HOneyClock.now() }
    public func invalidate() { lastLoaded = nil }
}

/// The last answer each screen showed, by key.
@MainActor
public final class ScreenCache {
    private struct Entry {
        let value: Any
        let at: Date
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    /// The cached value for `key`, if one was stored within `maxAge`.
    public func value<T>(_ key: String, maxAge: TimeInterval = 300) -> T? {
        guard let entry = entries[key], HOneyClock.now().timeIntervalSince(entry.at) < maxAge else { return nil }
        return entry.value as? T
    }

    public func put<T>(_ value: T, for key: String) {
        entries[key] = Entry(value: value, at: HOneyClock.now())
    }

    public func drop(_ key: String) { entries[key] = nil }

    /// Sign-out and account change: nothing survives.
    public func clear() { entries.removeAll() }
}
