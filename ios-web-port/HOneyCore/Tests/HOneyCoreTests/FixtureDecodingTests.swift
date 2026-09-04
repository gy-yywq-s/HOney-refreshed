import XCTest
@testable import HOneyCore

/// Contract parity (port spec §4.1 / §28.1): every fixture the TypeScript
/// side pins to the contracts decodes into the Swift DTOs — the canonical
/// school data of the Core API and the identity-free Community v2 wire —
/// including the additive fields and every enum value the server can send.
final class FixtureDecodingTests: XCTestCase {
    func testFixtureDirectoryIsCheckedIn() {
        XCTAssertGreaterThan(Fixtures.names.count, 30, "fixtures missing at \(Fixtures.directory.path)")
    }

    func testEveryFixtureDecodesIntoItsDTO() throws {
        struct Updates: Decodable { let newItemsAvailable: Bool }
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
            "feed-page": { _ = try WireCoding.decode(FeedPageV2.self, from: $0) },
            "feed-page-end": { _ = try WireCoding.decode(FeedPageV2.self, from: $0) },
            "feed-updates": { _ = try WireCoding.decode(FeedUpdatesResponse.self, from: $0) },
            "from-my-classes": { _ = try WireCoding.decode(ExperiencesListV2.self, from: $0) },
            "search": { _ = try WireCoding.decode(SearchResponseV2.self, from: $0) },
            "stats": { _ = try WireCoding.decode(EntityStatsV2.self, from: $0) },
            "check-publish": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "check-nudge": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "check-cooldown": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "check-edit-required": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "check-out-of-scope": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "check-failed-closed": { _ = try WireCoding.decode(CheckResponseV2.self, from: $0) },
            "publish": { _ = try WireCoding.decode(PublishResponseV2.self, from: $0) },
            "challenge": { _ = try WireCoding.decode(ChallengeResponse.self, from: $0) },
            "mine": { _ = try WireCoding.decode(MineResponse.self, from: $0) },
            "react": { _ = try WireCoding.decode(ReactResponseV2.self, from: $0) },
            "react-hidden": { _ = try WireCoding.decode(ReactResponseV2.self, from: $0) },
            "issuer": { _ = try WireCoding.decode(IssuerDescriptor.self, from: $0) },
            "scope": { _ = try WireCoding.decode(CommunityScope.self, from: $0) },
            "eligibility-info": { _ = try WireCoding.decode(EligibilityInfoResponse.self, from: $0) },
            "eligibility-issued": { _ = try WireCoding.decode(EligibilityIssued.self, from: $0) },
            "vault-record": { _ = try WireCoding.decode(VaultRecord.self, from: $0) },
            "vault-put-ok": { _ = try WireCoding.decode(VaultPutResponse.self, from: $0) },
            "vault-put-conflict": { _ = try WireCoding.decode(VaultPutResponse.self, from: $0) },
            "pairing-offer": { _ = try WireCoding.decode(PairingOffer.self, from: $0) },
            "pairing-delivery": { _ = try WireCoding.decode(PairingDelivery.self, from: $0) },
            "error": { _ = try WireCoding.decode(APIErrorBody.self, from: $0) },
        ]
        _ = Updates.self
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

        // Canonical school data: the Course carries the title, the section is context only.
        let day = try Fixtures.decode(TimetableResponse.self, "timetable-day")
        let econ = day.lessons[1]
        XCTAssertEqual(econ.subjectName, "Economics")
        XCTAssertEqual(econ.courseName, "AL ECON U4")
        XCTAssertEqual(econ.classSectionName, "2026 Autumn · Prep Class")
        XCTAssertEqual(econ.title, "AL ECON U4")
        let range = try Fixtures.decode(TimetableRangeResponse.self, "timetable-range")
        let saturday = range.days[5].lessons[0]
        XCTAssertNil(saturday.courseName, "an unresolved label has no course")
        XCTAssertEqual(saturday.title, "Public Speaking")
        XCTAssertEqual(try Fixtures.decode(SyncResponse.self, "sync").unresolved, 1)

        let none = try Fixtures.decode(NextLessonResponse.self, "next-lesson-none")
        XCTAssertNil(none.nextLesson)

        let entities = try Fixtures.decode(EntitiesResponse.self, "entities")
        XCTAssertEqual(entities.entities.count, 6, "additive fields must not break decoding")
        XCTAssertEqual(entities.entities[5].type, .dish)
        XCTAssertEqual(entities.entities[2].name, "AL ECON U4")

        let page = try Fixtures.decode(FeedPageV2.self, "feed-page")
        XCTAssertEqual(page.items[0].reactions, ReactionCounts(likes: 3, dislikes: 1))
        XCTAssertNil(page.items[1].reactions, "hidden counts decode as nil")
        XCTAssertEqual(page.items[2].rating, 4)
        XCTAssertEqual(page.items[0].primary.type, .lesson)
        XCTAssertNil(page.items[0].primary.name, "names are null on the wire; clients join them")
        XCTAssertEqual(page.items[0].contexts.map(\.type), [.course, .teacher, .room])

