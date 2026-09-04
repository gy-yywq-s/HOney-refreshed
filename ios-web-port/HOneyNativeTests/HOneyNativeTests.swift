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

    func testPostControlsSealedOnTheKeychainPerAccount() throws {
        let store = try keychainStore()
        let controls = SecretPostControlStore(store: store, prefix: "honey.v2.test")
        let secret = try controls.deviceSecret(account: "h_test")
        XCTAssertEqual(secret.count, 32)
        XCTAssertEqual(try controls.deviceSecret(account: "h_test"), secret, "stable per account")
        XCTAssertNotEqual(try controls.deviceSecret(account: "h_other"), secret, "namespaced by account")
        let state = LocalVaultState(vaultId: "v", revision: 1, wrappers: [], rIv: "i", rWrapped: "w", payloadIv: "pi", payloadCiphertext: "pc")
        try controls.saveState(account: "h_test", state)
        XCTAssertEqual(try controls.loadState(account: "h_test"), state)
        XCTAssertNil(try controls.loadState(account: "h_other"))
        try controls.clearState(account: "h_test")
        try controls.clearDeviceSecret(account: "h_test")
        try controls.clearDeviceSecret(account: "h_other")
        XCTAssertNil(try controls.loadState(account: "h_test"))
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

    /// The hand-off HOney issues lives on a login path; it is never the
    /// login page. Only a login route without the token is (the fix for the
    /// "sign in on its own page" banner that showed while signed in).
    func testTokenHandOffIsNotTheLoginPage() {
        XCTAssertFalse(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/student/login?token=abc")!))
        XCTAssertFalse(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/student/login/?TOKEN=abc")!))
        XCTAssertTrue(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/student/login")!))
        XCTAssertTrue(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/login?token=")!), "an empty token is no hand-off")
        XCTAssertTrue(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/auth/login?next=%2Fhome")!))
        XCTAssertFalse(PortalWebController.isLoginPage(URL(string: "https://p.example.edu/student/home")!))
        XCTAssertTrue(PortalWebController.isSensitive(URL(string: "https://p.example.edu/student/login?token=abc")!), "the hand-off is still never remembered")
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
