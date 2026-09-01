//
//  HOneyAPI.swift
//  HOney — typed async client for the HOney backend (Band 2/4, no SwiftUI).
//
//  Bearer access token; single-flight refresh-on-401 with one retry. All request
//  timeouts are bounded via the URLSession configuration.
//

import Foundation

enum HOneyAPIError: Error, Equatable {
    case notAuthenticated
    case invalidResponse
    case http(status: Int, body: String?)
    case decoding(String)

    /// The backend's `{ "error": "<code>" }` body of a non-2xx response, when
    /// present. Error handling matches codes as strings so unknown additions
    /// degrade to generic copy.
    var apiErrorCode: String? {
        guard case .http(_, let body) = self, let body, let data = body.data(using: .utf8) else { return nil }
        struct ErrorBody: Decodable { let error: String? }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
    }
}

private struct NoBody: Encodable {}

actor HOneyAPI {
    private let baseURL: URL
    private let session: URLSession
    private let store: SessionStore
    private var refreshTask: Task<HOneySession, Error>?

    init(baseURL: URL, store: SessionStore, session: URLSession = HOneyAPI.makeSession()) {
        self.baseURL = baseURL
        self.store = store
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    // MARK: - Auth

    func login(username: String, password: String, consentTimetable: Bool?) async throws -> LoginResponse {
        struct Body: Encodable { let username: String; let password: String; let consentTimetable: Bool? }
        let response: LoginResponse = try await send(
            "POST", "/api/auth/login",
            body: Body(username: username, password: password, consentTimetable: consentTimetable),
            authed: false
        )
        await store.save(response.session)
        return response
    }

    func logout() async {
        _ = try? await sendNoContent("POST", "/api/auth/logout", authed: true)
        await store.clear()
    }

    func me() async throws -> MeResponse {
        try await send("GET", "/api/me", authed: true)
    }

    func setConsent(timetable: Bool) async throws {
        struct Body: Encodable { let timetable: Bool }
        try await sendNoContent("POST", "/api/consent", body: Body(timetable: timetable), authed: true)
    }

    // MARK: - Timetable

    func sync() async throws -> SyncResponse {
        try await send("POST", "/api/sync", authed: true)
    }

    func timetable(date: String) async throws -> TimetableResponse {
        try await send("GET", "/api/timetable", query: [URLQueryItem(name: "date", value: date)], authed: true)
    }

    func nextLesson() async throws -> NextLessonResponse {
        try await send("GET", "/api/next-lesson", authed: true)
    }

    func history(query: String?, teacherId: String?, courseId: String?, order: String?) async throws -> HistoryResponse {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        if let teacherId { items.append(URLQueryItem(name: "teacherId", value: teacherId)) }
        if let courseId { items.append(URLQueryItem(name: "courseId", value: courseId)) }
        if let order { items.append(URLQueryItem(name: "order", value: order)) }
        return try await send("GET", "/api/history", query: items, authed: true)
    }

    func directory() async throws -> DirectoryResponse {
        try await send("GET", "/api/directory", authed: true)
    }

    // MARK: - Experiences

    func entities(type: EntityType?, query: String?) async throws -> EntitiesResponse {
        var items: [URLQueryItem] = []
        if let type { items.append(URLQueryItem(name: "type", value: type.rawValue)) }
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await send("GET", "/api/entities", query: items, authed: true)
    }

    func experiences(
        entityKey: String? = nil,
        teacherId: String? = nil,
        courseId: String? = nil,
        roomId: String? = nil,
        query: String? = nil,
        sort: ExperienceSort = .newest
    ) async throws -> ExperiencesFeedResponse {
        var items: [URLQueryItem] = []
        if let entityKey { items.append(URLQueryItem(name: "entityKey", value: entityKey)) }
        if let teacherId { items.append(URLQueryItem(name: "teacherId", value: teacherId)) }
        if let courseId { items.append(URLQueryItem(name: "courseId", value: courseId)) }
        if let roomId { items.append(URLQueryItem(name: "roomId", value: roomId)) }
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        items.append(URLQueryItem(name: "sort", value: sort.rawValue))
        return try await send("GET", "/api/experiences", query: items, authed: true)
    }

    /// Domain query (audit §4.2): posts relevant to my verified exposure —
    /// chronological, never ranked. The server knows the caller's exposure.
    func fromMyClasses(before: Int? = nil, limit: Int? = nil) async throws -> ExperiencesFeedResponse {
        var items: [URLQueryItem] = []
        if let before { items.append(URLQueryItem(name: "before", value: String(before))) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await send("GET", "/api/experiences/from-my-classes", query: items, authed: true)
    }

    // MARK: Publication flow: eligibility → check → publish (contract §Experiences)

    /// Step 1: authenticated, single-use, scope-bound eligibility token.
    func experienceEligibility(lessonId: String? = nil, entityKey: String? = nil) async throws -> ExperienceEligibilityResponse {
        try await send(
            "POST", "/api/experiences/eligibility",
            body: ExperienceEligibilityRequest(lessonId: lessonId, entityKey: entityKey),
            authed: true
        )
    }

    /// Step 2: synchronous moderation preflight. The draft is NEVER persisted
    /// by the server, and nothing is published without an explicit user action.
    func checkExperience(_ request: CheckExperienceRequest) async throws -> CheckExperienceResponse {
        try await send("POST", "/api/experiences/check", body: request, authed: true)
    }

    /// Step 3: publish. Sent WITHOUT session auth — the eligibility token and
    /// content-bound pass are the only proof; the request carries no identity.
    func publishExperience(_ request: PublishExperienceRequest) async throws -> PublishExperienceResponse {
        try await send("POST", "/api/experiences/publish", body: request, authed: false)
    }

    /// Own submissions (any status), proved by client-held ownership keys.
    func myExperiences(keys: [String]) async throws -> MyExperiencesResponse {
        try await send("POST", "/api/experiences/mine", body: MineRequest(keys: keys), authed: true)
    }

    func revokeExperience(ownershipKey: String) async throws {
        try await sendNoContent("POST", "/api/experiences/revoke", body: OwnershipKeyRequest(ownershipKey: ownershipKey), authed: true)
    }

    func react(experienceId: String, value: Int) async throws {
        try await sendNoContent("POST", "/api/experiences/\(experienceId)/react", body: ReactRequest(value: value), authed: true)
    }

    /// Reports are category-only (audit §3.9): the backend rejects any free text.
    func report(experienceId: String, category: ReportCategory) async throws {
        try await sendNoContent("POST", "/api/experiences/\(experienceId)/report", body: ReportExperienceRequest(category: category), authed: true)
    }

    /// Push a client-obtained portal token for server-side sync.
    func disconnectSchool() async throws {
        try await sendNoContent("POST", "/api/school/disconnect", authed: true)
    }

    func deleteAccount() async throws {
        try await sendNoContent("DELETE", "/api/account", authed: true)
    }

    func pushPortalToken(_ token: String) async throws {
        struct Body: Encodable { let token: String }
        try await sendNoContent("POST", "/api/portal/token", body: Body(token: token), authed: true)
    }

    // MARK: - Transport

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        authed: Bool
    ) async throws -> Response {
        let data = try await perform(method, path, query: query, body: Optional<NoBody>.none, authed: authed)
        return try decode(Response.self, from: data)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body,
        authed: Bool
    ) async throws -> Response {
        let data = try await perform(method, path, query: query, body: body, authed: authed)
        return try decode(Response.self, from: data)
    }

    private func sendNoContent(_ method: String, _ path: String, authed: Bool) async throws {
        _ = try await perform(method, path, query: [], body: Optional<NoBody>.none, authed: authed)
    }

    private func sendNoContent<Body: Encodable>(_ method: String, _ path: String, body: Body, authed: Bool) async throws {
        _ = try await perform(method, path, query: [], body: body, authed: authed)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try HOneyCoding.decoder.decode(T.self, from: data)
        } catch {
            throw HOneyAPIError.decoding(String(describing: error))
        }
    }

    private func perform<Body: Encodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem],
        body: Body?,
        authed: Bool,
        isRetry: Bool = false
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw HOneyAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try HOneyCoding.encoder.encode(body)
        }
        if authed {
            guard let token = await store.current()?.accessToken else {
                throw HOneyAPIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HOneyAPIError.invalidResponse }

        if http.statusCode == 401, authed, !isRetry {
            // Single-flight refresh, then retry exactly once.
            _ = try await refreshSession()
            return try await perform(method, path, query: query, body: body, authed: authed, isRetry: true)
        }

        guard 200..<300 ~= http.statusCode else {
            throw HOneyAPIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }

    /// Single-flight refresh: concurrent 401s share one in-flight refresh.
    private func refreshSession() async throws -> HOneySession {
        if let refreshTask {
            return try await refreshTask.value
        }
        let store = self.store
        let baseURL = self.baseURL
        let session = self.session
        let task = Task<HOneySession, Error> {
            guard let current = await store.current() else { throw HOneyAPIError.notAuthenticated }
            struct Body: Encodable { let refreshToken: String }
            var request = URLRequest(url: baseURL.appending(path: "/api/auth/refresh"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try HOneyCoding.encoder.encode(Body(refreshToken: current.refreshToken))
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                await store.clear()
                throw HOneyAPIError.notAuthenticated
            }
            let refreshed = try HOneyCoding.decoder.decode(HOneySession.self, from: data)
            await store.save(refreshed)
            return refreshed
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
