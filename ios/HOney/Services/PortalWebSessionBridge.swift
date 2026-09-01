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
    private static let loginPaths: Set<String> = ["/login", "/student/login", "/auth/login"]
    private static let loginHashes: Set<String> = ["#/login", "#/student/login", "#/auth/login"]

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
        Self.isKnownLoginRoute(url)
    }

    static func isKnownLoginRoute(_ url: URL) -> Bool {
        let path = normalizedRoute(url.path)
        let hash = normalizedHash(url.fragment)
        return loginPaths.contains(path) || loginHashes.contains(hash)
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
        return """
        (function(){
          var CH=\(channel);
          var PATHS={"/login":1,"/student/login":1,"/auth/login":1};
          var HASHES={"#/login":1,"#/student/login":1,"#/auth/login":1};
          function notify(){ try{ window.webkit.messageHandlers[CH].postMessage(location.href); }catch(e){} }
          function cleanPath(v){ v=(v||"/").toLowerCase(); if(v.length>1&&v.endsWith("/"))v=v.slice(0,-1); return v; }
          function cleanHash(v){ v=(v||"").toLowerCase().split("?")[0]; if(v.length>2&&v.endsWith("/"))v=v.slice(0,-1); return v; }
          function isLogin(u){ try{ var x=new URL(u,location.origin); return !!PATHS[cleanPath(x.pathname)]||!!HASHES[cleanHash(x.hash)]; }catch(e){ return false; } }
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

    private static func normalizedRoute(_ raw: String) -> String {
        var value = raw.lowercased()
        if value.count > 1, value.hasSuffix("/") { value.removeLast() }
        return value.isEmpty ? "/" : value
    }

    private static func normalizedHash(_ raw: String?) -> String {
        guard var value = raw?.lowercased(), !value.isEmpty else { return "" }
        value = "#" + value.split(separator: "?", maxSplits: 1).first.map(String.init)!
        if value.count > 2, value.hasSuffix("/") { value.removeLast() }
        return value
    }
}
