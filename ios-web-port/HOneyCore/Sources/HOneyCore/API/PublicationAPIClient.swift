// Step 3 of publication — POST /api/experiences/publish — on its own client
// (spec §3.4). It has no session store, takes no token, and is built on a
// transport with no cookies or credential storage, so the request carries
// exactly what the contract allows: eligibility token, content-bound pass,
// body and the permitted rating. Tests prove Authorization and Cookie
// headers are absent.

import Foundation

public actor PublicationAPIClient {
    public let baseURL: URL
    private let transport: HTTPTransport

    public init(baseURL: URL, transport: HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func publish(_ input: PublishExperienceInput) async throws -> PublishExperienceResponse {
        let body = try WireCoding.encode(input)
        let request = HTTPRequest(
            method: "POST",
            url: baseURL.appendingPathComponent("/api/experiences/publish"),
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: body
        )
        let response = try await transport.send(request)
        guard (200..<300).contains(response.status) else {
            throw APIError.from(status: response.status, body: response.body)
        }
        return try WireCoding.decode(PublishExperienceResponse.self, from: response.body)
    }
}
