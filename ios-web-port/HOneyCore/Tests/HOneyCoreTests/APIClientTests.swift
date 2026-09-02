import XCTest
@testable import HOneyCore

final class APIClientTests: XCTestCase {
    let base = URL(string: "https://honey.example")!

    func testLoginPostsWithoutAuthAndStoresSession() async throws {
        let transport = ScriptedTransport()
        transport.enqueue(status: 200, json: String(decoding: try Fixtures.data("login"), as: UTF8.self))
        let store = InMemorySessionStore()
        let client = APIClient(baseURL: base, transport: transport, sessionStore: store)

        let result = try await client.login(LoginInput(username: "u", password: "p"))
        XCTAssertEqual(result.displayName, "沈高远")
        XCTAssertEqual(try store.load()?.accessToken, "acc_fixture_token")
        let req = transport.request(at: 0)
        XCTAssertEqual(req.url.path, "/api/auth/login")
        XCTAssertNil(req.headers["Authorization"])
        let body = try JSONSerialization.jsonObject(with: req.body!) as! [String: String]
        XCTAssertEqual(body, ["username": "u", "password": "p"])
    }

    func testCredentialsRejectedIsTypedAndStoresNothing() async {
        let transport = ScriptedTransport()
        transport.enqueue(status: 401, json: #"{"error":"school_credentials_rejected"}"#)
        let store = InMemorySessionStore()
        let client = APIClient(baseURL: base, transport: transport, sessionStore: store)
        do {
            _ = try await client.login(LoginInput(username: "u", password: "p"))
            XCTFail("expected error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "school_credentials_rejected")
            XCTAssertEqual(APIErrorCopy.describe(error), "The school portal rejected that username or password.")
        } catch { XCTFail("\(error)") }
        XCTAssertNil(try store.load())
    }

    func testBodylessServerErrorReadsAsPortalUnavailable() async {
        let transport = ScriptedTransport()
        transport.enqueue { _ in HTTPResponse(status: 503) }
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore(sessionFixture()))
        do {
            _ = try await client.me()
            XCTFail()
        } catch let error as APIError {
            XCTAssertEqual(error.code, "portal_unavailable")
        } catch { XCTFail("\(error)") }
    }

    func testRefreshesOnceRetriesAndPersists() async throws {
        let transport = ScriptedTransport()
        transport.enqueue { _ in HTTPResponse(status: 401, body: Data(#"{"error":"session_expired"}"#.utf8)) }
        transport.enqueue { req in
            XCTAssertEqual(req.url.path, "/api/auth/refresh")
            let body = try JSONSerialization.jsonObject(with: req.body!) as! [String: String]
            XCTAssertEqual(body["refreshToken"], "ref_fixture_token")
            return HTTPResponse(status: 200, body: json(["accessToken": "acc2", "accessExpiresAt": "x", "refreshToken": "ref2", "refreshExpiresAt": "y"]))
        }
        transport.enqueue { req in
            XCTAssertEqual(req.headers["Authorization"], "Bearer acc2")
            return HTTPResponse(status: 200, body: try Fixtures.data("me"))
        }
        let store = InMemorySessionStore(sessionFixture())
        let client = APIClient(baseURL: base, transport: transport, sessionStore: store)
        let me = try await client.me()
        XCTAssertEqual(me.honeyId, "h_fixture01")
        XCTAssertEqual(try store.load()?.refreshToken, "ref2")
        XCTAssertEqual(transport.count, 3)
    }

    func testConcurrent401sShareOneRefresh() async throws {
        let transport = ScriptedTransport { req in
            if req.url.path == "/api/auth/refresh" {
                try await Task.sleep(nanoseconds: 50_000_000)
                return HTTPResponse(status: 200, body: json(["accessToken": "acc2", "accessExpiresAt": "x", "refreshToken": "ref2", "refreshExpiresAt": "y"]))
            }
            if req.headers["Authorization"] == "Bearer acc2" {
                return HTTPResponse(status: 200, body: try Fixtures.data("me"))
            }
            return HTTPResponse(status: 401, body: Data(#"{"error":"session_expired"}"#.utf8))
        }
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore(sessionFixture()))
        async let a = client.me()
        async let b = client.me()
        async let c = client.nextLesson()
        _ = try await (a, b)
        _ = try? await c
        let refreshes = transport.requests.filter { $0.url.path == "/api/auth/refresh" }.count
        XCTAssertEqual(refreshes, 1, "single-flight refresh")
    }

    func testRejectedRefreshClearsSessionAndSignalsLoss() async {
        let transport = ScriptedTransport { req in
            if req.url.path == "/api/auth/refresh" { return HTTPResponse(status: 401, body: Data(#"{"error":"invalid_refresh_token"}"#.utf8)) }
            return HTTPResponse(status: 401, body: Data(#"{"error":"session_expired"}"#.utf8))
        }
        let store = InMemorySessionStore(sessionFixture())
        let client = APIClient(baseURL: base, transport: transport, sessionStore: store)
        let lost = expectation(description: "session lost")
        await client.onSessionLost { lost.fulfill() }
        do {
            _ = try await client.me()
            XCTFail()
        } catch let error as APIError {
            XCTAssertEqual(error, .sessionExpired)
        } catch { XCTFail("\(error)") }
        await fulfillment(of: [lost], timeout: 1)
        XCTAssertNil(try store.load())
    }

    func testNoSessionIsATypedError() async {
        let transport = ScriptedTransport()
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore())
        do {
            _ = try await client.me()
            XCTFail()
        } catch let error as APIError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch { XCTFail("\(error)") }
        XCTAssertEqual(transport.count, 0, "no network call without a session")
    }

    func testQueryEncoding() async throws {
        let transport = ScriptedTransport { _ in HTTPResponse(status: 200, body: try Fixtures.data("feed-page")) }
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore(sessionFixture()))
        _ = try await client.feedPage(FeedParams(scope: .school, cursor: "a b+c", limit: 5, courseId: "c_1"))
        let url = transport.lastRequest!.url
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(comps.path, "/api/experiences/feed")
        let items = Dictionary(uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items, ["scope": "school", "cursor": "a b+c", "limit": "5", "courseId": "c_1"])
        _ = try? await client.react(experienceId: "id/with slash", value: 1)
        XCTAssertTrue(transport.lastRequest!.url.absoluteString.hasSuffix("/api/experiences/id%2Fwith%20slash/react"), "path segment is percent-encoded")
    }

    private func sessionFixture() -> SessionTokens {
        try! Fixtures.decode(SessionTokens.self, "session-refresh")
    }
}

final class PublicationAPIClientTests: XCTestCase {
    func testPublishCarriesNoIdentity() async throws {
        let transport = ScriptedTransport { req in
            HTTPResponse(status: 200, body: try Fixtures.data("publish"))
        }
        let client = PublicationAPIClient(baseURL: URL(string: "https://honey.example")!, transport: transport)
        let result = try await client.publish(PublishExperienceInput(eligibilityToken: "e", pass: "p", body: "b"))
        XCTAssertEqual(result.ownershipKey, "own_fixture_key")
        let req = transport.request(at: 0)
        XCTAssertEqual(req.url.path, "/api/experiences/publish")
        for header in req.headers.keys {
            XCTAssertFalse(header.lowercased().contains("authorization"), "publish must never carry a session")
            XCTAssertFalse(header.lowercased().contains("cookie"), "publish must never carry cookies")
        }
        let body = try JSONSerialization.jsonObject(with: req.body!) as! [String: Any]
        XCTAssertEqual(Set(body.keys), ["eligibilityToken", "pass", "body"])
    }

    func testIdentityFreeTransportConstructs() {
        // The cookie-less/credential-less configuration is asserted on the
        // simulator (HOneyNativeTests); here we only prove it builds everywhere.
        let transport = URLSessionTransport.identityFree()
        XCTAssertNotNil(transport)
    }

    func testPublishErrorsAreTyped() async {
        let transport = ScriptedTransport { _ in HTTPResponse(status: 422, body: Data(#"{"error":"pass_content_mismatch"}"#.utf8)) }
        let client = PublicationAPIClient(baseURL: URL(string: "https://honey.example")!, transport: transport)
        do {
            _ = try await client.publish(PublishExperienceInput(eligibilityToken: "e", pass: "p", body: "b"))
            XCTFail()
        } catch let error as APIError {
            XCTAssertEqual(error.code, "pass_content_mismatch")
        } catch { XCTFail("\(error)") }
    }
}
