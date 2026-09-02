// A newly written WKWebView surface for the official portal (spec §23.2):
// persistent website state across openings, last useful page restored,
// stale entry recovered without ejecting the student, allowlisted hosts
// only, external links to the system browser, no JavaScript form filling.

import SwiftUI
import WebKit
import HOneyCore

enum PortalPhase: Equatable {
    case preparing
    case opening
    case loaded
    case reconnecting
    case actionRequired
    case unavailable(String)
}

/// One WKWebView for the life of the app, so the portal keeps its own
/// session and the last page the student was on.
@MainActor
final class PortalWebController: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = PortalWebController()

    @Published private(set) var phase: PortalPhase = .preparing
    @Published private(set) var canGoBack = false
    private(set) lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
        return view
    }()

    private var allowedHosts: Set<String> = []
    private var lastSafeURL: URL?
    private var recoveryAttempted = false
    private var recover: (@MainActor () async -> URL?)?
    private static let loginPaths: Set<String> = ["/login", "/student/login", "/auth/login"]

    static func isLoginRoute(_ url: URL) -> Bool {
        var path = url.path.lowercased()
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return loginPaths.contains(path)
    }

    /// Open the portal: a fresh signed-in entry when one is prepared, else
    /// the last safe page, else the portal home.
    func open(entry: URL?, home: URL, allowedHosts: Set<String>, recover: @escaping @MainActor () async -> URL?) {
        self.allowedHosts = allowedHosts
        self.recover = recover
        recoveryAttempted = false
        if let entry {
            phase = .opening
            webView.load(URLRequest(url: entry))
        } else if let lastSafeURL, webView.url != nil {
            phase = .loaded
            _ = lastSafeURL
        } else {
            phase = .opening
            webView.load(URLRequest(url: home))
        }
    }

    func reload() {
        phase = .opening
        webView.reload()
    }

    func goBack() { webView.goBack() }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" || scheme == "data" { decisionHandler(.allow); return }
        guard scheme == "https" || scheme == "http", let host = url.host?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        if allowedHosts.contains(host) || allowedHosts.contains { host.hasSuffix("." + $0) } {
            decisionHandler(.allow)
        } else {
            // Outside the school: the system browser, never inside HOney.
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if phase != .reconnecting { phase = .opening }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canGoBack = webView.canGoBack
        guard let url = webView.url else { phase = .loaded; return }
        if Self.isLoginRoute(url) {
            // The entry was spent or the portal session ended: renew once.
            guard !recoveryAttempted, let recover else {
                phase = .actionRequired
                return
            }
            recoveryAttempted = true
            phase = .reconnecting
            Task { @MainActor in
                if let fresh = await recover() {
                    webView.load(URLRequest(url: fresh))
                } else {
                    phase = .actionRequired
                }
            }
            return
        }
        lastSafeURL = url // never a login/token URL: those return above
        phase = .loaded
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        phase = .unavailable("The school portal did not respond.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        phase = .unavailable("The school portal is unreachable right now.")
    }
}

struct PortalWebViewRepresentable: UIViewRepresentable {
    let controller: PortalWebController

    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Full-screen portal surface with a compact bar: Done · title · Back/Reload.
struct PortalView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @StateObject private var web = PortalWebController.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBanner
                PortalWebViewRepresentable(controller: web)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("School Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { web.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!web.canGoBack)
                        .accessibilityLabel("Back")
                    Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload")
                }
            }
        }
        .task {
            await env.portal.prewarm()
            web.open(entry: env.portal.signedInEntry, home: env.config.portalHome, allowedHosts: env.config.portalHosts) {
                env.portal.invalidateEntry()
                await env.portal.prewarm(force: true)
                return env.portal.signedInEntry
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch web.phase {
        case .preparing, .opening:
            ProgressView().padding(.vertical, HSpace.x2)
        case .reconnecting:
            InlineStatusBanner(text: "Reconnecting to the school portal…", tone: .info).pageInset().padding(.vertical, HSpace.x2)
        case .actionRequired:
            InlineStatusBanner(text: "The portal needs you to sign in on its own page. Your HOney account is unaffected.", tone: .warning).pageInset().padding(.vertical, HSpace.x2)
        case .unavailable(let message):
            InlineStatusBanner(text: message, tone: .warning, action: ("Retry", { web.reload() })).pageInset().padding(.vertical, HSpace.x2)
        case .loaded:
            EmptyView()
        }
    }
}
