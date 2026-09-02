import Foundation
import XCTest
@testable import HOneyCore

/// The checked-in contract fixtures (packages/shared/fixtures/api).
enum Fixtures {
    static var directory: URL {
        // …/ios-web-port/HOneyCore/Tests/HOneyCoreTests/Support.swift → repo root
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("packages/shared/fixtures/api")
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try WireCoding.decode(type, from: try data(name))
    }

    static var names: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }
}

/// A transport that answers from a script and records every request.
final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (HTTPRequest) async throws -> HTTPResponse

    private let lock = NSLock()
    private(set) var requests: [HTTPRequest] = []
    private var handlers: [Handler] = []
    var fallback: Handler

    init(_ fallback: @escaping Handler = { _ in HTTPResponse(status: 404) }) {
        self.fallback = fallback
    }

    func enqueue(_ handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        handlers.append(handler)
    }

    func enqueue(status: Int, json: String) {
        enqueue { _ in HTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: Data(json.utf8)) }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.lock()
        requests.append(request)
        let handler = handlers.isEmpty ? fallback : handlers.removeFirst()
        lock.unlock()
        return try await handler(request)
    }

    var lastRequest: HTTPRequest? { lock.lock(); defer { lock.unlock() }; return requests.last }
    var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
    func request(at index: Int) -> HTTPRequest { lock.lock(); defer { lock.unlock() }; return requests[index] }
}

func json(_ value: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: value)
}

/// Pins the domain clock to the school zone and a fixed instant for a test.
struct PinnedClock {
    static let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    static func at(_ iso: String, _ body: () throws -> Void) rethrows {
        let previousZone = HOneyClock.timeZone
        let previousNow = HOneyClock.now
        HOneyClock.timeZone = shanghai
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let now = f.date(from: iso)!
        HOneyClock.now = { now }
        defer {
            HOneyClock.timeZone = previousZone
            HOneyClock.now = previousNow
        }
        try body()
    }

    static func shanghaiDate(_ text: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = shanghai
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: text)!
    }

    static func ms(_ text: String) -> Int64 { shanghaiDate(text).epochMillis }
}

func XCTAssertThrowsPortal(_ expected: PortalError, _ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        try await body()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch let error as PortalError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("expected \(expected), got \(error)", file: file, line: line)
    }
}
