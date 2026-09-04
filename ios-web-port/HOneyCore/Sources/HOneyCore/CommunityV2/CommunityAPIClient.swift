// The identity-free client for HOney Community (`/community/v2/*`), the
// iPhone twin of apps/web/src/api/community.ts. Every request rides an
// identity-free transport (no cookies, no credential storage) and carries
// no Authorization header: the process on the other side has no account
// database, and this client must never give it a correlation handle.
// Proofs (tokens, signed statements) are the only authentication.

import Foundation

public actor CommunityAPIClient {
    public let baseURL: URL
    private let transport: HTTPTransport

    public init(baseURL: URL, transport: HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    // MARK: reading

    public func feed(_ request: FeedRequestV2) async throws -> FeedPageV2 {
        try await call("POST", "/community/v2/feed", body: request)
    }

    public func feedUpdates(_ request: FeedUpdatesRequestV2) async throws -> FeedUpdatesResponse {
        try await call("POST", "/community/v2/feed/updates", body: request)
    }

    public func fromMyClasses(_ request: FromMyClassesRequestV2) async throws -> ExperiencesListV2 {
        try await call("POST", "/community/v2/from-my-classes", body: request)
    }

    public func search(q: String) async throws -> SearchResponseV2 {
        try await call("GET", "/community/v2/search", query: [("q", q)], body: Empty?.none)
    }

    public func stats(entityKey: String) async throws -> EntityStatsV2 {
        try await call("GET", "/community/v2/stats", query: [("entityKey", entityKey)], body: Empty?.none)
    }

    // MARK: publication

    public func check(_ request: CheckRequestV2) async throws -> CheckResponseV2 {
        try await call("POST", "/community/v2/check", body: request)
    }

    public func publish(_ request: PublishRequestV2) async throws -> PublishResponseV2 {
        try await call("POST", "/community/v2/publish", body: request)
    }

    // MARK: ownership

    public func mineChallenge() async throws -> ChallengeResponse {
        try await call("POST", "/community/v2/mine/challenge", body: Empty())
    }

    public func mine(_ request: MineRequest) async throws -> MineResponse {
        try await call("POST", "/community/v2/mine", body: request)
    }

    public func revokeChallenge(experienceId: String) async throws -> ChallengeResponse {
        try await call("POST", "/community/v2/posts/\(encode(experienceId))/revoke/challenge", body: Empty())
    }

    public func revoke(experienceId: String, _ request: RevokeRequest) async throws -> OkResponse {
        try await call("POST", "/community/v2/posts/\(encode(experienceId))/revoke", body: request)
    }

    // MARK: reactions and reports

    public func registerReactor(_ request: RegisterReactorRequest) async throws -> OkResponse {
        try await call("POST", "/community/v2/reactors/register", body: request)
    }

    public func react(experienceId: String, _ request: ReactRequestV2) async throws -> ReactResponseV2 {
        try await call("POST", "/community/v2/posts/\(encode(experienceId))/react", body: request)
    }

    public func report(experienceId: String, _ request: ReportRequestV2) async throws -> OkResponse {
        try await call("POST", "/community/v2/posts/\(encode(experienceId))/report", body: request)
    }

    // MARK: plumbing

    private struct Empty: Encodable {}

    private func encode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? segment
    }

    private func call<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [(String, String)] = [], body: B?) async throws -> T {
        var headers = ["Accept": "application/json"]
        var data: Data?
        if let body {
            headers["Content-Type"] = "application/json"
            data = try WireCoding.encode(body)
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = components.percentEncodedPath
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.percentEncodedPath = basePath + path
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        let response = try await transport.send(HTTPRequest(method: method, url: components.url!, headers: headers, body: data))
        guard (200..<300).contains(response.status) else {
            throw APIError.from(status: response.status, body: response.body)
        }
        if response.body.isEmpty, let ok = try? WireCoding.decode(T.self, from: Data("{\"ok\":true}".utf8)) { return ok }
        return try WireCoding.decode(T.self, from: response.body)
    }
}
