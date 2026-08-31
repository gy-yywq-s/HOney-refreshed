//
//  PortalAPI.swift
//  HOney — direct-to-school portal client for Access ONLY (Band 2/4, no SwiftUI).
//
//  Raw `Authorization: <token>` header (NO Bearer). Mandatory URLSession timeouts.
//  Documented quirks honoured:
//    - door list success is `status == 1` with doors in `message[]`;
//    - commuter record_id == -2 (see AccessRoute);
//    - door_id == indexcode == the door's `key`;
//    - open success is `status == 0` OR `code == 200`.
//  HTTP / portal statuses are mapped onto PortalSessionError so the coordinator's
//  replay + credential-preservation logic works unchanged.
//

import Foundation

struct PortalAPI: PortalAuthAPI, Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = PortalAPI.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    // MARK: - PortalAuthAPI

    func login(_ credentials: PortalCredentials) async throws -> String {
        var request = makeRequest("/api/login", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try PortalCoding.encoder.encode(
            PortalLoginRequest(username: credentials.username, password: credentials.password)
        )

        let (data, http) = try await transport(request)
        if http.statusCode == 401 {
            // Portal login only 401s for bad credentials.
            throw PortalSessionError.credentialsRejected
        }
        try throwIfServerUnavailable(http)
        guard let parsed = try? PortalCoding.decoder.decode(PortalLoginResponse.self, from: data) else {
            throw PortalSessionError.incompatibleResponse
        }
        guard let token = parsed.token, !token.isEmpty else {
            // 2xx with no token generally means a rejected credential envelope.
            if (parsed.message ?? "").lowercased().contains("invalid") {
                throw PortalSessionError.credentialsRejected
            }
            throw PortalSessionError.incompatibleResponse
        }
        return token
    }

    func identity(token: String) async throws -> (studentID: Int, expiresAt: Date) {
        let request = makeRequest("/api/public/user_info", token: token)
        let (data, http) = try await transport(request)
        try throwIfExpired(http, data: data)
        try throwIfServerUnavailable(http)
        guard let parsed = try? PortalCoding.decoder.decode(PortalUserInfoResponse.self, from: data),
              let info = parsed.data else {
            throw PortalSessionError.incompatibleResponse
        }
        let expiresAt = info.exp.map { Date(timeIntervalSince1970: $0) }
            ?? Date().addingTimeInterval(30 * 60)
        return (info.id, expiresAt)
    }

    // MARK: - Access reads (safe to replay)

    func doorList(token: String) async throws -> [PortalDoor] {
        let request = makeRequest("/api/user/get_door_list", token: token)
        let (data, http) = try await transport(request)
        try throwIfExpired(http, data: data)
        try throwIfServerUnavailable(http)
        guard let parsed = try? PortalCoding.decoder.decode(PortalDoorListResponse.self, from: data) else {
            throw PortalSessionError.incompatibleResponse
        }
        // Success == status 1; empty message means unavailable, surfaced as [].
        guard parsed.isSuccess else { return [] }
        return parsed.message
    }

    func permits(token: String) async throws -> [PortalPermitRow] {
        let request = makeRequest("/api/exit/get_student_list", token: token)
        let (data, http) = try await transport(request)
        try throwIfExpired(http, data: data)
        try throwIfServerUnavailable(http)
        guard let parsed = try? PortalCoding.decoder.decode(PortalPermitListResponse.self, from: data) else {
            throw PortalSessionError.incompatibleResponse
        }
        return parsed.data?.rows ?? []
    }

    // MARK: - Access mutations (user-initiated, never auto-replayed)

    func applyPermit(_ application: PortalApplyPermitRequest, token: String) async throws -> PortalActionResponse {
        var request = makeRequest("/api/exit/add_record", method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try PortalCoding.encoder.encode(application)
        let (data, http) = try await transport(request)
        try throwIfExpired(http, data: data)
        try throwIfServerUnavailable(http)
        return (try? PortalCoding.decoder.decode(PortalActionResponse.self, from: data))
            ?? PortalActionResponse(status: nil, code: nil, message: nil)
    }

    /// Non-idempotent physical door open. A timeout is reported as
    /// `mutationOutcomeUnknown` — the caller must ask the user to verify
    /// physically rather than silently retrying.
    func openDoor(recordId: Int, doorKey: String, token: String) async throws -> PortalActionResponse {
        var request = makeRequest("/api/exit/update_door_flag", method: "POST", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try PortalCoding.encoder.encode(
            PortalOpenDoorRequest(recordId: recordId, doorKey: doorKey)
        )
        let (data, http): (Data, HTTPURLResponse)
        do {
            (data, http) = try await transport(request)
        } catch PortalSessionError.networkUnavailable {
            throw PortalSessionError.mutationOutcomeUnknown
        }
        try throwIfExpired(http, data: data)
        try throwIfServerUnavailable(http)
        return (try? PortalCoding.decoder.decode(PortalActionResponse.self, from: data))
            ?? PortalActionResponse(status: nil, code: nil, message: nil)
    }

    // MARK: - Transport & error mapping

    private func makeRequest(_ path: String, method: String = "GET", token: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let token {
            // NO Bearer prefix — the portal uses a raw opaque token.
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw PortalSessionError.incompatibleResponse
            }
            return (data, http)
        } catch let error as PortalSessionError {
            throw error
        } catch {
            throw PortalSessionError.networkUnavailable
        }
    }

    private func throwIfServerUnavailable(_ http: HTTPURLResponse) throws {
        if (500...599).contains(http.statusCode) {
            throw PortalSessionError.serverUnavailable(http.statusCode)
        }
    }

    /// Session expiry is HTTP 401 with portal `status == 400001` or
    /// `message == "Unauthorized"`.
    private func throwIfExpired(_ http: HTTPURLResponse, data: Data) throws {
        guard http.statusCode == 401 else { return }
        struct Envelope: Decodable { let status: Int?; let message: String? }
        let envelope = try? PortalCoding.decoder.decode(Envelope.self, from: data)
        if envelope?.status == 400001 || envelope?.message == "Unauthorized" {
            throw PortalSessionError.unauthorized
        }
        // Any other 401 on an authed endpoint is still an expired/invalid token.
        throw PortalSessionError.unauthorized
    }
}
