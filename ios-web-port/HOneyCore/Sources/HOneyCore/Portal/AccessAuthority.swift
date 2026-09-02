// Who may open a gate right now (review 11d42e3 §3.5): cached permits may
// stay visible after a failed refresh, but a permit-based physical action
// is authorised only by the latest successful read — and after any open
// attempt the authority is withdrawn until a fresh read confirms what the
// portal now says. The day-student route depends only on the door list.

import Foundation

public struct AccessAuthority: Sendable, Equatable {
    public enum Freshness: Sendable, Equatable {
        case never
        case fresh
        case stale(String)
    }

    public private(set) var permits: [ExitPermit] = []
    public private(set) var permitFreshness: Freshness = .never
    public private(set) var doors: [PortalDoor] = []
    public private(set) var doorsFresh = false
    /// A gate open was attempted since the last successful permit read.
    public private(set) var awaitingPostActionRead = false

    public init() {}

    // MARK: Events

    public mutating func permitsLoaded(_ rows: [ExitPermitWire]) {
        permits = rows.map(ExitPermit.init)
        permitFreshness = .fresh
        awaitingPostActionRead = false
    }

    public mutating func permitsFailed(_ message: String) {
        permitFreshness = .stale(message)
    }

    public mutating func doorsLoaded(_ list: [PortalDoor]) {
        doors = list
        doorsFresh = true
    }

    public mutating func doorsFailed() {
        doorsFresh = false
    }

    /// Whatever the portal answered, the permit list is unknown until re-read.
    public mutating func openAttempted() {
        awaitingPostActionRead = true
    }

    public mutating func reset() {
        self = AccessAuthority()
    }

    // MARK: Authority

    public var permitsUsable: Bool {
        permitFreshness == .fresh && !awaitingPostActionRead
    }

    public var staleMessage: String? {
        if case .stale(let m) = permitFreshness { return m }
        return awaitingPostActionRead ? "The last gate request has not been confirmed by the portal yet. Refresh before using a permit again." : nil
    }

    /// Permits that may open a gate now: only from a fresh read.
    public func openable(now: Date = HOneyClock.now()) -> [ExitPermit] {
        guard permitsUsable else { return [] }
        return ExitPermit.openable(permits, now: now)
    }

    public func mayUse(_ permit: ExitPermit, now: Date = HOneyClock.now()) -> Bool {
        permitsUsable && permit.isOpenable(now: now)
    }

    /// Day students need no permit: only a current door list.
    public var commuterRouteAvailable: Bool { doorsFresh && !doors.isEmpty }

    public var permitRouteAvailable: Bool { doorsFresh && !doors.isEmpty && permitsUsable }
}
