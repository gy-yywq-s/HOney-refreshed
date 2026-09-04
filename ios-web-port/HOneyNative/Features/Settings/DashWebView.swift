// Settings › Admin › Dash. The operational console is a Web-only surface, so
// it is shown here in a WKWebView on the HOney origin instead of being handed
// to Safari, where the student would have to sign in a second time (Gary
// 2026-09-04).
//
// The session is not passed in a URL, a query item or a header: a
// document-start user script writes the same `HOney.session` localStorage
// entry the Web client writes after its own login, on the same origin, so the
// Web app finds the session already there and never shows /login. The tokens
// are never logged and never leave that origin; the web view runs in a
// non-persistent data store, so closing Dash leaves nothing behind on disk.

import SwiftUI
import WebKit
import Observation
import HOneyCore

@MainActor
@Observable
final class DashWebController: NSObject, WKNavigationDelegate {
    private(set) var loading = true
    private(set) var failure: String?

    let webView: WKWebView

    init(session: SessionTokens?) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        if let session, let json = try? WireCoding.encode(session), let text = String(data: json, encoding: .utf8) {
            // JSON is injected as a JSON string literal, so nothing in a token
            // can close the script; the value is the Web client's own shape.
            let escaped = String(data: (try? JSONSerialization.data(withJSONObject: text, options: .fragmentsAllowed)) ?? Data("\"\"".utf8), encoding: .utf8) ?? "\"\""
            let source = "try { window.localStorage.setItem('HOney.session', \(escaped)); } catch (e) {}"
            config.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            )
        }
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        loading = true
        failure = nil
        webView.load(URLRequest(url: url))
    }

    func reload() {
        failure = nil
        webView.reload()
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.loading = false }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.loading = false
            self.failure = L10n.t("Could not open Dash.")
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.loading = false
            self.failure = L10n.t("Could not open Dash.")
        }
    }
}

private struct DashWebRepresentable: UIViewRepresentable {
    let controller: DashWebController

    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct DashWebScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @State private var controller: DashWebController?

    var body: some View {
        Group {
            if let controller {
                VStack(spacing: 0) {
                    if let failure = controller.failure {
                        Text(failure)
                            .font(.footnote)
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(HSpace.x2)
                    }
                    DashWebRepresentable(controller: controller)
                        .ignoresSafeArea(edges: .bottom)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button { controller.goBack() } label: { Image(systemName: "chevron.left") }
                        Button { controller.reload() } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .webScreen(title: L10n.t("Dash"))
        .task {
            guard controller == nil else { return }
            let made = DashWebController(session: try? env.sessionStore.load())
            controller = made
            made.load(env.config.dashURL)
        }
    }
}
