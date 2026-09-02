// The seam between the API clients and the network. Production uses
// URLSession; tests use a scripted transport that also records every
// request, which is how the "publish sends no session" proof is written.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public struct HTTPRequest: Sendable, Equatable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPTransport: Sendable {
    /// Performs the request. Throws only for transport failures (no
    /// connection, timeout); an HTTP error status is a normal response.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// URLSession-backed transport. The publication client gets its own
/// instance built on an ephemeral, cookie-less configuration (see
/// `URLSessionTransport.identityFree()`), so the identity-free publish can
/// never ride on ambient cookies or cached credentials.
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }

    /// No cookies, no credential storage, no cache, no shared state.
    public static func identityFree() -> URLSessionTransport {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSessionTransport(configuration: config)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.timeoutInterval = 30
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .cancelled {
            // A cancelled request is not a network failure the student should see.
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.networkError
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let k = key as? String, let v = value as? String { headers[k] = v }
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
