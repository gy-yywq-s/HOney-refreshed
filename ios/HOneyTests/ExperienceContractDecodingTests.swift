//
//  ExperienceContractDecodingTests.swift
//  HOneyTests — wire-contract fixtures for the Experiences objects, matching
//  packages/shared/src/api/contract.ts exactly (snake_case fields, nullable
//  reactions, every check lane), decoded through HOneyCoding.
//

import XCTest
@testable import HOney

final class ExperienceContractDecodingTests: XCTestCase {

    func testTargetNamingUsesEntityAndLessonContextWithoutExposingRawKeys() {
        let names = [
            "teacher:t1": "Ms Lin",
            "course:c1": "Mathematics",
            "dish:d1": "Braised tofu"
        ]
        let dish = PublicExperience(
            id: "e1", entityKey: "dish:d1", ctxTeacherId: nil, ctxCourseId: nil,
            ctxRoomId: nil, body: "Good", rating: 4, provenance: .verifiedMember,
            publishedDay: nil, reactions: nil
        )
        let lesson = PublicExperience(
            id: "e2", entityKey: "lesson:opaque", ctxTeacherId: "t1", ctxCourseId: "c1",
            ctxRoomId: nil, body: "Clear", rating: nil, provenance: .verifiedLesson,
            publishedDay: nil, reactions: nil
        )

        XCTAssertEqual(ExperienceTargetNaming.label(for: dish, names: names), "Braised tofu")
        XCTAssertEqual(ExperienceTargetNaming.label(for: lesson, names: names), "Lesson · Mathematics · Ms Lin")

        let unresolvedCases = [
            ("teacher:missing", "Teacher"),
            ("room:missing", "Place"),
            ("dish:missing", "Dish"),
            ("unknown:opaque", "School experience")
        ]
        for (entityKey, expected) in unresolvedCases {
            let experience = PublicExperience(
                id: entityKey, entityKey: entityKey, ctxTeacherId: "t1", ctxCourseId: "c1",
                ctxRoomId: nil, body: "Body", rating: nil, provenance: .verifiedMember,
                publishedDay: nil, reactions: nil
            )
            let label = ExperienceTargetNaming.label(for: experience, names: names)
            XCTAssertEqual(label, expected)
            XCTAssertFalse(label.contains(entityKey))
        }

        let normalized = ExperienceTargetNaming.names(
            directory: DirectoryResponse(
                teachers: [DirectoryEntry(id: "blank", name: "  ")], courses: [], rooms: []
            ),
            entities: nil
        )
        XCTAssertNil(normalized["teacher:blank"])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try HOneyCoding.decoder.decode(T.self, from: Data(json.utf8))
    }

    // MARK: PublicExperience

    func testPublicExperienceDecodesSnakeCaseWireShape() throws {
        let json = """
        {
          "id": "e1",
          "entity_key": "teacher:t9",
          "ctx_teacher_id": "t9",
          "ctx_course_id": "c3",
          "ctx_room_id": null,
          "body": "A calm, precise lesson.",
          "rating": null,
          "provenance": "verified_lesson",
          "publishedDay": 20696,
          "reactions": { "likes": 4, "dislikes": 1 }
        }
        """
        let exp = try decode(PublicExperience.self, json)
        XCTAssertEqual(exp.id, "e1")
        XCTAssertEqual(exp.entityKey, "teacher:t9")
        XCTAssertEqual(exp.ctxTeacherId, "t9")
        XCTAssertEqual(exp.ctxCourseId, "c3")
        XCTAssertNil(exp.ctxRoomId)
        XCTAssertEqual(exp.body, "A calm, precise lesson.")
        XCTAssertNil(exp.rating)
        XCTAssertEqual(exp.provenance, .verifiedLesson)
        XCTAssertEqual(exp.publishedDay, 20696)
        XCTAssertEqual(exp.reactions, ReactionCounts(likes: 4, dislikes: 1))
    }

    func testPublicExperienceNullReactionsMeansHidden() throws {
        let json = """
        {
          "id": "e2",
          "entity_key": "dish:d1",
          "ctx_teacher_id": null,
          "ctx_course_id": null,
          "ctx_room_id": null,
          "body": "Salty but honest.",
          "rating": 4,
          "provenance": "verified_member",
          "publishedDay": null,
          "reactions": null
        }
        """
        let exp = try decode(PublicExperience.self, json)
        XCTAssertNil(exp.reactions, "reactions: null means counts are hidden")
        XCTAssertNil(exp.publishedDay)
        XCTAssertEqual(exp.rating, 4)
    }

