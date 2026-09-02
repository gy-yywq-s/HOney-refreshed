// The one error type the API layer throws. `code` mirrors the Web client's
// ApiError codes so the copy mapper (APIErrorCopy) is the same table:
// backend `{ error }` bodies pass through as-is; transport failures become
// `network_error`; 502/503 without a code become `portal_unavailable`;
// missing/expired sessions become `not_authenticated` / `session_expired`.

import Foundation

public struct APIError: Error, Sendable, Equatable, CustomStringConvertible {
    public let status: Int
    public let code: String

    public init(status: Int, code: String) {
        self.status = status
        self.code = code
    }

    public static let networkError = APIError(status: 0, code: "network_error")
    public static let notAuthenticated = APIError(status: 401, code: "not_authenticated")
    public static let sessionExpired = APIError(status: 401, code: "session_expired")

    public var description: String { "APIError(\(status), \(code))" }

    /// True for the codes the Web maps to "the school portal is unreachable".
    public var isPortalUnavailable: Bool {
        code == "portal_unavailable" || status == 502 || status == 503
    }

    /// The error a non-2xx response stands for (mirrors `toApiError` on the Web).
    static func from(status: Int, body: Data) -> APIError {
        var code = "http_\(status)"
        if let parsed = try? WireCoding.decode(APIErrorBody.self, from: body) {
            code = parsed.error
        }
        if (status == 502 || status == 503), code == "http_\(status)" {
            code = "portal_unavailable"
        }
        return APIError(status: status, code: code)
    }
}
