// The ordinary authenticated HOney API client (spec §3.4). One actor owns
// every /api/* call that carries the bearer token: a 401 triggers exactly
// one single-flight refresh and a retry; if that fails the session is
// dropped and `sessionLost` fires so the shell can return to Login.
//
// It deliberately does NOT expose `publish`: that call must never carry a
// session, so it lives in PublicationAPIClient on its own transport.

import Foundation

public struct QueryItem: Sendable, Equatable {
    let name: String
    let value: String
}

public actor APIClient: IssuerAPI, VaultAPI {
    public let baseURL: URL
    private let transport: HTTPTransport
    private let sessionStore: SessionStoring
    private var refreshTask: Task<Bool, Never>?
    private var sessionLostHandler: (@Sendable () -> Void)?

    public init(baseURL: URL, transport: HTTPTransport, sessionStore: SessionStoring) {
        self.baseURL = baseURL
        self.transport = transport
        self.sessionStore = sessionStore
    }

    /// Called when the session is unrecoverable (refresh failed / no session).
    public func onSessionLost(_ handler: (@Sendable () -> Void)?) {
        sessionLostHandler = handler
    }

    public func hasSession() -> Bool {
        (try? sessionStore.load()) != nil
    }

    // MARK: Auth / account

    public func login(_ input: LoginInput) async throws -> LoginResponse {
        let result: LoginResponse = try await request("POST", "/api/auth/login", body: input, auth: false)
        try sessionStore.save(result.session)
        return result
    }

    // Replay policy (review 11d42e3 §4.13): a 401 is answered by the backend
    // BEFORE the route runs (`requireAuth` preHandler), so replaying any
    // request — including a mutation — after a successful refresh cannot
    // apply it twice. Logout is the one call that must not replay (the old
    // session is gone either way), and publish never goes through here.

    /// Best effort server-side sign-out; the local session is dropped regardless.
    public func logout() async {
        if hasSession() {
            _ = try? await request("POST", "/api/auth/logout", body: Empty?.none, retryOn401: false) as OkResponse
        }
        try? sessionStore.clear()
    }

    public func me() async throws -> Me {
        try await request("GET", "/api/me")
    }

    public func sync() async throws -> SyncResponse {
        try await request("POST", "/api/sync")
    }

    public func portalEntry() async throws -> PortalEntryResponse {
        try await request("GET", "/api/portal/entry")
    }

    /// Hand a portal token the device obtained itself to HOney (validated
    /// server-side) so Sync and Portal entry reuse it instead of logging in again.
    public func pushPortalToken(_ token: String) async throws {
        struct Body: Encodable { let token: String }
        _ = try await request("POST", "/api/portal/token", body: Body(token: token)) as OkResponse
    }

    public func disconnectSchool() async throws {
        _ = try await request("POST", "/api/school/disconnect") as OkResponse
    }

    public func deleteImportedData() async throws {
        _ = try await request("DELETE", "/api/imported-data") as OkResponse
    }

    public func deleteAccount() async throws {
        _ = try await request("DELETE", "/api/account") as OkResponse
        try? sessionStore.clear()
    }

    public func clearSession() {
        try? sessionStore.clear()
    }

    // MARK: Timetable

    public func timetable(date: String) async throws -> TimetableResponse {
        try await request("GET", "/api/timetable", query: [QueryItem(name: "date", value: date)])
    }

    public func timetableRange(from: String, to: String) async throws -> TimetableRangeResponse {
        try await request("GET", "/api/timetable/range", query: [QueryItem(name: "from", value: from), QueryItem(name: "to", value: to)])
    }

    public func nextLesson() async throws -> NextLessonResponse {
        try await request("GET", "/api/next-lesson")
    }

    public func history(_ params: HistoryParams = HistoryParams()) async throws -> HistoryResponse {
        var query: [QueryItem] = []
        if let q = params.q, !q.isEmpty { query.append(QueryItem(name: "q", value: q)) }
        if let v = params.teacherId, !v.isEmpty { query.append(QueryItem(name: "teacherId", value: v)) }
        if let v = params.courseId, !v.isEmpty { query.append(QueryItem(name: "courseId", value: v)) }
        if let v = params.before, !v.isEmpty { query.append(QueryItem(name: "before", value: v)) }
        if let v = params.limit { query.append(QueryItem(name: "limit", value: String(v))) }
        if let v = params.order { query.append(QueryItem(name: "order", value: v.rawValue)) }
        return try await request("GET", "/api/history", query: query)
    }

    public func directory() async throws -> DirectoryResponse {
        try await request("GET", "/api/directory")
    }

    // MARK: Experiences

    public func entities(type: EntityType? = nil, q: String? = nil) async throws -> EntitiesResponse {
        var query: [QueryItem] = []
        if let type { query.append(QueryItem(name: "type", value: type.rawValue)) }
        if let q, !q.isEmpty { query.append(QueryItem(name: "q", value: q)) }
        return try await request("GET", "/api/entities", query: query)
    }

    // MARK: Anonymous Control v2 — issuer, scope, Control Vault, pairing relay
    // (posts themselves go to Community through CommunityAPIClient, never here)

    /// The blind-eligibility issuer's public descriptor (no session needed).
    public func communityIssuer() async throws -> IssuerDescriptor {
        try await request("GET", "/api/community/issuer", auth: false)
    }

    /// The viewer's canonical exposure with opaque lesson ids.
    public func communityScope() async throws -> CommunityScope {
        try await request("GET", "/api/community/scope")
    }

    /// Uncounted: which metadata the issuer would bind for a target.
    public func communityEligibilityInfo(_ target: EligibilityTarget) async throws -> EligibilityInfoResponse {
        try await request("POST", "/api/community/eligibility/info", body: target)
    }

    /// Counted: the one blind-signing round.
    public func communityEligibility(_ input: EligibilityRequest) async throws -> EligibilityIssued {
        try await request("POST", "/api/community/eligibility", body: input)
    }

    /// nil when no vault exists (404).
    public func vault() async throws -> VaultRecord? {
        do {
            return try await request("GET", "/api/vault")
        } catch let error as APIError where error.status == 404 {
            return nil
        }
    }

    /// CAS write; a 409 carries the server's current record.
    public func vaultPut(_ input: VaultPutRequest) async throws -> VaultPutResponse {
        do {
            return try await request("PUT", "/api/vault", body: input)
        } catch let error as APIError where error.status == 409 {
            if let body = error.body, let conflict = try? WireCoding.decode(VaultPutResponse.self, from: body) { return conflict }
            throw error
        }
    }

    public func vaultDelete() async throws {
        _ = try await request("DELETE", "/api/vault") as OkResponse
    }

    public func vaultPairingOffer(recipientPublicKey: String) async throws -> PairingOffer {
        try await request("POST", "/api/vault/pairing", body: RecipientBody(recipientPublicKey: recipientPublicKey))
    }

    public func vaultPairingRead(pairingId: String) async throws -> PairingOffer {
        try await request("GET", "/api/vault/pairing/\(pathEncode(pairingId))")
    }

    public func vaultPairingDeliver(pairingId: String, enc: String, ciphertext: String) async throws {
        _ = try await request("POST", "/api/vault/pairing/\(pathEncode(pairingId))/deliver", body: DeliverBody(enc: enc, ciphertext: ciphertext)) as OkResponse
    }

    /// nil while the other device has not delivered yet (404).
    public func vaultPairingClaim(pairingId: String) async throws -> PairingDelivery? {
        do {
            return try await request("GET", "/api/vault/pairing/\(pathEncode(pairingId))/delivery")
        } catch let error as APIError where error.status == 404 {
            return nil
        }
    }

    // MARK: Plumbing

    private struct Empty: Encodable {}
    private struct RecipientBody: Encodable { let recipientPublicKey: String }
    private struct DeliverBody: Encodable { let enc: String; let ciphertext: String }
    private struct RefreshBody: Encodable { let refreshToken: String }
    /// The refresh endpoint answers a bare SessionTokens; tolerate a `{ session }` wrapper too.
    private struct WrappedSession: Decodable { let session: SessionTokens }

    private func pathEncode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? segment
    }

    func request<T: Decodable>(
        _ method: String,
        _ path: String,
        query: [QueryItem] = [],
        auth: Bool = true,
        retryOn401: Bool = true
    ) async throws -> T {
        try await request(method, path, query: query, body: Empty?.none, auth: auth, retryOn401: retryOn401)
    }

    func request<T: Decodable, B: Encodable>(
        _ method: String,
        _ path: String,
        query: [QueryItem] = [],
        body: B?,
        auth: Bool = true,
        retryOn401: Bool = true
    ) async throws -> T {
        var headers = ["Accept": "application/json"]
        var data: Data?
        if let body {
            headers["Content-Type"] = "application/json"
            data = try WireCoding.encode(body)
        }
        if auth {
            guard let session = try? sessionStore.load() else {
                sessionLostHandler?()
                throw APIError.notAuthenticated
            }
            headers["Authorization"] = "Bearer \(session.accessToken)"
        }
        let response = try await transport.send(HTTPRequest(method: method, url: url(path, query: query), headers: headers, body: data))

        if response.status == 401, auth {
            if retryOn401, await refreshSession() {
                return try await request(method, path, query: query, body: body, auth: auth, retryOn401: false)
            }
            try? sessionStore.clear()
            sessionLostHandler?()
            throw APIError.sessionExpired
        }
        guard (200..<300).contains(response.status) else {
            throw APIError.from(status: response.status, body: response.body)
        }
        if response.body.isEmpty {
            // Void-ish endpoints answer `{ ok: true }`; an empty body only
            // appears on a misconfigured server — decode a placeholder.
            if let ok = try? WireCoding.decode(T.self, from: Data("{\"ok\":true}".utf8)) { return ok }
        }
        return try WireCoding.decode(T.self, from: response.body)
    }

    func url(_ path: String, query: [QueryItem]) -> URL {
        // Paths are built from literal routes plus already-encoded segments,
        // so they are appended as percent-encoded text (never re-encoded).
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = components.percentEncodedPath
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.percentEncodedPath = basePath + path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        return components.url!
    }

    /// Single-flight: concurrent 401s share one refresh round-trip.
    private func refreshSession() async -> Bool {
        if let refreshTask { return await refreshTask.value }
        let task = Task<Bool, Never> { [self] in await self.performRefresh() }
        refreshTask = task
        let ok = await task.value
        refreshTask = nil
        return ok
    }

    private func performRefresh() async -> Bool {
        guard let session = try? sessionStore.load() else { return false }
        do {
            let body = try WireCoding.encode(RefreshBody(refreshToken: session.refreshToken))
            let response = try await transport.send(HTTPRequest(
                method: "POST",
                url: url("/api/auth/refresh", query: []),
                headers: ["Content-Type": "application/json", "Accept": "application/json"],
                body: body
            ))
            guard (200..<300).contains(response.status) else { return false }
            let tokens: SessionTokens
            if let bare = try? WireCoding.decode(SessionTokens.self, from: response.body) {
                tokens = bare
            } else {
                tokens = try WireCoding.decode(WrappedSession.self, from: response.body).session
            }
            try sessionStore.save(tokens)
            return true
        } catch {
            return false
        }
    }
}