    func testProvenanceDecodesAllContractValuesAndFallsBack() throws {
        func provenance(_ raw: String) throws -> ExperienceProvenance {
            try decode(ExperienceProvenance.self, "\"\(raw)\"")
        }
        XCTAssertEqual(try provenance("verified_lesson"), .verifiedLesson)
        XCTAssertEqual(try provenance("verified_retrospective"), .verifiedRetrospective)
        XCTAssertEqual(try provenance("verified_member"), .verifiedMember)
        // Unknown future values degrade like the web label fallback.
        XCTAssertEqual(try provenance("verified_alumni"), .verifiedMember)
    }

    func testExperiencesFeedResponseDecodes() throws {
        let json = """
        { "experiences": [ { "id": "e1", "entity_key": "room:r2", "ctx_teacher_id": null,
          "ctx_course_id": null, "ctx_room_id": "r2", "body": "quiet in the afternoon",
          "rating": null, "provenance": "verified_retrospective", "publishedDay": 20700,
          "reactions": null } ] }
        """
        let feed = try decode(ExperiencesFeedResponse.self, json)
        XCTAssertEqual(feed.experiences.count, 1)
        XCTAssertEqual(feed.experiences.first?.entityKey, "room:r2")
    }

    // MARK: MyExperience

    func testMyExperienceDecodesFullWireShape() throws {
        let json = """
        {
          "id": "m1",
          "entity_key": "lesson:opaque-token",
          "lesson_id": "opaque-token",
          "ctx_teacher_id": "t1",
          "ctx_course_id": "c1",
          "ctx_room_id": "r1",
          "body": "My own words.",
          "rating": null,
          "provenance": "verified_lesson",
          "status": "blocked",
          "status_detail": "Hidden after re-evaluation",
          "policy_version": 3,
          "created_at": 1756700000000,
          "published_at": 1756700001000
        }
        """
        let mine = try decode(MyExperience.self, json)
        XCTAssertEqual(mine.entityKey, "lesson:opaque-token")
        XCTAssertEqual(mine.lessonId, "opaque-token")
        XCTAssertEqual(mine.status, .blocked)
        XCTAssertEqual(mine.statusDetail, "Hidden after re-evaluation")
        XCTAssertEqual(mine.policyVersion, 3)
        XCTAssertEqual(mine.createdAt, 1_756_700_000_000)
        XCTAssertEqual(mine.publishedAt, 1_756_700_001_000)
    }

    func testMyExperienceRevokedRowWithNullBody() throws {
        let json = """
        {
          "id": "m2", "entity_key": "teacher:t2", "lesson_id": null,
          "ctx_teacher_id": "t2", "ctx_course_id": null, "ctx_room_id": null,
          "body": null, "rating": null, "provenance": "verified_member",
          "status": "revoked", "status_detail": null, "policy_version": 2,
          "created_at": 1756000000000, "published_at": null
        }
        """
        let mine = try decode(MyExperience.self, json)
        XCTAssertEqual(mine.status, .revoked)
        XCTAssertNil(mine.body)
        XCTAssertNil(mine.publishedAt)
    }

    // MARK: EntityRef

    func testEntityRefDecodes() throws {
        let json = """
        { "entities": [
          { "entity_key": "teacher:t1", "type": "teacher", "name": "Ms Lin", "source": "organic" },
          { "entity_key": "dish:d7", "type": "dish", "name": "Braised tofu", "source": "admin" }
        ] }
        """
        let response = try decode(EntitiesResponse.self, json)
        XCTAssertEqual(response.entities.count, 2)
        XCTAssertEqual(response.entities[0].entityKey, "teacher:t1")
        XCTAssertEqual(response.entities[0].type, .teacher)
        XCTAssertEqual(response.entities[0].source, .organic)
        XCTAssertEqual(response.entities[1].source, .admin)
    }

    // MARK: Eligibility / check / publish

