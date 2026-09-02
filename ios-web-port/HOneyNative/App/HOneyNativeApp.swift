// HOneyNative — the current Web product on the iPhone (fidelity spec v2).
// Launch restores the HOney session from the Keychain and shows the shell
// from local state; the chosen Background · Accent · Text size are applied
// at the first frame, before anything else paints.

import SwiftUI
import HOneyCore

@main
struct HOneyNativeApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ThemedRoot(store: environment.themeStore) {
                RootView()
            }
            .environment(environment)
            .environment(environment.navigator)
            .task { await environment.bootstrap() }
            .onOpenURL { url in environment.navigator.open(url) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await environment.didBecomeActive() } }
            }
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch env.phase {
            case .loading:
                ZStack {
                    theme.surface.ignoresSafeArea()
                    WordmarkView(height: 34)
                }
            case .signedOut:
                LoginView()
            case .signedIn:
                RootTabView()
            case .unavailable(let message):
                StartupUnavailableView(message: message)
            }
        }
        .animation(.default, value: env.phase.key)
    }
}

/// Session known, account fetch failed: keep the doorway, offer a scoped retry.
struct StartupUnavailableView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme

    let message: String

    var body: some View {
        VStack(spacing: HSpace.x6) {
            WordmarkView(height: 34)
            Text(message)
                .hfont(.body)
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
            Button(L10n.t("Try again")) { Task { await env.bootstrap() } }
                .buttonStyle(.webPrimary)
            Button(L10n.t("Sign out")) { Task { await env.signOut() } }
                .buttonStyle(.webLinkBody)
        }
        .padding(HSpace.pageX)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface.ignoresSafeArea())
    }
}
