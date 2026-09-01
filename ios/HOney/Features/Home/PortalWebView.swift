//
//  PortalWebView.swift
//  HOney — the persistent School Portal browser (NOT a tab).
//
//  A single long-lived WKWebView backed by WKWebsiteDataStore.default(), kept
//  fully separate from the HOney native session and the Access connector session.
//  It remembers a *safe* last URL (excluding login / callback / logout / error
//  URLs) and, on a detected expiry, hands off to `PortalWebSessionBridge` to
//  silently rebuild the session. This controller holds NO authentication logic.
//

import SwiftUI
import WebKit

/// Long-lived controller so cookies + scroll position survive sheet dismissal.
@MainActor
final class PortalWebController: NSObject, WKNavigationDelegate {
    static let shared = PortalWebController()

    let webView: WKWebView
    private let lastURLKey = "portal.lastSafeURL"
    private var fallbackURL: URL?
    private var bridge: PortalWebSessionBridge?

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    /// Wire the portal-web session bridge (idempotent). Supplies it the safe URL
    /// to return to after a rebuild; the controller keeps no auth logic itself.
    func configure(coordinator: PortalSessionCoordinator) {
        guard bridge == nil else { return }
        let bridge = PortalWebSessionBridge(coordinator: coordinator)
        bridge.intendedURLProvider = { [weak self] in
            self?.savedSafeURL() ?? self?.fallbackURL
        }
        // Install on the web view's OWN content controller — WKWebView copies
        // its configuration at init, so the live handlers must go on the copy.
        bridge.install(on: webView.configuration.userContentController)
        bridge.attach(webView)
        self.bridge = bridge
    }

    func loadInitial(fallback: URL) {
        fallbackURL = fallback
        guard webView.url == nil else { return } // already loaded — reuse it
        let start = savedSafeURL() ?? fallback
        webView.load(URLRequest(url: start))
    }

    private func savedSafeURL() -> URL? {
        guard let string = UserDefaults.standard.string(forKey: lastURLKey),
              let url = URL(string: string) else { return nil }
        return url
    }

    private func isSafe(_ url: URL) -> Bool {
        let unsafe = ["login", "callback", "logout", "signin", "error", "oauth"]
        let lowered = url.absoluteString.lowercased()
        return !unsafe.contains { lowered.contains($0) }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url, isSafe(url) {
            UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Transient failures are left for the user to retry; do not clear state.
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let bridge,
           let http = navigationResponse.response as? HTTPURLResponse,
           bridge.isExpirySignal(httpStatus: http.statusCode) {
            // Session expired on a full navigation — cancel and let the bridge
            // rebuild it (the SPA's XHR-level 401s are caught by its injected
            // probe instead). This controller performs no auth itself.
            decisionHandler(.cancel)
            Task { await bridge.recover(reloading: savedSafeURL() ?? fallbackURL) }
            return
        }
        decisionHandler(.allow)
    }
}

struct PortalWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        PortalWebController.shared.webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct PortalWebScreen: View {
    let portalURL: URL
    let coordinator: PortalSessionCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PortalWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("School Portal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            PortalWebController.shared.webView.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Reload School Portal")
                    }
                }
                .onAppear {
                    PortalWebController.shared.configure(coordinator: coordinator)
                    PortalWebController.shared.loadInitial(fallback: portalURL)
                }
        }
    }
}
