import XCTest
@testable import HOneyCore

final class PortalAPITests: XCTestCase {
    let base = URL(string: "https://portal.example")!

    func testLoginParsesEitherTokenShapeAndRejects401() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":0,"message":"ok","token":"tok1"}"#)
        t.enqueue(status: 200, json: #"{"status":0,"data":{"token":"tok2"}}"#)
        t.enqueue(status: 401, json: #"{"message":"invalid username or password"}"#)
        t.enqueue { _ in HTTPResponse(status: 200, body: Data("<html>系统维护中</html>".utf8)) }
        let api = PortalAPI(baseURL: base, transport: t)
        let tok1 = try await api.login(PortalCredentials(username: "u", password: "p"))
        XCTAssertEqual(tok1, "tok1")
        let tok2 = try await api.login(PortalCredentials(username: "u", password: "p"))
        XCTAssertEqual(tok2, "tok2")
        await XCTAssertThrowsPortal(.credentialsRejected) { _ = try await api.login(PortalCredentials(username: "u", password: "p")) }
        await XCTAssertThrowsPortal(.serverUnavailable(httpStatus: 200)) { _ = try await api.login(PortalCredentials(username: "u", password: "p")) }
        let first = t.request(at: 0)
        XCTAssertNil(first.headers["Authorization"])
        XCTAssertEqual(first.url.path, "/api/login")
    }

    func testRawTokenHeaderAndIdentity() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":0,"data":{"id":12345,"name":"沈高远","type":1,"exp":1788422247,"day_student":0}}"#)
        let api = PortalAPI(baseURL: base, transport: t)
        let identity = try await api.identity(token: "raw-token")
        XCTAssertEqual(identity.studentId, "12345")
        XCTAssertEqual(identity.isDayStudent, false)
        XCTAssertEqual(identity.tokenExpiresAt.timeIntervalSince1970, 1788422247)
        XCTAssertEqual(t.request(at: 0).headers["Authorization"], "raw-token", "no Bearer prefix")
    }

    func testDoorListQuirkAndDegradedList() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":1,"message":[{"key":"door-front-01","value":"正门 Front Gate"},{"key":"door-back-02","value":"后门 Back Gate"}],"data":{}}"#)
        t.enqueue(status: 200, json: #"{"status":0,"message":"degraded","data":{}}"#)
        let api = PortalAPI(baseURL: base, transport: t)
        let doors = try await api.doors(token: "t")
        XCTAssertEqual(doors.map(\.displayName), ["正门 Front Gate", "后门 Back Gate"])
        await XCTAssertThrowsPortal(.serverUnavailable(httpStatus: nil)) { _ = try await api.doors(token: "t") }
    }

