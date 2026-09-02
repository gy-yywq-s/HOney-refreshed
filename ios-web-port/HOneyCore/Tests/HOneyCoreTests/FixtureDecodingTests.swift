import XCTest
@testable import HOneyCore

/// Contract parity (port spec §4.1 / §28.1): every fixture the TypeScript
/// side pins to contract.ts decodes into the Swift DTOs, including the
/// additive fields and every enum value the server can send.
final class FixtureDecodingTests: XCTestCase {
    func testFixtureDirectoryIsCheckedIn() {
        XCTAssertGreaterThan(Fixtures.names.count, 20, "fixtures missing at \(Fixtures.directory.path)")
    }

    func testEveryFixtureDecodesIntoItsDTO() throws {
        let table: [String: (Data) throws -> Void] = [
            "login": { _ = try WireCoding.decode(LoginResponse.self, from: $0) },
            "session-refresh": { _ = try WireCoding.decode(SessionTokens.self, from: $0) },
            "me": { _ = try WireCoding.decode(Me.self, from: $0) },
            "me-disconnected": { _ = try WireCoding.decode(Me.self, from: $0) },
            "next-lesson-now": { _ = try WireCoding.decode(NextLessonResponse.self, from: $0) },
            "next-lesson-upcoming": { _ = try WireCoding.decode(NextLessonResponse.self, from: $0) },
            "next-lesson-none": { _ = try WireCoding.decode(NextLessonResponse.self, from: $0) },
            "timetable-day": { _ = try WireCoding.decode(TimetableResponse.self, from: $0) },
            "timetable-range": { _ = try WireCoding.decode(TimetableRangeResponse.self, from: $0) },
            "history": { _ = try WireCoding.decode(HistoryResponse.self, from: $0) },
            "directory": { _ = try WireCoding.decode(DirectoryResponse.self, from: $0) },
            "sync": { _ = try WireCoding.decode(SyncResponse.self, from: $0) },
            "sync-reconnect": { _ = try WireCoding.decode(SyncResponse.self, from: $0) },
            "portal-entry-ok": { _ = try WireCoding.decode(PortalEntryResponse.self, from: $0) },
            "portal-entry-reconnect": { _ = try WireCoding.decode(PortalEntryResponse.self, from: $0) },
            "entities": { _ = try WireCoding.decode(EntitiesResponse.self, from: $0) },
            "feed-page": { _ = try WireCoding.decode(FeedPage.self, from: $0) },
            "feed-page-end": { _ = try WireCoding.decode(FeedPage.self, from: $0) },
            "feed-updates": { _ = try WireCoding.decode(FeedUpdatesResponse.self, from: $0) },
            "from-my-classes": { _ = try WireCoding.decode(ExperiencesFeedResponse.self, from: $0) },
            "search": { _ = try WireCoding.decode(SearchResponse.self, from: $0) },
            "stats": { _ = try WireCoding.decode(EntityStats.self, from: $0) },
            "eligibility": { _ = try WireCoding.decode(ExperienceEligibilityResponse.self, from: $0) },
            "check-publish": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "check-nudge": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "check-cooldown": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "check-edit-required": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "check-out-of-scope": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "check-failed-closed": { _ = try WireCoding.decode(CheckExperienceResponse.self, from: $0) },
            "publish": { _ = try WireCoding.decode(PublishExperienceResponse.self, from: $0) },
            "mine": { _ = try WireCoding.decode(MyExperiencesResponse.self, from: $0) },
            "react": { _ = try WireCoding.decode(ReactResponse.self, from: $0) },
            "react-hidden": { _ = try WireCoding.decode(ReactResponse.self, from: $0) },
            "error": { _ = try WireCoding.decode(APIErrorBody.self, from: $0) },
        ]
        for name in Fixtures.names {
            guard let decode = table[name] else {
                XCTFail("fixture \(name).json has no Swift decode entry — add it to the table")
                continue
            }
            XCTAssertNoThrow(try decode(try Fixtures.data(name)), name)
        }
        for name in table.keys where !Fixtures.names.contains(name) {
            XCTFail("Swift expects fixture \(name).json but it is not checked in")
        }
    }

