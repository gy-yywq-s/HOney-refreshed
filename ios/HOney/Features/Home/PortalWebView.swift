//
//  PortalWebView.swift
//  HOney — the persistent School Portal browser (NOT a tab).
//
//  A single long-lived WKWebView backed by WKWebsiteDataStore.default(), kept
//  fully separate from the HOney native session and the Access connector session.
//  It remembers a *safe* last URL (excluding login / callback / logout / error
//  URLs) and silently reloads when it detects an expired session.
//

import SwiftUI
import WebKit

/// Long-lived controller so cookies + scroll position survive sheet dismissal.
@MainActor
final class PortalWebController: NSObject, WKNavigationDelegate {
    static let shared = PortalWebController()

    let webView: WKWebView
    private let lastURLKey = "portal.lastSafeURL"
    private var didAttemptExpiryReload = false

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func loadInitial(fallback: URL) {
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
            didAttemptExpiryReload = false
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
        if let http = navigationResponse.response as? HTTPURLResponse,
           http.statusCode == 401 || http.statusCode == 419,
           !didAttemptExpiryReload {
            // Session expired — silently reload the portal root once.
            didAttemptExpiryReload = true
            decisionHandler(.cancel)
            if let host = webView.url {
                webView.load(URLRequest(url: host))
            }
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
                    }
                }
                .onAppear {
                    PortalWebController.shared.loadInitial(fallback: portalURL)
                }
        }
    }
}
