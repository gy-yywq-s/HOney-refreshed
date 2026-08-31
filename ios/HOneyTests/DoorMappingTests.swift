//
//  DoorMappingTests.swift
//  HOneyTests — Front/Back door keyword mapping and route record ids.
//

import XCTest
@testable import HOney

final class DoorMappingTests: XCTestCase {

    private let doors = [
        PortalDoor(key: "gate-a", value: "Front Gate"),
        PortalDoor(key: "gate-b", value: "Back Gate")
    ]

    func testFrontMatchesFrontKeyword() {
        let match = DoorMatcher.match(.front, in: doors)
        XCTAssertEqual(match?.value, "Front Gate")
    }

    func testBackMatchesBackKeyword() {
        let match = DoorMatcher.match(.back, in: doors)
        XCTAssertEqual(match?.value, "Back Gate")
    }

    func testChineseFrontKeyword() {
        let doors = [PortalDoor(key: "d1", value: "正门"), PortalDoor(key: "d2", value: "后门")]
        XCTAssertEqual(DoorMatcher.match(.front, in: doors)?.value, "正门")
        XCTAssertEqual(DoorMatcher.match(.back, in: doors)?.value, "后门")
    }

    func testOpaqueLabelsFallBackDeterministically() {
        let doors = [PortalDoor(key: "x1", value: "Door 1"), PortalDoor(key: "x2", value: "Door 2")]
        XCTAssertEqual(DoorMatcher.match(.front, in: doors)?.key, "x1")
        XCTAssertEqual(DoorMatcher.match(.back, in: doors)?.key, "x2")
    }

    func testEmptyDoorsReturnsNil() {
        XCTAssertNil(DoorMatcher.match(.front, in: []))
    }

    func testCommuterRouteRecordIdIsMinusTwo() {
        XCTAssertEqual(AccessRoute.commuter.recordId, -2)
    }

    func testPermitRouteRecordId() {
        XCTAssertEqual(AccessRoute.permit(recordId: 1000).recordId, 1000)
    }
}
