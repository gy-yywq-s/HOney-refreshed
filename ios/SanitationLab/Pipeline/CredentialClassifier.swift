//
//  CredentialClassifier.swift
//  SanitationLab — the one remote question: is this a credential?
//
//  The derivative JPEG is the whole request body (image/jpeg). No account, no
//  cookie, no filename travels with it — the route sits in the identity-free
//  Community process and refuses session material anyway.
//

import Foundation

protocol CredentialClassifier: Sendable {
    func classify(jpeg: Data) async -> ClassifierAnswer
}

struct RemoteCredentialClassifier: CredentialClassifier {
    var baseURL: URL
    /// The pipeline reserves the remaining hard-gate time for local work.
    var timeout: TimeInterval = 3.2

    private struct Wire: Decodable {
        let credentialLike: Bool
        let uncertain: Bool
        let latencyMs: Int?
        let model: String?
    }

    func classify(jpeg: Data) async -> ClassifierAnswer {
        var request = URLRequest(url: baseURL.appendingPathComponent("community/v2/image/classify"))
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpShouldHandleCookies = false
        request.timeoutInterval = timeout
        let started = Date()
        do {
            let (data, response) = try await Self.session.upload(for: request, from: jpeg)
            let elapsed = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .unavailable(latencyMs: elapsed)
            }
            let wire = try JSONDecoder().decode(Wire.self, from: data)
            return ClassifierAnswer(available: true, credentialLike: wire.credentialLike, uncertain: wire.uncertain, latencyMs: elapsed, model: wire.model)
        } catch {
            return .unavailable(latencyMs: Int(Date().timeIntervalSince(started) * 1000))
        }
    }

    /// Ephemeral, cookie-less: nothing about the device or account is sent.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
}

/// For the harness: answers from a fixed table (or a fixed value) with a
/// simulated delay, so detector/sanitizer behaviour is tested without network.
struct StubCredentialClassifier: CredentialClassifier {
    var credentialLike: Bool
    var uncertain: Bool = false
    var available: Bool = true
    var delayMs: Int = 0

    func classify(jpeg: Data) async -> ClassifierAnswer {
        if delayMs > 0 { try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000) }
        return available
            ? ClassifierAnswer(available: true, credentialLike: credentialLike, uncertain: uncertain, latencyMs: delayMs, model: "stub")
            : .unavailable(latencyMs: delayMs)
    }
}

extension ClassifierAnswer {
    static func unavailable(latencyMs: Int) -> ClassifierAnswer {
        ClassifierAnswer(available: false, credentialLike: false, uncertain: true, latencyMs: latencyMs, model: nil)
    }
}
