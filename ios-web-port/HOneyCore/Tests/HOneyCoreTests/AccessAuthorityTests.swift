import XCTest
@testable import HOneyCore

/// Review 11d42e3 §3.5: stale permit data is never authority for a physical action.
final class AccessAuthorityTests: XCTestCase {
    func approved(_ id: Int) -> ExitPermitWire {
        ExitPermitWire(recordId: id, status: 1, statusName: "通过", flag: 0, startTime: "2026-09-02 08:00:00", endTime: "2026-09-02 22:00:00")
    }

    func testFreshReadAuthorisesThenFailureWithdrawsButKeepsTheList() {
        PinnedClock.at("2026-09-02T09:00:00Z") {
            var a = AccessAuthority()
            XCTAssertEqual(a.openable(), [])
            a.permitsLoaded([approved(1)])
            a.doorsLoaded([PortalDoor(key: "d1", value: "Front")])
            XCTAssertEqual(a.openable().map(\.recordId), [1])
            XCTAssertTrue(a.permitRouteAvailable)
            a.permitsFailed("offline")
            XCTAssertEqual(a.permits.count, 1, "cached permits stay visible")
            XCTAssertEqual(a.openable(), [], "…but nothing is openable")
            XCTAssertFalse(a.permitRouteAvailable)
            XCTAssertTrue(a.commuterRouteAvailable, "the day-student route only needs doors")
            XCTAssertEqual(a.staleMessage, "offline")
            a.permitsLoaded([approved(1)])
            XCTAssertTrue(a.permitRouteAvailable)
        }
    }

    func testOpenAttemptWithdrawsAuthorityUntilAFreshRead() {
        PinnedClock.at("2026-09-02T09:00:00Z") {
            var a = AccessAuthority()
            a.permitsLoaded([approved(1)])
            a.doorsLoaded([PortalDoor(key: "d1", value: "Front")])
            a.openAttempted()
            XCTAssertEqual(a.openable(), [], "the same permit cannot be reused before the portal confirms")
            XCTAssertNotNil(a.staleMessage)
            a.permitsFailed("timeout")
            XCTAssertEqual(a.openable(), [])
            a.permitsLoaded([ExitPermitWire(recordId: 1, status: 1, statusName: "通过", flag: 1, startTime: "2026-09-02 08:00:00", endTime: "2026-09-02 22:00:00")])
            XCTAssertEqual(a.openable(), [], "confirmed consumed")
            XCTAssertNil(a.staleMessage)
        }
    }

    func testDoorsGateBothRoutes() {
        PinnedClock.at("2026-09-02T09:00:00Z") {
            var a = AccessAuthority()
            a.permitsLoaded([approved(1)])
            XCTAssertFalse(a.permitRouteAvailable, "no door list yet")
            XCTAssertFalse(a.commuterRouteAvailable)
            a.doorsLoaded([])
            XCTAssertFalse(a.commuterRouteAvailable, "an empty list is not a gate")
            a.doorsLoaded([PortalDoor(key: "d", value: "Gate")])
            XCTAssertTrue(a.commuterRouteAvailable)
            a.doorsFailed()
            XCTAssertFalse(a.permitRouteAvailable)
            a.reset()
            XCTAssertEqual(a, AccessAuthority())
        }
    }
}