    func testEligibilityResponseDecodes() throws {
        let json = """
        { "ok": true, "eligibilityToken": "tok-abc", "expiresAt": 1756700600000 }
        """
        let response = try decode(ExperienceEligibilityResponse.self, json)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.eligibilityToken, "tok-abc")
        XCTAssertEqual(response.expiresAt, 1_756_700_600_000)
    }

    func testCheckResponsePublishLaneCarriesPass() throws {
        let json = """
        { "lane": "publish", "reasons": [], "policyVersion": 3, "pass": "pass-1" }
        """
        let response = try decode(CheckExperienceResponse.self, json)
        XCTAssertEqual(response.lane, .publish)
        XCTAssertEqual(response.pass, "pass-1")
        XCTAssertNil(response.cooldown)
    }

    func testCheckResponseNudgeLaneCarriesPassAndReasons() throws {
        let json = """
        { "lane": "nudge", "reasons": ["Consider adding when this happened"],
          "policyVersion": 3, "pass": "pass-2" }
        """
        let response = try decode(CheckExperienceResponse.self, json)
        XCTAssertEqual(response.lane, .nudge)
        XCTAssertEqual(response.reasons, ["Consider adding when this happened"])
        XCTAssertEqual(response.pass, "pass-2")
    }

    func testCheckResponseCooldownLaneCarriesTicket() throws {
        let json = """
        { "lane": "cooldown", "reasons": ["Very heated wording"], "policyVersion": 3,
          "cooldown": { "ticket": "cd-1", "retryAt": 1756704000000 } }
        """
        let response = try decode(CheckExperienceResponse.self, json)
        XCTAssertEqual(response.lane, .cooldown)
        XCTAssertNil(response.pass)
        XCTAssertEqual(response.cooldown, CheckCooldown(ticket: "cd-1", retryAt: 1_756_704_000_000))
    }

    func testCheckResponseKeepDraftLanesDecode() throws {
        let lanes: [(String, CheckLane)] = [
            ("edit_required", .editRequired),
            ("out_of_scope", .outOfScope),
            ("blocked_serious", .blockedSerious),
            ("failed_closed", .failedClosed)
        ]
        for (raw, expected) in lanes {
            let json = """
            { "lane": "\(raw)", "reasons": ["reason"], "policyVersion": 1 }
            """
            let response = try decode(CheckExperienceResponse.self, json)
            XCTAssertEqual(response.lane, expected)
            XCTAssertNil(response.pass, "no pass for lane \(raw)")
        }
    }

    func testPublishResponseDecodes() throws {
        let json = """
        { "ok": true, "experienceId": "e9", "ownershipKey": "own-9" }
        """
        let response = try decode(PublishExperienceResponse.self, json)
        XCTAssertTrue(response.ok)
        XCTAssertEqual(response.experienceId, "e9")
        XCTAssertEqual(response.ownershipKey, "own-9")
    }

    // MARK: Request encoding

    func testCheckRequestEncodesCamelCaseAndOmitsNils() throws {
        let request = CheckExperienceRequest(
            lessonId: "l1", entityKey: nil, body: "text", rating: nil, cooldownTicket: nil
        )
        let object = try encodeToObject(request)
        XCTAssertEqual(object["lessonId"] as? String, "l1")
        XCTAssertEqual(object["body"] as? String, "text")
        XCTAssertNil(object["entityKey"], "nil optionals are omitted from the wire")
        XCTAssertNil(object["cooldownTicket"])
    }

    func testCheckRequestEncodesCooldownTicketWhenPresent() throws {
        let request = CheckExperienceRequest(
            lessonId: nil, entityKey: "dish:d1", body: "text", rating: 5, cooldownTicket: "cd-1"
        )
        let object = try encodeToObject(request)
        XCTAssertEqual(object["entityKey"] as? String, "dish:d1")
        XCTAssertEqual(object["rating"] as? Int, 5)
        XCTAssertEqual(object["cooldownTicket"] as? String, "cd-1")
    }

    func testReportRequestEncodesCategoryOnly() throws {
        let object = try encodeToObject(ReportExperienceRequest(category: .notExperience))
        XCTAssertEqual(object["category"] as? String, "not_experience")
        XCTAssertEqual(object.count, 1, "reports are category-only: no free text on the wire")
    }

    private func encodeToObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try HOneyCoding.encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
