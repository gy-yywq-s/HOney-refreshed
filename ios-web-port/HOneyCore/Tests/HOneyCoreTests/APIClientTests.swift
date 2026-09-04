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

    func testQueryEncodingAndPathSegments() async throws {
        let transport = ScriptedTransport { _ in HTTPResponse(status: 200, body: try Fixtures.data("entities")) }
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore(sessionFixture()))
        _ = try await client.entities(type: .course, q: "a b+c")
        let comps = URLComponents(url: transport.lastRequest!.url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(comps.path, "/api/entities")
        let items = Dictionary(uniqueKeysWithValues: comps.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items, ["type": "course", "q": "a b+c"])
        _ = try? await client.vaultPairingRead(pairingId: "id/with slash")
        XCTAssertTrue(transport.lastRequest!.url.absoluteString.hasSuffix("/api/vault/pairing/id%2Fwith%20slash"), "path segment is percent-encoded")
    }

    func testVaultConflictCarriesTheCurrentRecord() async throws {
        let transport = ScriptedTransport { req in
            if req.method == "PUT" { return HTTPResponse(status: 409, body: try Fixtures.data("vault-put-conflict")) }
            return HTTPResponse(status: 404, body: Data(#"{"error":"no_vault"}"#.utf8))
        }
        let client = APIClient(baseURL: base, transport: transport, sessionStore: InMemorySessionStore(sessionFixture()))
        let none = try await client.vault()
        XCTAssertNil(none, "404 reads as no vault, not an error")
        let put = try await client.vaultPut(VaultPutRequest(vaultId: "v_fixture", baseRevision: 2, iv: "i", ciphertext: "c", wrappers: []))
        guard case .conflict(let current) = put else { return XCTFail("conflict expected") }
        XCTAssertEqual(current.revision, 3)
    }

    private func sessionFixture() -> SessionTokens {
        try! Fixtures.decode(SessionTokens.self, "session-refresh")
    }
}

final class CommunityAPIClientTests: XCTestCase {
    func testRequestsCarryNoIdentity() async throws {
        let transport = ScriptedTransport { req in
            switch req.url.path {
            case "/community/v2/feed": return HTTPResponse(status: 200, body: try Fixtures.data("feed-page"))
            case "/community/v2/search": return HTTPResponse(status: 200, body: try Fixtures.data("search"))
            default: return HTTPResponse(status: 200, body: try Fixtures.data("publish"))
            }
        }
        let client = CommunityAPIClient(baseURL: URL(string: "https://honey.example")!, transport: transport)
        let page = try await client.feed(FeedRequestV2(scope: .myClasses, exposure: ExposureScope(teachers: ["t"], courses: [], lessons: ["l"]), limit: 20))
        XCTAssertEqual(page.items.count, 3)
        let search = try await client.search(q: "dia grams")
        XCTAssertEqual(search.q, "diagrams")
        for i in 0..<transport.count {
            let req = transport.request(at: i)
            for header in req.headers.keys {
                XCTAssertFalse(header.lowercased().contains("authorization"), "Community must never see a session")
                XCTAssertFalse(header.lowercased().contains("cookie"), "Community must never see cookies")
            }
        }
        let feedBody = try JSONSerialization.jsonObject(with: transport.request(at: 0).body!) as! [String: Any]
        XCTAssertEqual(Set(feedBody.keys), ["scope", "exposure", "limit"])
        XCTAssertTrue(transport.request(at: 1).url.absoluteString.hasSuffix("/community/v2/search?q=dia%20grams"))
    }

    func testIdentityFreeTransportConstructs() {
        // The cookie-less/credential-less configuration is asserted on the
        // simulator (HOneyNativeTests); here we only prove it builds everywhere.
        let transport = URLSessionTransport.identityFree()
        XCTAssertNotNil(transport)
    }

    func testErrorsAreTyped() async {
        let transport = ScriptedTransport { _ in HTTPResponse(status: 422, body: Data(#"{"error":"pass_mismatch"}"#.utf8)) }
        let client = CommunityAPIClient(baseURL: URL(string: "https://honey.example")!, transport: transport)
        do {
            _ = try await client.mineChallenge()
            XCTFail()
        } catch let error as APIError {
            XCTAssertEqual(error.code, "pass_mismatch")
        } catch { XCTFail("\(error)") }
    }
}