    func testPermitsAndExpiryEnvelope() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":0,"message":"ok","data":{"rows":[{"record_id":501,"staff_id":9,"staff_name":"Mr Approver","status":1,"status_name":"通过","note":"出门","flag":0,"start_time":"2026-09-02 08:00:00","end_time":"2026-09-02 22:00:00","create_time":"2026-09-01 12:00:00","update_time":"2026-09-01 13:00:00"}],"total":1}}"#)
        t.enqueue(status: 401, json: #"{"status":400001,"message":"Unauthorized"}"#)
        t.enqueue(status: 401, json: #"{"message":"proxy"}"#)
        t.enqueue(status: 502, json: "{}")
        let api = PortalAPI(baseURL: base, transport: t)
        let rows = try await api.permits(token: "t")
        XCTAssertEqual(rows.first?.recordId, 501)
        XCTAssertEqual(rows.first?.flag, 0)
        await XCTAssertThrowsPortal(.sessionExpired) { _ = try await api.permits(token: "t") }
        await XCTAssertThrowsPortal(.serverUnavailable(httpStatus: 401)) { _ = try await api.permits(token: "t") }
        await XCTAssertThrowsPortal(.serverUnavailable(httpStatus: 502)) { _ = try await api.permits(token: "t") }
    }

    func testOpenDoorSuccessRuleAndRefusal() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":0,"message":"ok","data":{}}"#)
        t.enqueue(status: 200, json: #"{"code":200,"message":"opened"}"#)
        t.enqueue(status: 200, json: #"{"status":1,"message":"该出门条已使用","data":{}}"#)
        t.enqueue { _ in throw APIError.networkError }
        let api = PortalAPI(baseURL: base, transport: t)
        let ok = try await api.openDoor(token: "t", recordId: 501, doorKey: "door-front-01")
        XCTAssertEqual(ok.message, "ok")
        let opened = try await api.openDoor(token: "t", recordId: -2, doorKey: "door-front-01")
        XCTAssertEqual(opened.message, "opened")
        await XCTAssertThrowsPortal(.operationRejected(endpoint: "/api/exit/update_door_flag", status: 1, message: "该出门条已使用")) {
            _ = try await api.openDoor(token: "t", recordId: 501, doorKey: "door-front-01")
        }
        await XCTAssertThrowsPortal(.timeout(outcomeUnknown: true)) { _ = try await api.openDoor(token: "t", recordId: 501, doorKey: "door-front-01") }
        let body = try JSONSerialization.jsonObject(with: t.request(at: 1).body!) as! [String: Any]
        XCTAssertEqual(body["record_id"] as? Int, -2, "commuter sentinel")
        XCTAssertEqual(t.request(at: 0).url.path, "/api/exit/update_door_flag")
    }

    func testAddPermitBody() async throws {
        let t = ScriptedTransport()
        t.enqueue(status: 200, json: #"{"status":0,"message":"ok","data":{}}"#)
        let api = PortalAPI(baseURL: base, transport: t)
        _ = try await api.addPermit(token: "t", AddPermitRequest(startTime: "2026-09-02 17:00:00", endTime: "2026-09-02 19:00:00", note: "出门"))
        let body = try JSONSerialization.jsonObject(with: t.request(at: 0).body!) as! [String: String]
        XCTAssertEqual(body, ["start_time": "2026-09-02 17:00:00", "end_time": "2026-09-02 19:00:00", "note": "出门"])
    }
}

final class PortalSessionCoordinatorTests: XCTestCase {
    final class FakeAuth: PortalAuthAPI, @unchecked Sendable {
        var loginResult: Result<String, PortalError> = .success("tok")
        var loginDelayNs: UInt64 = 0
        private(set) var logins = 0
        private(set) var logouts = 0
        var exp: Date = Date().addingTimeInterval(3600)
        var identityName = ""
        var studentId = "1"

        func login(_ credentials: PortalCredentials) async throws -> String {
            logins += 1
            if loginDelayNs > 0 { try await Task.sleep(nanoseconds: loginDelayNs) }
            return try loginResult.get()
        }

        func identity(token: String) async throws -> PortalIdentity {
            PortalIdentity(studentId: studentId, name: identityName, isDayStudent: nil, tokenExpiresAt: exp)
        }

        func logout(token: String) async { logouts += 1 }
    }

    func make(creds: Bool = true, saved: PortalSession? = nil, expectedName: String? = nil) -> (PortalSessionCoordinator, FakeAuth, SecretPortalVault) {
        let vault = SecretPortalVault(store: InMemorySecretStore())
        vault.setAccount("h_1", expectedName: expectedName)
        if creds { try? vault.saveCredentials(PortalCredentials(username: "u", password: "p")) }
        if let saved { try? vault.saveSession(saved) }
        let auth = FakeAuth()
        return (PortalSessionCoordinator(api: auth, sessions: vault, credentials: vault, binding: vault), auth, vault)
    }

    func testIdentityMismatchNeverBecomesASession() async {
        let (c, auth, vault) = make(expectedName: "沈高远")
        auth.identityName = "王某某"
        let state = await c.restore()
        XCTAssertEqual(state, .userActionRequired(.unknown))
        XCTAssertFalse(vault.hasCredentials, "a login for someone else is purged")
        XCTAssertNil(try? vault.loadSession())
        XCTAssertEqual(auth.logouts, 1, "the foreign token is logged out")
    }

    func testStudentIdIsRememberedPerAccountAndMustNotChange() async throws {
        let (c, auth, vault) = make(expectedName: "沈高远")
        auth.identityName = "沈高远"
        auth.studentId = "1001"
        await c.restore()
        XCTAssertTrue(vault.hasCredentials)
        try? vault.saveSession(PortalSession(token: "stale", expiresAt: Date().addingTimeInterval(-10), studentId: "1001"))
        auth.studentId = "2002"
        await c.accountChanged()
        await XCTAssertThrowsPortal(.identityMismatch) { _ = try await c.prepareForSensitiveAction() }
    }

    func testVaultReadsNothingWithoutAnAccount() throws {
        let vault = SecretPortalVault(store: InMemorySecretStore())
        XCTAssertNil(try? vault.loadCredentials())
        XCTAssertThrowsError(try vault.saveCredentials(PortalCredentials(username: "u", password: "p")))
        vault.setAccount("h_1", expectedName: nil)
        try vault.saveCredentials(PortalCredentials(username: "u", password: "p"))
        vault.setAccount("h_2", expectedName: nil)
        XCTAssertNil(try vault.loadCredentials(), "another account sees no school login")
        vault.setAccount(nil, expectedName: nil)
        XCTAssertNil(try? vault.loadCredentials())
    }

    func testAccountChangeDropsInFlightReauth() async throws {
        let (c, auth, _) = make()
        auth.loginDelayNs = 100_000_000
        let pending = Task { try await c.prepareForSensitiveAction() }
        try await Task.sleep(nanoseconds: 10_000_000)
        await c.accountChanged()
        do {
            _ = try await pending.value
            XCTFail("a token minted for the previous account must not be delivered")
        } catch {}
    }

    func testVerifyProvesWithoutKeeping() async throws {
        let (c, auth, vault) = make(creds: false, expectedName: "沈高远")
        auth.identityName = "沈高远"
        try await c.verify(PortalCredentials(username: "u", password: "p"))
        XCTAssertFalse(vault.hasCredentials)
        auth.identityName = "someone else"
        await XCTAssertThrowsPortal(.identityMismatch) { try await c.verify(PortalCredentials(username: "u", password: "p")) }
    }

    func testRestoreUsesFreshSavedSessionWithoutLogin() async {
        let saved = PortalSession(token: "saved", expiresAt: Date().addingTimeInterval(3600), studentId: "1")
        let (c, auth, _) = make(saved: saved)
        let state = await c.restore()
        XCTAssertEqual(state, .authenticated(expiresAt: saved.expiresAt, studentId: "1"))
        XCTAssertEqual(auth.logins, 0)
    }

    func testExpiredSavedSessionSilentlyRelogins() async throws {
        let stale = PortalSession(token: "stale", expiresAt: Date().addingTimeInterval(-10), studentId: "1")
        let (c, auth, vault) = make(saved: stale)
        await c.restore()
        XCTAssertEqual(auth.logins, 1)
        XCTAssertEqual(try vault.loadSession()?.token, "tok")
        let token = try await c.prepareForSensitiveAction()
        XCTAssertEqual(token, "tok")
        XCTAssertEqual(auth.logins, 1, "a fresh session is reused")
    }

    func testNoCredentialsMeansNoSilentRecovery() async {
        let (c, auth, _) = make(creds: false)
        let state = await c.restore()
        XCTAssertEqual(state, .noCredentials)
        XCTAssertEqual(auth.logins, 0)
    }

    func testSingleFlightReauth() async throws {
        let (c, auth, _) = make()
        auth.loginDelayNs = 50_000_000
        async let a = c.prepareForSensitiveAction()
        async let b = c.prepareForSensitiveAction()
        _ = try await (a, b)
        XCTAssertEqual(auth.logins, 1)
    }

    func testSafeReadReplaysOnceButMutationsDoNot() async throws {
        let (c, auth, _) = make()
        final class Counter: @unchecked Sendable { var calls = 0 }
        let counter = Counter()
        let value: String = try await c.withAuthentication(replay: .safeRead) { token in
            counter.calls += 1
            if counter.calls == 1 { throw PortalError.sessionExpired }
            return "ok:\(token)"
        }
        XCTAssertEqual(value, "ok:tok")
        XCTAssertEqual(counter.calls, 2)
        XCTAssertEqual(auth.logins, 2)

        counter.calls = 0
        await XCTAssertThrowsPortal(.sessionExpired) {
            _ = try await c.withAuthentication(replay: .nonIdempotent) { _ -> String in
                counter.calls += 1
                throw PortalError.sessionExpired
            }
        }
        XCTAssertEqual(counter.calls, 1, "a gate open is never replayed")
    }

    func testRejectedCredentialsPurgeTheSavedLogin() async {
        let (c, auth, vault) = make()
        auth.loginResult = .failure(.credentialsRejected)
        let state = await c.restore()
        XCTAssertEqual(state, .userActionRequired(.passwordChanged))
        XCTAssertFalse(vault.hasCredentials)
    }

    func testOfflinePreservesCredentialsAndStillValidToken() async throws {
        let soon = PortalSession(token: "soon", expiresAt: Date().addingTimeInterval(120), studentId: "1")
        let (c, auth, vault) = make(saved: soon)
        auth.loginResult = .failure(.networkUnavailable)
        let state = await c.restore()
        XCTAssertEqual(state, .temporarilyUnavailable)
        XCTAssertTrue(vault.hasCredentials)
        let token = try await c.prepareForSensitiveAction()
        XCTAssertEqual(token, "soon", "inside the safety window a clock-valid token keeps working offline")
    }
}

final class AccessRulesTests: XCTestCase {
    func row(status: Int, flag: Int, start: String, end: String) -> ExitPermitWire {
        ExitPermitWire(recordId: 1, status: status, statusName: status == 1 ? "通过" : "", note: "出门", flag: flag, startTime: start, endTime: end)
    }

    func testOpenableRequiresApprovedUnusedAndInsideWindow() {
        PinnedClock.at("2026-09-02T09:00:00Z") { // 17:00 Shanghai
            let approved = ExitPermit(row(status: 1, flag: 0, start: "2026-09-02 16:00:00", end: "2026-09-02 19:00:00"))
            XCTAssertTrue(approved.isOpenable())
            XCTAssertEqual(approved.displayStatus, "通过")
            XCTAssertEqual(approved.displayWhen, "Wed 2 Sept · 16:00–19:00")

            let usedOnTheWebsite = ExitPermit(row(status: 1, flag: 1, start: "2026-09-02 16:00:00", end: "2026-09-02 19:00:00"))
            XCTAssertFalse(usedOnTheWebsite.isOpenable(), "the door flag set elsewhere consumes the permit")
            XCTAssertTrue(usedOnTheWebsite.isConsumed)
            XCTAssertEqual(usedOnTheWebsite.displayStatus, "Used")

            let opened = ExitPermit(row(status: 3, flag: 0, start: "2026-09-02 16:00:00", end: "2026-09-02 19:00:00"))
            XCTAssertFalse(opened.isOpenable())
            XCTAssertTrue(opened.isConsumed)

            XCTAssertFalse(ExitPermit(row(status: 0, flag: 0, start: "2026-09-02 16:00:00", end: "2026-09-02 19:00:00")).isOpenable())
            XCTAssertFalse(ExitPermit(row(status: 1, flag: 0, start: "2026-09-02 18:00:00", end: "2026-09-02 19:00:00")).isOpenable(), "not yet")
            XCTAssertFalse(ExitPermit(row(status: 1, flag: 0, start: "2026-09-02 10:00:00", end: "2026-09-02 12:00:00")).isOpenable(), "expired")
            XCTAssertTrue(ExitPermit(row(status: 1, flag: 0, start: "2026-09-02 10:00:00", end: "2026-09-02 12:00:00")).isExpired())
        }
    }

    func testOpenableOrderingIsMostRecentFirst() {
        PinnedClock.at("2026-09-02T09:00:00Z") {
            let a = ExitPermit(ExitPermitWire(recordId: 1, status: 1, flag: 0, startTime: "2026-09-02 15:00:00", endTime: "2026-09-02 19:00:00"))
            let b = ExitPermit(ExitPermitWire(recordId: 2, status: 1, flag: 0, startTime: "2026-09-02 16:30:00", endTime: "2026-09-02 19:00:00"))
            XCTAssertEqual(ExitPermit.openable([a, b]).map(\.recordId), [2, 1])
        }
    }

    func testQuickDraftDefaultsAndMidnight() {
        PinnedClock.at("2026-09-02T14:30:00Z") { // 22:30 Shanghai
            var draft = PermitDraft.quick()
            XCTAssertEqual(draft.reason, "出门")
            XCTAssertTrue(draft.crossesMidnight, "22:30 + 2 h is tomorrow")
            XCTAssertEqual(draft.request.startTime, "2026-09-02 22:30:00")
            XCTAssertEqual(draft.request.endTime, "2026-09-03 00:30:00")
            draft.setEnd(PinnedClock.shanghaiDate("2026-09-02 21:00"))
            XCTAssertEqual(PortalTime.string(draft.end), "2026-09-03 21:00:00", "an end before the start rolls to the next day")
            draft.reason = "   "
            XCTAssertEqual(draft.cleanedReason, "出门")
            draft.setStart(PinnedClock.shanghaiDate("2026-09-03 22:00"))
            XCTAssertTrue(draft.end > draft.start)
        }
    }

    func testAccessCopy() {
        XCTAssertEqual(AccessCopy.describe(PortalError.operationRejected(endpoint: "x", status: 1, message: "该出门条已使用")), "该出门条已使用")
        XCTAssertEqual(AccessCopy.describe(PortalError.timeout(outcomeUnknown: true)), "The request timed out. Check the gate physically before trying again.")
        XCTAssertEqual(AccessCopy.describe(PortalError.noCredentials), "Access needs your school login kept on this iPhone. Turn on Stay connected in Settings.")
    }
}
