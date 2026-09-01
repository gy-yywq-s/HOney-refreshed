//
//  PortalWebView.swift
//  HOney — persistent School Portal browser with one cancellable open attempt.
//

import Combine
import SwiftUI
import UIKit
import WebKit
import os.signpost

enum PortalWebPhase: Equatable {
    case idle
    case preparing
    case loading(Double)
    case authenticating
    case content
    case failed(String)
    case timedOut

    var isWorking: Bool {
        switch self {
        case .preparing, .loading, .authenticating: return true
        default: return false
        }
    }
}

@MainActor
final class PortalWebController: NSObject, ObservableObject, WKNavigationDelegate {
    static let shared = PortalWebController()

    @Published private(set) var phase: PortalWebPhase = .idle

    let webView: WKWebView
    private let lastURLKey = "portal.lastSafeURL"
    private let signpostLog = OSLog(subsystem: "com.gaelisus.honey", category: "SchoolPortal")
    private let overallDeadline: Duration = .seconds(12)

    private var fallbackURL: URL?
    private var bridge: PortalWebSessionBridge?
    private var timeoutTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var progressObservation: NSKeyValueObservation?
    private var activeNavigation: WKNavigation?
    private var lastSuccessfullyFinishedURL: URL?
    private var attempt = 0
    private var signpostID: OSSignpostID?

    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor [weak self] in
                guard let self, case .loading = self.phase else { return }
                self.phase = .loading(webView.estimatedProgress)
            }
        }
    }

    func prepare(coordinator: PortalSessionCoordinator) {
        configure(coordinator: coordinator)
    }

    func configure(coordinator: PortalSessionCoordinator) {
        guard bridge == nil else { return }
        let bridge = PortalWebSessionBridge(coordinator: coordinator)
        bridge.intendedURLProvider = { [weak self] in
            self?.savedSafeURL() ?? self?.fallbackURL
        }
        bridge.onExpirySignal = { [weak self] in self?.startRecovery() }
        bridge.install(on: webView.configuration.userContentController)
        bridge.attach(webView)
        self.bridge = bridge
    }

    func open(fallback: URL) {
        fallbackURL = fallback
        if let finished = lastSuccessfullyFinishedURL,
           webView.url == finished,
           !webView.isLoading {
            phase = .content
            return
        }

        let id = beginAttempt()
        phase = .preparing
        startNavigation(savedSafeURL() ?? fallback, attempt: id)
    }

    func retry() {
        let id = beginAttempt()
        startNavigation(savedSafeURL() ?? fallbackURL ?? webView.url, attempt: id)
    }

    func cancelActiveWork() {
        invalidateAttempt(result: "cancel", stopWebView: true)
        if phase.isWorking { phase = .idle }
    }

    private func beginAttempt() -> Int {
        invalidateAttempt(result: "superseded", stopWebView: true)
        let id = attempt
        let signpostID = OSSignpostID(log: signpostLog)
        self.signpostID = signpostID
        os_signpost(.begin, log: signpostLog, name: "PortalOpen", signpostID: signpostID, "attempt=%d", id)
        armAbsoluteDeadline(for: id)
        return id
    }

    private func invalidateAttempt(result: String, stopWebView: Bool) {
        timeoutTask?.cancel()
        timeoutTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        activeNavigation = nil
        if stopWebView, webView.isLoading {
            lastSuccessfullyFinishedURL = nil
            webView.stopLoading()
        }
        if let signpostID {
            os_signpost(.end, log: signpostLog, name: "PortalOpen", signpostID: signpostID, "%{public}@", result)
            self.signpostID = nil
        }
        attempt += 1
    }

    private func armAbsoluteDeadline(for id: Int) {
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: self?.overallDeadline ?? .seconds(12))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.attempt == id, self.phase.isWorking else { return }
                    self.recoveryTask?.cancel()
                    self.recoveryTask = nil
                    self.activeNavigation = nil
                    self.webView.stopLoading()
                    self.lastSuccessfullyFinishedURL = nil
                    self.phase = .timedOut
                    self.invalidateAttempt(result: "timeout", stopWebView: false)
                }
            } catch {}
        }
    }

    private func startNavigation(_ url: URL?, attempt id: Int) {
        guard attempt == id else { return }
        guard let url else {
            phase = .failed("The School Portal address is unavailable.")
            invalidateAttempt(result: "missing-url", stopWebView: false)
            return
        }
        phase = .loading(0)
        activeNavigation = webView.load(URLRequest(
            url: url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 12
        ))
    }

    private func startRecovery() {
        guard recoveryTask == nil, let bridge, phase != .timedOut else { return }
        let id = signpostID == nil ? beginAttempt() : attempt
        activeNavigation = nil
        webView.stopLoading()
        phase = .authenticating

        recoveryTask = Task { [weak self] in
            do {
                let token = try await bridge.freshToken()
                try Task.checkCancellation()
                guard let self, self.attempt == id else { return }
                try await bridge.applyToken(token)
                try Task.checkCancellation()
                guard self.attempt == id else { return }
                self.recoveryTask = nil
                self.startNavigation(bridge.intendedURL(), attempt: id)
            } catch is CancellationError {
                // Cancellation belongs to timeout, dismissal or a newer attempt.
            } catch {
                guard let self, self.attempt == id else { return }
                self.recoveryTask = nil
                self.phase = .failed("HOney could not restore School Portal access. Try again or close the portal.")
                self.invalidateAttempt(result: "recovery-failed", stopWebView: true)
            }
        }
    }

    private func savedSafeURL() -> URL? {
        guard let string = UserDefaults.standard.string(forKey: lastURLKey),
              let url = URL(string: string), !isUnsafe(url) else { return nil }
        return url
    }

    private func isUnsafe(_ url: URL) -> Bool {
        let unsafe = ["login", "callback", "logout", "signin", "error", "oauth"]
        let lowered = url.absoluteString.lowercased()
        return unsafe.contains { lowered.contains($0) }
    }

    private func shouldHandleExpiry(_ url: URL?) -> Bool {
        guard phase == .content || phase.isWorking,
              let url,
              let expectedHost = fallbackURL?.host,
              url.host == expectedHost else { return false }
        return bridge?.isExpirySignal(url: url) == true
    }

    private func isActive(_ navigation: WKNavigation?) -> Bool {
        guard let navigation, let activeNavigation else { return false }
        return navigation === activeNavigation
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard isActive(navigation) else { return }
        phase = .loading(0)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard isActive(navigation) else { return }
        phase = .loading(max(0.08, webView.estimatedProgress))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard isActive(navigation) else { return }
        if let url = webView.url, !isUnsafe(url) {
            lastSuccessfullyFinishedURL = url
            UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
        }
        phase = .content
        invalidateAttempt(result: "content", stopWebView: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(navigation, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(navigation, error: error)
    }

    private func handleNavigationFailure(_ navigation: WKNavigation?, error: Error) {
        guard isActive(navigation) else { return }
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        lastSuccessfullyFinishedURL = nil
        phase = .failed("The School Portal could not load. Check your connection and try again.")
        invalidateAttempt(result: "navigation-failed", stopWebView: false)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        lastSuccessfullyFinishedURL = nil
        phase = .failed("The School Portal stopped responding. Reload it to continue.")
        invalidateAttempt(result: "web-process-terminated", stopWebView: false)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if shouldHandleExpiry(navigationAction.request.url) {
            decisionHandler(.cancel)
            startRecovery()
            return
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if (phase == .content || phase.isWorking),
           navigationResponse.response.url?.host == fallbackURL?.host,
           let http = navigationResponse.response as? HTTPURLResponse,
           bridge?.isExpirySignal(httpStatus: http.statusCode) == true {
            decisionHandler(.cancel)
            startRecovery()
            return
        }
        decisionHandler(.allow)
    }
}

struct PortalWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { PortalWebController.shared.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct PortalWebScreen: View {
    let portalURL: URL
    let coordinator: PortalSessionCoordinator
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var controller = PortalWebController.shared
    @AccessibilityFocusState private var failureFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PortalWebView()
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(controller.phase == .content)
                    .accessibilityHidden(controller.phase != .content)

                overlay
            }
            .navigationTitle("School Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        controller.cancelActiveWork()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { controller.retry() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload School Portal")
                        .disabled(controller.phase.isWorking)
                }
            }
            .onAppear {
                controller.configure(coordinator: coordinator)
                controller.open(fallback: portalURL)
            }
            .onDisappear { controller.cancelActiveWork() }
            .onChange(of: controller.phase) { _, phase in
                switch phase {
                case .authenticating:
                    UIAccessibility.post(notification: .announcement, argument: "Restoring School Portal access")
                case .failed, .timedOut:
                    failureFocused = true
                default:
                    failureFocused = false
                }
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.phase {
        case .idle, .content:
            EmptyView()
        case .preparing:
            statusBackdrop { portalStatus(title: "Opening School Portal…", detail: "Preparing the browser", progress: nil) }
        case .loading(let progress):
            statusBackdrop { portalStatus(title: "Loading School Portal…", detail: "Done remains available if you want to leave", progress: progress) }
        case .authenticating:
            statusBackdrop { portalStatus(title: "Restoring School Portal access…", detail: "Checking your saved school session", progress: nil) }
        case .failed(let message):
            statusBackdrop { failureStatus(title: "School Portal unavailable", detail: message) }
        case .timedOut:
            statusBackdrop {
                failureStatus(
                    title: "School Portal is taking too long",
                    detail: "HOney stopped this portal attempt. Try again, or close the portal and continue using HOney."
                )
            }
        }
    }

    private func statusBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Palette.canvas.opacity(0.96).ignoresSafeArea()
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
    }

    private func portalStatus(title: String, detail: String, progress: Double?) -> some View {
        VStack(spacing: 14) {
            if let progress, progress > 0 {
                ProgressView(value: progress)
                    .frame(maxWidth: 220)
                    .accessibilityValue(Text(Int(progress * 100).description + " percent"))
            } else {
                ProgressView()
            }
            Text(title).font(AppTheme.Typography.headlineSemibold).foregroundStyle(Palette.ink)
            Text(detail).font(AppTheme.Typography.footnote).foregroundStyle(Palette.inkSecondary)
        }
        .padding(22)
        .frame(maxWidth: 300)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(Palette.line) }
        .accessibilityElement(children: .combine)
    }

    private func failureStatus(title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle").font(.title2).foregroundStyle(Palette.warning)
            Text(title)
                .font(AppTheme.Typography.headlineSemibold)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityFocused($failureFocused)
            Text(detail)
                .font(AppTheme.Typography.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Close") {
                    controller.cancelActiveWork()
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Button("Try again") { controller.retry() }
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(22)
        .frame(maxWidth: 340)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay { RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(Palette.line) }
    }
}
