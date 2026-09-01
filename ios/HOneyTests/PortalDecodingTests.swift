//
//  PortalDecodingTests.swift
//  HOneyTests — portal wire decoding, including the door-list quirk.
//

import XCTest
@testable import HOney

final class PortalDecodingTests: XCTestCase {

    @MainActor
    func testWebExpiryRouteUsesExactKnownLoginPaths() throws {
        XCTAssertTrue(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/login"))))
        XCTAssertTrue(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/student/login/"))))
        XCTAssertTrue(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/student#/login"))))

        XCTAssertFalse(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/student/login-history"))))
        XCTAssertFalse(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/student?next=login"))))
        XCTAssertFalse(PortalWebSessionBridge.isKnownLoginRoute(try XCTUnwrap(URL(string: "https://www.huayaopudong.com/student#/login-help"))))
    }

    func testDoorListQuirkSuccessIsStatus1WithDoorsInMessage() throws {
        let json = """
        {
          "status": 1,
          "message": [
            { "key": "front-gate", "value": "Front Gate" },
            { "key": "back-gate", "value": "Back Gate" }
          ],
          "data": {}
        }
        """.data(using: .utf8)!

        let response = try PortalCoding.decoder.decode(PortalDoorListResponse.self, from: json)
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.message.count, 2)
        XCTAssertEqual(response.message.first?.key, "front-gate")
        XCTAssertEqual(response.message.first?.displayName, "Front Gate")
    }

    func testDoorListNonSuccessStatus() throws {
        let json = #"{ "status": 0, "message": [], "data": {} }"#.data(using: .utf8)!
        let response = try PortalCoding.decoder.decode(PortalDoorListResponse.self, from: json)
        XCTAssertFalse(response.isSuccess)
    }

    func testLoginTokenTopLevel() throws {
        let json = #"{ "status": 0, "message": "ok", "token": "abc123" }"#.data(using: .utf8)!
        let response = try PortalCoding.decoder.decode(PortalLoginResponse.self, from: json)
        XCTAssertEqual(response.token, "abc123")
    }

    func testLoginTokenInsideDataBlock() throws {
        let json = """
        { "status": 0, "message": "ok", "data": { "access_token": "xyz789" } }
        """.data(using: .utf8)!
        let response = try PortalCoding.decoder.decode(PortalLoginResponse.self, from: json)
        XCTAssertEqual(response.token, "xyz789")
    }

    func testPermitRowDecoding() throws {
        let json = """
        {
          "status": 0,
          "data": {
            "rows": [
              {
                "record_id": 1000, "staff_name": "X", "status": 1, "status_name": "通过",
                "note": "Doctor", "flag": 0,
                "start_time": "2026-09-01 12:00:00", "end_time": "2026-09-01 14:00:00",
                "create_time": "2026-09-01 11:00:00"
              }
            ],
            "total": 1
          }
        }
        """.data(using: .utf8)!
        let response = try PortalCoding.decoder.decode(PortalPermitListResponse.self, from: json)
        let row = try XCTUnwrap(response.data?.rows.first)
        XCTAssertEqual(row.recordId, 1000)
        XCTAssertTrue(row.isApproved)
        XCTAssertEqual(row.statusName, "通过")
    }

    func testActionSuccessStatusZeroOrCode200() throws {
        let byStatus = try PortalCoding.decoder.decode(
            PortalActionResponse.self, from: #"{ "status": 0, "message": "done" }"#.data(using: .utf8)!)
        XCTAssertTrue(byStatus.isSuccess)

        let byCode = try PortalCoding.decoder.decode(
            PortalActionResponse.self, from: #"{ "code": 200, "message": "done" }"#.data(using: .utf8)!)
        XCTAssertTrue(byCode.isSuccess)

        let failure = try PortalCoding.decoder.decode(
            PortalActionResponse.self, from: #"{ "status": -1, "message": "no" }"#.data(using: .utf8)!)
        XCTAssertFalse(failure.isSuccess)
    }

    func testOpenDoorRequestUsesLowercaseIndexcodeEqualToDoorId() throws {
        let request = PortalOpenDoorRequest(recordId: -2, doorKey: "front-gate")
        let data = try PortalCoding.encoder.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(object["record_id"] as? Int, -2)
        XCTAssertEqual(object["door_id"] as? String, "front-gate")
        XCTAssertEqual(object["indexcode"] as? String, "front-gate")
        XCTAssertNil(object["index_code"], "The portal key is lowercase `indexcode`")
    }
}
