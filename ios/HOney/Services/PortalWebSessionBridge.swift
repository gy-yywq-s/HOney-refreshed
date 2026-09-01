//
//  PortalWebSessionBridge.swift
//  HOney — restores an expired School Portal *WebView* session silently.
//
//  The OASIS web portal (Next.js SPA at /student) is TOKEN-based, NOT cookie-
//  based: login returns a top-level `token` and sets NO cookies. The SPA persists
//  it as `localStorage["token"]` and sends it on every API call as a raw
//  `Authorization: <token>` header (no Bearer — the portal's convention). On
//  expiry the SPA's API calls get HTTP 401 (`status == 400001`) and it routes to
//  `/student/login`.
//
//  So the bridge rebuilds the WebView session by injecting a FRESH token into the
//  web app's own storage key and reloading the intended page — it does NOT need
//  cookies, and it never has to automate the login form. All portal-web auth
//  lives here; the SwiftUI view / controller carries none. A failure here is
//  swallowed and confined to the Home portal-web area: it never signs the user
//  out of HOney and never touches Timetable / Access / Experiences.
//

import Foundation
import WebKit

@MainActor
final class PortalWebSessionBridge: NSObject, WKScriptMessageHandler {
    /// The localStorage key the web portal reads its `Authorization` token from.
    private static let tokenStorageKey = "token"
    /// JS -> native channel name for expiry signals.
    private static let messageHandlerName = "portalSession"
    /// Path fragment the SPA routes to when it drops an expired session.
    private static let loginRouteFragment = "login"

    private let coordinator: PortalSessionCoordinator
    private weak var webView: WKWebView?
    /// Supplies the *safe* page to return to after a rebuild (never the login
    /// route). Owned by the controller so the bridge holds no navigation state.
    var intendedURLProvider: (() -> URL?)?

    private var pendingIntendedURL: URL?
    private var isRecovering = false

    init(coordinator: PortalSessionCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - Installation

    /// Install the expiry-detection user script + message handler. Must be done
    /// on the content controller backing the live web view.
    func install(on userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        userContentController.add(self, name: Self.messageHandlerName)
        userContentController.addUserScript(WKUserScript(
            source: Self.expiryProbeSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }

    /// Attach the live web view the bridge injects into and reloads.
    func attach(_ webView: WKWebView) { self.webView = webView }

    // MARK: - Detection (single source of truth for "expired")

    /// True when a navigation URL is the portal's login route.
    func isExpirySignal(url: URL) -> Bool {
        url.absoluteString.lowercased().contains(Self.loginRouteFragment)
    }

    /// True for the portal's HTTP session-expiry status codes.
    func isExpirySignal(httpStatus: Int) -> Bool {
        httpStatus == 401 || httpStatus == 419
    }

    // MARK: - Recovery

    /// Rebuild the portal web session (fresh token -> web storage) and reload the
    /// intended page. Single-flight: concurrent triggers collapse into one pass.
    /// Returns `false` (never throws) so callers stay auth-logic-free.
    @discardableResult
    func recover(reloading intendedURL: URL? = nil) async -> Bool {
        guard !isRecovering else { return false }
        isRecovering = true
        defer { isRecovering = false }

        if let intendedURL { pendingIntendedURL = intendedURL }
        do {
            let token = try await coordinator.freshTokenForWebBridge()
            try await applyToken(token)
            reloadIntended()
            return true
        } catch {
            // Deliberately swallowed: portal-web only. Do NOT propagate — a bad
            // portal session must never sign the user out of HOney.
            return false
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName else { return }
        Task { await recover() }
    }

    // MARK: - Injection

    private func applyToken(_ token: String) async throws {
        guard let webView else { return }
        let literal = Self.jsStringLiteral(token)
        let key = Self.jsStringLiteral(Self.tokenStorageKey)
        // Ends in `true` so the async evaluateJavaScript gets a serializable
        // result (a bare setItem returns `undefined`, which the API rejects).
        let js = "(function(){try{localStorage.setItem(\(key), \(literal));}catch(e){}return true;})();"
        _ = try await webView.evaluateJavaScript(js)
    }

    private func reloadIntended() {
        guard let webView else { return }
        let target = pendingIntendedURL ?? intendedURLProvider?() ?? webView.url
        pendingIntendedURL = nil
        if let target {
            webView.load(URLRequest(url: target))
        } else {
            webView.reload()
        }
    }

    // MARK: - JS helpers

    /// A JSON string literal is also a safe JS string literal.
    private static func jsStringLiteral(_ value: String) -> String {
        if let data = try? JSONEncoder().encode(value),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\"\""
    }

    /// Injected at documentStart in every frame: reports SPA login-route hops and
    /// API 401/419s back to native so the bridge can rebuild the session. It is a
    /// pure signal — it carries no credentials or token.
    private static var expiryProbeSource: String {
        let channel = jsStringLiteral(messageHandlerName)
        let loginFragment = jsStringLiteral(loginRouteFragment)
        return """
        (function(){
          var CH=\(channel);
          function notify(){ try{ window.webkit.messageHandlers[CH].postMessage(location.href); }catch(e){} }
          function isLogin(u){ try{ return (""+u).toLowerCase().indexOf(\(loginFragment))>=0; }catch(e){ return false; } }
          var _push=history.pushState, _replace=history.replaceState;
          history.pushState=function(){ var r=_push.apply(this,arguments); if(isLogin(location.href)) notify(); return r; };
          history.replaceState=function(){ var r=_replace.apply(this,arguments); if(isLogin(location.href)) notify(); return r; };
          window.addEventListener("popstate", function(){ if(isLogin(location.href)) notify(); });
          if(window.fetch){
            var _fetch=window.fetch;
            window.fetch=function(){
              return _fetch.apply(this,arguments).then(function(res){
                try{ if(res && (res.status===401 || res.status===419)) notify(); }catch(e){}
                return res;
              });
            };
          }
        })();
        """
    }
}