        let mine = try Fixtures.decode(MineResponse.self, "mine")
        XCTAssertEqual(mine.experiences.map(\.status), [.published, .blocked])
        XCTAssertEqual(mine.experiences[1].statusDetail, "Re-checked under policy v7.")

        let cooldown = try Fixtures.decode(CheckResponseV2.self, "check-cooldown")
        XCTAssertEqual(cooldown.lane, .cooldown)
        XCTAssertEqual(cooldown.cooldown?.ticket, "cool_fixture")

        let vault = try Fixtures.decode(VaultRecord.self, "vault-record")
        XCTAssertEqual(vault.wrappers.map(\.stableId).count, 2)
        if case .passkeyPrf(let w) = vault.wrappers[1] { XCTAssertEqual(w.label, "Safari on iPhone") } else { XCTFail("passkey wrapper") }
        guard case .conflict(let current) = try Fixtures.decode(VaultPutResponse.self, "vault-put-conflict") else { return XCTFail("conflict") }
        XCTAssertEqual(current.revision, 3)
        guard case .ok(let revision, _) = try Fixtures.decode(VaultPutResponse.self, "vault-put-ok") else { return XCTFail("ok") }
        XCTAssertEqual(revision, 4)

        let info = try Fixtures.decode(EligibilityInfoResponse.self, "eligibility-info")
        XCTAssertEqual(info.info.scopeParts.type, "lesson")
        XCTAssertEqual(info.info.contexts.courseId, "c_al_econ_u4")

        let entry = try Fixtures.decode(PortalEntryResponse.self, "portal-entry-ok")
        guard case .ok(let url, _) = entry else { return XCTFail("expected ok") }
        XCTAssertTrue(url.hasPrefix("https://www.huayaopudong.com/student/login?token="))
        XCTAssertEqual(try Fixtures.decode(PortalEntryResponse.self, "portal-entry-reconnect"), .reconnectRequired)
    }

    func testUnknownEnumValuesDecodeAsUnknown() throws {
        let lane = try WireCoding.decode(CheckResponseV2.self, from: json(["lane": "future_lane", "reasons": [], "policyVersion": 9]))
        XCTAssertEqual(lane.lane, .unknown("future_lane"))
        let entity = try WireCoding.decode(EntityRef.self, from: json(["entity_key": "club:x", "type": "club", "name": "Chess", "source": "admin"]))
        XCTAssertEqual(entity.type, .unknown("club"))
        let sync = try WireCoding.decode(SyncResponse.self, from: json(["status": "rate_limited", "lessons": 0, "teachers": 0, "courses": 0, "rooms": 0]))
        XCTAssertEqual(sync.status, .unknown("rate_limited"))
    }

    func testRequestBodiesMatchTheContractShape() throws {
        let check = try WireCoding.encode(CheckRequestV2(
            token: EligibilityToken(keyId: "k", info: EligibilityInfo(schoolId: "s", academicYear: "y", scope: "lesson:L1", contexts: EligibilityContexts(lessonId: "L1"), provenance: "verified_lesson", week: 1), message: "m", signature: "s"),
            envelope: SignedPostEnvelopeV2(schoolId: "s", academicYear: "y", primaryEntity: EnvelopeEntity(type: "lesson", id: "L1"), contexts: EnvelopeContexts(lessonId: "L1"), body: "words", rating: nil, postNonce: "n", postingPublicKey: "p", controlPublicKey: "c", clientNonce: "cn"),
            postSignature: "sig"
        ))
        let obj = try JSONSerialization.jsonObject(with: check) as! [String: Any]
        XCTAssertEqual(Set(obj.keys), ["token", "envelope", "postSignature"], "optional nils must be omitted, never sent as null")
        let envelope = obj["envelope"] as! [String: Any]
        XCTAssertTrue(envelope["rating"] is NSNull, "the envelope's rating is always present (null) — it is signed that way")
        XCTAssertEqual(Set((envelope["contexts"] as! [String: Any]).keys), ["lessonId"])

        let feed = try WireCoding.encode(FeedRequestV2(scope: .myClasses, exposure: ExposureScope(teachers: ["t"], courses: [], lessons: []), limit: 20))
        let fobj = try JSONSerialization.jsonObject(with: feed) as! [String: Any]
        XCTAssertEqual(Set(fobj.keys), ["scope", "exposure", "limit"])
        XCTAssertEqual(fobj["scope"] as? String, "my_classes")

        let open = try WireCoding.encode(OpenDoorRequest(recordId: -2, doorKey: "door-front-01"))
        let oobj = try JSONSerialization.jsonObject(with: open) as! [String: Any]
        XCTAssertEqual(oobj["record_id"] as? Int, -2)
        XCTAssertEqual(oobj["status"] as? Int, 1)
        XCTAssertEqual(oobj["door_id"] as? String, "door-front-01")
        XCTAssertEqual(oobj["indexcode"] as? String, "door-front-01")
    }
}
