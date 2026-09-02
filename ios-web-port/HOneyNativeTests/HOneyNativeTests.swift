// App-level tests that need the simulator: the Keychain store, the
// identity-free publication transport's configuration, and the deep-link
// router. Everything else is covered on Linux in HOneyCoreTests.

import XCTest
import WebKit
import HOneyCore
@testable import HOneyNative

final class KeychainSecretStoreTests: XCTestCase {
    /// An unsigned simulator test host (CI, CODE_SIGNING_ALLOWED=NO) has no
    /// Keychain entitlement; these tests then skip and run on a signed build.
    private func keychainStore() throws -> KeychainSecretStore {
        let store = KeychainSecretStore(service: "com.gaelisus.honey.native.tests.\(UUID().uuidString)")
        do {
            try store.write("probe", Data("1".utf8))
            try store.delete("probe")
        } catch {
            throw XCTSkip("Keychain unavailable in this test host: \(error)")
        }
        return store
    }

    func testRoundTripAndPrefixEnumeration() throws {
        let store = try keychainStore()
        XCTAssertNil(try store.read("a"))
        try store.write("honey.keys.h1.e1", Data("k1".utf8))
        try store.write("honey.keys.h1.e2", Data("k2".utf8))
        try store.write("honey.session", Data("s".utf8))
        XCTAssertEqual(try store.read("honey.keys.h1.e1"), Data("k1".utf8))
        XCTAssertEqual(try store.keys(withPrefix: "honey.keys.h1."), ["honey.keys.h1.e1", "honey.keys.h1.e2"])
        try store.write("honey.keys.h1.e1", Data("k1b".utf8))
        XCTAssertEqual(try store.read("honey.keys.h1.e1"), Data("k1b".utf8), "update in place")
        try store.delete("honey.keys.h1.e1")
        XCTAssertNil(try store.read("honey.keys.h1.e1"))
        try store.delete("honey.keys.h1.e2")
        try store.delete("honey.session")
    }

    func testOwnershipKeysOnTheKeychainExportAndImport() throws {
        let store = try keychainStore()
        let keys = SecretOwnershipKeyStore(store: store, account: "h_test")
        try keys.add(key: "own-1", experienceId: "e-1")
        XCTAssertEqual(keys.count(), 1)
        let exported = try keys.exportJSON()
        let other = SecretOwnershipKeyStore(store: store, account: "h_other")
        XCTAssertEqual(other.count(), 0, "namespaced by account")
        XCTAssertEqual(try other.importJSON(exported), 1)
        try keys.remove(key: "own-1")
        try other.remove(key: "own-1")
    }
}

final class IdentityFreeTransportTests: XCTestCase {
    func testConfigurationCarriesNoCookiesOrCredentials() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        XCTAssertFalse(config.httpShouldSetCookies)
        XCTAssertNil(config.httpCookieStorage)
        XCTAssertNil(config.urlCredentialStorage)
        XCTAssertNil(config.urlCache)
        XCTAssertNotNil(URLSessionTransport.identityFree())
    }
}

@MainActor
final class PortalWebControllerTests: XCTestCase {
    /// WebKit only calls a delegate method whose selector it recognises. A
    /// spelling that "nearly matches" compiles, is never called, and leaves
    /// the allowlist inert — this is what 0fb6a8e shipped as a warning.
    func testNavigationPolicyDelegateIsBound() {
        let controller = PortalWebController()
        let selector = NSSelectorFromString("webView:decidePolicyForNavigationAction:decisionHandler:")
        XCTAssertTrue(controller.responds(to: selector))
        XCTAssertTrue(controller.responds(to: #selector(WKNavigationDelegate.webView(_:didFinish:))))
        XCTAssertTrue(controller.responds(to: #selector(WKNavigationDelegate.webViewWebContentProcessDidTerminate(_:))))
    }

    func testPolicyKeepsSchoolInsideAndRefusesPlainHTTP() {
        let controller = PortalWebController()
        controller.open(entry: nil, home: URL(string: "https://portal.example.edu/")!, allowedHosts: ["portal.example.edu"]) { nil }
        XCTAssertEqual(controller.policy(for: URL(string: "https://portal.example.edu/student/home")!), .allow)
        XCTAssertEqual(controller.policy(for: URL(string: "https://sub.portal.example.edu/x")!), .allow)
        XCTAssertEqual(controller.policy(for: URL(string: "http://portal.example.edu/")!), .cancel, "plain HTTP is refused")
        XCTAssertEqual(controller.policy(for: URL(string: "about:blank")!), .allow)
    }

    func testSensitiveURLsAreNeverKept() {
        XCTAssertTrue(PortalWebController.isSensitive(URL(string: "https://p.example.edu/student/login")!))
        XCTAssertTrue(PortalWebController.isSensitive(URL(string: "https://p.example.edu/entry?token=abc")!))
        XCTAssertFalse(PortalWebController.isSensitive(URL(string: "https://p.example.edu/student/home?tab=2")!))
    }
}

@MainActor
final class NavigatorTests: XCTestCase {
    func testDeepLinksMirrorWebPaths() {
        let nav = Navigator()
        nav.open(URL(string: "honey://experiences/teacher/t_1")!)
        XCTAssertEqual(nav.selected, .experiences)
        XCTAssertEqual(nav.experiencesPath, [.entity(.teacher, "t_1")])

        nav.open(URL(string: "honey://experiences/place/r_9")!)
        XCTAssertEqual(nav.experiencesPath, [.entity(.room, "r_9")], "legacy alias")

        nav.open(URL(string: "honey://experiences/compose?lessonId=L1&date=2026-09-02")!)
        XCTAssertEqual(nav.experiencesPath, [.compose(.lesson(id: "L1", date: "2026-09-02"))])

        nav.open(URL(string: "honey://timetable?date=2026-09-03&view=week")!)
        XCTAssertEqual(nav.selected, .timetable)
        XCTAssertEqual(nav.timetableIntent, TimetableIntent(date: "2026-09-03", view: .week))

        nav.open(URL(string: "honey://timetable?date=2026-13-45")!)
        XCTAssertEqual(nav.timetableIntent, TimetableIntent(date: nil, view: nil), "an impossible date is ignored")

        nav.open(URL(string: "honey://settings/privacy")!)
        XCTAssertEqual(nav.selected, .settings)
        XCTAssertEqual(nav.settingsPath, [.settingsPrivacy])

        nav.open(URL(string: "honey://access")!)
        XCTAssertEqual(nav.selected, .access)

        nav.open(URL(string: "https://example.com")!)
        XCTAssertEqual(nav.selected, .access, "foreign schemes are ignored")
    }

    func testPushPopOnSelectedTab() {
        let nav = Navigator()
        nav.selected = .home
        nav.push(.compose(nil))
        XCTAssertEqual(nav.homePath, [.compose(nil)])
        nav.pop()
        XCTAssertEqual(nav.homePath, [])
        nav.pop()
        XCTAssertEqual(nav.homePath, [])
    }
}
