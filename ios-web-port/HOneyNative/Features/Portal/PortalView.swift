// A newly written WKWebView surface for the official portal (spec §23.2):
// persistent website state across openings within one account, last useful
// page restored, stale entry recovered without ejecting the student,
// HTTPS-only allowlisted hosts, external links to the system browser, no
// JavaScript form filling. An account change wipes the page, the history
// and the website data (review 11d42e3 §3.1.5, §4.2).

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
/// session and the last page the student was on — for one account.
@MainActor
final class PortalWebController: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = PortalWebController()

    /// Stored defaults only, so the singleton can be created outside the actor.
    nonisolated override init() {
        super.init()
    }

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
    private var openGeneration = 0
    private var deadline: Task<Void, Never>?
    private static let openDeadline: TimeInterval = 25
    private static let loginPaths: Set<String> = ["/login", "/student/login", "/auth/login"]

    /// A path the portal uses for signing in. This is a route, not a verdict:
    /// the signed-in hand-off HOney issues (`/student/login?token=…`, routes/
    /// data.ts) lives on the same path as the form a student has to fill in.
    static func isLoginRoute(_ url: URL) -> Bool {
        var path = url.path.lowercased()
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return loginPaths.contains(path)
    }

    /// The portal has actually put the student in front of its login form.
    ///
    /// Root cause of the banner that showed while signed in (Gary 2026-09-04):
    /// the portal is a Next.js app, so the token hand-off finishes loading AT
    /// `/student/login?token=…` and routes to home client-side, with no further
    /// navigation callback. Judged by path alone, that finish "landed on the
    /// login page": recovery renewed the token, loaded another hand-off on
    /// the same path, and the second finish — recovery already spent — became
    /// `.actionRequired`, which then stuck while the student browsed signed in.
    ///
    /// The hand-off is not evidence of anything: HOney verifies the token
    /// against the school (`userInfo`) before it hands the entry out, and
    /// `signedInEntry` keeps a margin on its expiry, so a hand-off with a dead
    /// token is prevented upstream, not detected here. What this surface CAN
    /// know is that the portal answered with a login route carrying no
    /// hand-off — a bounce to the form — and that is the only login page.
    static func isLoginPage(_ url: URL) -> Bool {
        guard isLoginRoute(url) else { return false }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let handOff = items.contains { $0.name.lowercased() == "token" && !($0.value ?? "").isEmpty }
        return !handOff
    }

    /// A URL that carries credentials or a sign-in hand-off: never kept as
    /// the "last page", never shown as shareable.
    static func isSensitive(_ url: URL) -> Bool {
        if isLoginRoute(url) { return true }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let secretNames: Set<String> = ["token", "access_token", "auth", "password", "code", "ticket"]
        return items.contains { secretNames.contains($0.name.lowercased()) }
    }

    /// Open the portal: a fresh signed-in entry when one is prepared, else
    /// the last safe page (already loaded), else the portal home.
    func open(entry: URL?, home: URL, allowedHosts: Set<String>, recover: @escaping @MainActor () async -> URL?) {
        self.allowedHosts = allowedHosts
        self.recover = recover
        recoveryAttempted = false
        if let entry {
            load(entry)
        } else if lastSafeURL != nil, webView.url != nil {
            phase = .loaded
        } else {
            load(home)
        }
    }

    private func load(_ url: URL) {
        openGeneration += 1
        let gen = openGeneration
        phase = .opening
        webView.load(URLRequest(url: url))
        deadline?.cancel()
        deadline = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.openDeadline * 1_000_000_000))
            guard let self, !Task.isCancelled, gen == self.openGeneration, self.phase == .opening else { return }
            self.webView.stopLoading()
            self.phase = .unavailable("The school portal did not answer in time.")
        }
    }

    func reload() {
        if let url = webView.url ?? lastSafeURL { load(url) }
    }

    func goBack() { webView.goBack() }

    /// Another HOney account (or none): drop the page, its history, and the
    /// website data the school portal stored for the previous student.
    func resetForAccountChange() async {
        openGeneration += 1
        deadline?.cancel()
        recover = nil
        lastSafeURL = nil
        recoveryAttempted = false
        phase = .preparing
        canGoBack = false
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await store.removeData(ofTypes: types, modifiedSince: .distantPast)
    }

    // MARK: WKNavigationDelegate

    // The async form is the one WebKit binds under strict concurrency; the
    // completion-handler spelling "nearly matched" and was never called, which
    // would have left the allowlist inert (CI warning on 0fb6a8e).
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        return policy(for: url)
    }

    /// HTTPS to an allowlisted school host stays inside; anything else outside
    /// the school opens in the system browser; plain HTTP is refused.
    func policy(for url: URL) -> WKNavigationActionPolicy {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" || scheme == "data" { return .allow }
        guard scheme == "https", let host = url.host?.lowercased() else { return .cancel }
        if allowedHosts.contains(host) || allowedHosts.contains(where: { host.hasSuffix("." + $0) }) {
            return .allow
        }
        UIApplication.shared.open(url)
        return .cancel
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if phase != .reconnecting { phase = .opening }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        deadline?.cancel()
        canGoBack = webView.canGoBack
        guard let url = webView.url else { phase = .loaded; return }
        if Self.isLoginPage(url) {
            // The portal bounced to its form: the session ended. Renew once.
            guard !recoveryAttempted, let recover else {
                phase = .actionRequired
                return
            }
            recoveryAttempted = true
            phase = .reconnecting
            let gen = openGeneration
            Task { @MainActor in
                let fresh = await recover()
                guard gen == self.openGeneration else { return }
                if let fresh {
                    self.load(fresh)
                } else {
                    self.phase = .actionRequired
                }
            }
            return
        }
        if !Self.isSensitive(url) { lastSafeURL = url }
        phase = .loaded
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        deadline?.cancel()
        phase = .unavailable("The school portal did not respond.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        deadline?.cancel()
        phase = .unavailable("The school portal is unreachable right now.")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // WebKit dropped the page (memory pressure): bring the last safe page back.
        if let url = lastSafeURL { load(url) } else { phase = .unavailable("The page was closed by the system. Reopen the portal.") }
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
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("Done")) { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { web.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!web.canGoBack)
                        .accessibilityLabel(L10n.t("Back"))
                    Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload")
                }
            }
        }
        .task {
            await env.portal.prewarm()
            web.open(entry: env.portal.signedInEntry, home: env.config.portalHome, allowedHosts: env.config.portalHosts) {
                // Landing on the portal's login page means the token HOney
                // holds is dead: renew from the school with the saved login.
                await env.portal.recoverAfterLoginPage()
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
            InlineStatusBanner(text: env.portal.lastError ?? "The portal needs you to sign in on its own page. Your HOney account is unaffected.", tone: .warning).pageInset().padding(.vertical, HSpace.x2)
        case .unavailable(let message):
            InlineStatusBanner(text: message, tone: .warning, action: ("Retry", { web.reload() })).pageInset().padding(.vertical, HSpace.x2)
        case .loaded:
            EmptyView()
        }
    }
}
