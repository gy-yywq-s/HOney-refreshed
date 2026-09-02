// HOneyNative — the current Web product expressed through native iPhone
// primitives (spec §0). Launch restores the HOney session from the
// Keychain and shows the shell from local state; nothing waits for the
// timetable or Experiences network.

import SwiftUI
import HOneyCore

@main
struct HOneyNativeApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.navigator)
                .preferredColorScheme(environment.appearance.colorScheme)
                .tint(Color.honeyAccent)
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

    var body: some View {
        Group {
            switch env.phase {
            case .loading:
                ZStack {
                    Color.honeyCanvas.ignoresSafeArea()
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
    let message: String

    var body: some View {
        VStack(spacing: HSpace.x6) {
            WordmarkView(height: 34)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.honeySecondary)
                .multilineTextAlignment(.center)
            Button(L10n.t("Try again")) { Task { await env.bootstrap() } }
                .buttonStyle(.borderedProminent)
            Button(L10n.t("Sign out")) { Task { await env.signOut() } }
                .buttonStyle(.plain)
                .foregroundStyle(Color.honeySecondary)
        }
        .padding(HSpace.pageX)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeyCanvas.ignoresSafeArea())
    }
}
