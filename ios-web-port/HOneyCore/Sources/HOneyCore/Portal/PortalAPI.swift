// Direct-to-school portal client for Access (spec: HOney never relays
// Access; the backend exposes no Access route). Raw `Authorization: <token>`
// header — the portal does NOT use a Bearer prefix. Each endpoint applies
// its own documented success rule (see PortalWire.swift). Mutations are
// never retried here or anywhere above: a gate open is a physical action.

import Foundation

public protocol PortalAuthAPI: Sendable {
    func login(_ credentials: PortalCredentials) async throws -> String
    func identity(token: String) async throws -> PortalIdentity
    func logout(token: String) async
}

public struct PortalAPI: PortalAuthAPI, Sendable {
    public let baseURL: URL
    private let transport: HTTPTransport

    public init(baseURL: URL, transport: HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    private static let maintenanceSignatures = ["maintenance", "升级维护", "系统维护"]

    static func looksLikeMaintenance(_ body: Data) -> Bool {
        let text = String(decoding: body.prefix(2000), as: UTF8.self).lowercased()
        return maintenanceSignatures.contains { text.contains($0) }
    }

    // MARK: Auth

    /// POST /api/login — one attempt per call; never auto-looped on rejection.
    public func login(_ credentials: PortalCredentials) async throws -> String {
        struct Body: Encodable { let username: String; let password: String }
        let response = try await send("POST", "/api/login", token: nil, body: Body(username: credentials.username, password: credentials.password), mutation: false)
        if response.status >= 500 { throw PortalError.serverUnavailable(httpStatus: response.status) }
        if response.status == 401 { throw PortalError.credentialsRejected }
        guard let env = try? WireCoding.decode(PortalEnvelope.self, from: response.body) else {
            // Maintenance windows must NEVER surface as a password prompt;
            // only a real interactive challenge may.
            if Self.looksLikeMaintenance(response.body) { throw PortalError.serverUnavailable(httpStatus: response.status) }
            throw PortalError.userActionRequired(.unknown)
        }
        if let token = env.token, !token.isEmpty { return token }
        if env.status == 0, let token = env.data?["token"]?.stringValue, !token.isEmpty { return token }
        if let message = env.messageText?.lowercased(), message.contains("invalid") || message.contains("密码") {
            throw PortalError.credentialsRejected
        }
        throw PortalError.schemaIncompatible(endpoint: "/api/login")
    }

    /// GET /api/public/user_info — identity + server-authoritative exp (Unix seconds).
    public func identity(token: String) async throws -> PortalIdentity {
        let endpoint = "/api/public/user_info"
        let env = try await authed("GET", endpoint, token: token)
        guard env.status == 0, let data = env.data, data.isObject,
              let id = data["id"]?.doubleValue, let exp = data["exp"]?.doubleValue else {
            throw PortalError.schemaIncompatible(endpoint: endpoint)
        }
        return PortalIdentity(
            studentId: String(Int(id)),
            name: data["name"]?.stringValue ?? "",
            isDayStudent: data["day_student"]?.boolValue,
            tokenExpiresAt: Date(timeIntervalSince1970: exp)
        )
    }

    /// POST /api/logout — never retried; callers clear local state regardless.
    public func logout(token: String) async {
        _ = try? await send("POST", "/api/logout", token: token, body: Optional<OpenDoorRequest>.none, mutation: true)
    }

    // MARK: Access reads (safe to replay after a silent re-login)

    /// GET /api/exit/get_student_list — exit permits ({ rows, total }, unpaginated).
    public func permits(token: String) async throws -> [ExitPermitWire] {
        let endpoint = "/api/exit/get_student_list"
        let response = try await send("GET", endpoint, token: token, body: Optional<OpenDoorRequest>.none, mutation: false)
        try triage(response, endpoint: endpoint)
        struct Shape: Decodable {
            struct Data: Decodable { let rows: [ExitPermitWire]? }
            let status: Int?
            let data: Data?
        }
        guard let parsed = try? WireCoding.decode(Shape.self, from: response.body), parsed.status == 0, let rows = parsed.data?.rows else {
            throw PortalError.schemaIncompatible(endpoint: endpoint)
        }
        return rows
    }

    /// GET /api/user/get_door_list — NON-standard: success is status===1, doors in `message`.
    /// A degraded endpoint (any other status) is "temporarily unavailable" —
    /// distinct from a genuine empty list — so no open attempt is offered.
    public func doors(token: String) async throws -> [PortalDoor] {
        let endpoint = "/api/user/get_door_list"
        let env = try await authed("GET", endpoint, token: token)
        guard env.status == 1, let doors = env.messageArray else {
            throw PortalError.serverUnavailable(httpStatus: nil)
        }
        return doors.filter { !$0.key.isEmpty }
    }

    // MARK: Access mutations (explicit user action only; never replayed)

    /// POST /api/exit/update_door_flag — physically opens a gate. NON-IDEMPOTENT.
    /// Success is ONLY status 0 / code 200; a nonzero status means the portal
    /// refused (e.g. a permit already used at the gate or on the official site).
    public func openDoor(token: String, recordId: Int, doorKey: String) async throws -> PortalActionResult {
        try await action("/api/exit/update_door_flag", token: token, body: OpenDoorRequest(recordId: recordId, doorKey: doorKey))
    }

    /// POST /api/exit/add_record — create an exit permit request.
    public func addPermit(token: String, _ request: AddPermitRequest) async throws -> PortalActionResult {
        try await action("/api/exit/add_record", token: token, body: request)
    }

    /// POST /api/exit/delete_record — destructive; explicit user action only.
    public func deletePermit(token: String, recordId: Int) async throws -> PortalActionResult {
        struct Body: Encodable { let record_id: Int }
        return try await action("/api/exit/delete_record", token: token, body: Body(record_id: recordId))
    }

    // MARK: Plumbing

    private func action<B: Encodable>(_ endpoint: String, token: String, body: B) async throws -> PortalActionResult {
        let response = try await send("POST", endpoint, token: token, body: body, mutation: true)
        try triage(response, endpoint: endpoint)
        let env = try WireCoding.decode(PortalEnvelope.self, from: response.body)
        if env.status == 0 || env.code == 200 {
            return PortalActionResult(message: env.messageText ?? "")
        }
        throw PortalError.operationRejected(endpoint: endpoint, status: env.status, message: env.messageText)
    }

    private func authed(_ method: String, _ endpoint: String, token: String) async throws -> PortalEnvelope {
        let response = try await send(method, endpoint, token: token, body: Optional<OpenDoorRequest>.none, mutation: false)
        try triage(response, endpoint: endpoint)
        guard let env = try? WireCoding.decode(PortalEnvelope.self, from: response.body) else {
            throw PortalError.schemaIncompatible(endpoint: endpoint)
        }
        return env
    }

    /// Shared response triage for authenticated endpoints: 5xx →
    /// serverUnavailable; 401 + portal envelope → sessionExpired; other 401
    /// (proxy interference) → serverUnavailable; 200 + maintenance HTML →
    /// serverUnavailable; 200 + other non-JSON → schemaIncompatible.
    private func triage(_ response: HTTPResponse, endpoint: String) throws {
        if response.status >= 500 { throw PortalError.serverUnavailable(httpStatus: response.status) }
        if response.status == 401 {
            if Self.isUnauthorizedEnvelope(response.body) { throw PortalError.sessionExpired }
            throw PortalError.serverUnavailable(httpStatus: 401)
        }
        if (try? WireCoding.decode(PortalEnvelope.self, from: response.body)) == nil {
            if Self.looksLikeMaintenance(response.body) { throw PortalError.serverUnavailable(httpStatus: response.status) }
            throw PortalError.schemaIncompatible(endpoint: endpoint)
        }
    }

    /// The portal signals an expired session as HTTP 401 with status 400001 or message "Unauthorized".
    static func isUnauthorizedEnvelope(_ body: Data) -> Bool {
        guard let env = try? WireCoding.decode(PortalEnvelope.self, from: body) else { return false }
        return env.status == 400001 || env.messageText == "Unauthorized"
    }

    private func send<B: Encodable>(_ method: String, _ path: String, token: String?, body: B?, mutation: Bool) async throws -> HTTPResponse {
        var headers = ["Accept": "application/json"]
        if let token { headers["Authorization"] = token } // raw token, no Bearer
        var data: Data?
        if let body {
            headers["Content-Type"] = "application/json"
            data = try WireCoding.encode(body)
        }
        let request = HTTPRequest(method: method, url: baseURL.appendingPathComponent(path), headers: headers, body: data)
        do {
            return try await transport.send(request)
        } catch {
            // A mutation that never answered may still have been applied.
            throw mutation ? PortalError.timeout(outcomeUnknown: true) : PortalError.networkUnavailable
        }
    }
}
