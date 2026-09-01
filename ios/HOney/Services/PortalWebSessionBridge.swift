//
//  PortalWebSessionBridge.swift
//  HOney — expiry detection and token injection for the School Portal WebView.
//

import Foundation
import WebKit

@MainActor
final class PortalWebSessionBridge: NSObject, WKScriptMessageHandler {
    private static let tokenStorageKey = "token"
    private static let messageHandlerName = "portalSession"
    private static let loginRouteFragment = "login"

    private let coordinator: PortalSessionCoordinator
    private weak var webView: WKWebView?

    var intendedURLProvider: (() -> URL?)?
    var onExpirySignal: (() -> Void)?

    init(coordinator: PortalSessionCoordinator) {
        self.coordinator = coordinator
    }

    func install(on userContentController: WKUserContentController) {
        userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        userContentController.add(self, name: Self.messageHandlerName)
        userContentController.addUserScript(WKUserScript(
            source: Self.expiryProbeSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
    }

    func attach(_ webView: WKWebView) { self.webView = webView }

    func isExpirySignal(url: URL) -> Bool {
        url.absoluteString.lowercased().contains(Self.loginRouteFragment)
    }

    func isExpirySignal(httpStatus: Int) -> Bool {
        httpStatus == 401 || httpStatus == 419
    }

    func freshToken() async throws -> String {
        try Task.checkCancellation()
        return try await coordinator.freshTokenForWebBridge()
    }

    func applyToken(_ token: String) async throws {
        try Task.checkCancellation()
        guard let webView else { throw PortalSessionError.incompatibleResponse }
        let literal = Self.jsStringLiteral(token)
        let key = Self.jsStringLiteral(Self.tokenStorageKey)
        let js = "(function(){try{localStorage.setItem(\(key), \(literal));}catch(e){}return true;})();"
        _ = try await webView.evaluateJavaScript(js)
        try Task.checkCancellation()
    }

    func intendedURL() -> URL? { intendedURLProvider?() ?? webView?.url }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName else { return }
        onExpirySignal?()
    }

    private static func jsStringLiteral(_ value: String) -> String {
        if let data = try? JSONEncoder().encode(value),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\"\""
    }

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
          if(isLogin(location.href)) notify();
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