    func testValuesSurviveTheWire() throws {
        let me = try Fixtures.decode(Me.self, "me")
        XCTAssertEqual(me.displayName, "沈高远")
        XCTAssertTrue(me.connection.portalTokenValid)
        XCTAssertEqual(ISODate.parse(me.connection.lastSyncedAt)?.timeIntervalSince1970 ?? 0, 1788331246.298, accuracy: 0.001)

        let now = try Fixtures.decode(NextLessonResponse.self, "next-lesson-now")
        XCTAssertEqual(now.nextLesson?.temporalState, .now)
        XCTAssertEqual(now.nextLesson?.lesson.subjectName, "Activity")
        XCTAssertNil(now.nextLesson?.lesson.roomName)
        XCTAssertEqual(now.nextLesson?.lesson.startsAt, PinnedClock.ms("2026-09-02 16:30"))

        let none = try Fixtures.decode(NextLessonResponse.self, "next-lesson-none")
        XCTAssertNil(none.nextLesson)

        let entities = try Fixtures.decode(EntitiesResponse.self, "entities")
        XCTAssertEqual(entities.entities.count, 6, "additive fields must not break decoding")
        XCTAssertEqual(entities.entities[5].type, .dish)

        let page = try Fixtures.decode(FeedPage.self, "feed-page")
        XCTAssertEqual(page.items[0].myReaction, 1)
        XCTAssertNil(page.items[1].reactions, "hidden counts decode as nil")
        XCTAssertEqual(page.items[1].myReaction, 0)
        XCTAssertNil(page.items[2].myReaction, "absent myReaction stays absent")
        XCTAssertEqual(page.items[2].rating, 4)
        XCTAssertEqual(page.items[0].primary?.type, .lesson)
        XCTAssertNil(page.items[0].primary?.name)

        let mine = try Fixtures.decode(MyExperiencesResponse.self, "mine")
        XCTAssertEqual(mine.experiences.map(\.status), [.published, .blocked, .revoked])
        XCTAssertNil(mine.experiences[2].body)

        let cooldown = try Fixtures.decode(CheckExperienceResponse.self, "check-cooldown")
        XCTAssertEqual(cooldown.lane, .cooldown)
        XCTAssertEqual(cooldown.cooldown?.ticket, "cool_fixture")

        let entry = try Fixtures.decode(PortalEntryResponse.self, "portal-entry-ok")
        guard case .ok(let url, _) = entry else { return XCTFail("expected ok") }
        XCTAssertTrue(url.hasPrefix("https://www.huayaopudong.com/student/login?token="))
        XCTAssertEqual(try Fixtures.decode(PortalEntryResponse.self, "portal-entry-reconnect"), .reconnectRequired)
    }

    func testUnknownEnumValuesDecodeAsUnknown() throws {
        let lane = try WireCoding.decode(CheckExperienceResponse.self, from: json(["lane": "future_lane", "reasons": [], "policyVersion": 9]))
        XCTAssertEqual(lane.lane, .unknown("future_lane"))
        let entity = try WireCoding.decode(EntityRef.self, from: json(["entity_key": "club:x", "type": "club", "name": "Chess", "source": "admin"]))
        XCTAssertEqual(entity.type, .unknown("club"))
        let sync = try WireCoding.decode(SyncResponse.self, from: json(["status": "rate_limited", "lessons": 0, "teachers": 0, "courses": 0, "rooms": 0]))
        XCTAssertEqual(sync.status, .unknown("rate_limited"))
    }

    func testRequestBodiesMatchTheContractShape() throws {
        let check = try WireCoding.encode(CheckExperienceInput(lessonId: "L1", body: "words", cooldownTicket: "t"))
        let obj = try JSONSerialization.jsonObject(with: check) as! [String: Any]
        XCTAssertEqual(Set(obj.keys), ["lessonId", "body", "cooldownTicket"], "optional nils must be omitted, never sent as null")

        let publish = try WireCoding.encode(PublishExperienceInput(eligibilityToken: "e", pass: "p", body: "b", rating: 3))
        let pobj = try JSONSerialization.jsonObject(with: publish) as! [String: Any]
        XCTAssertEqual(Set(pobj.keys), ["eligibilityToken", "pass", "body", "rating"])

        let open = try WireCoding.encode(OpenDoorRequest(recordId: -2, doorKey: "door-front-01"))
        let oobj = try JSONSerialization.jsonObject(with: open) as! [String: Any]
        XCTAssertEqual(oobj["record_id"] as? Int, -2)
        XCTAssertEqual(oobj["status"] as? Int, 1)
        XCTAssertEqual(oobj["door_id"] as? String, "door-front-01")
        XCTAssertEqual(oobj["indexcode"] as? String, "door-front-01")
    }
}
