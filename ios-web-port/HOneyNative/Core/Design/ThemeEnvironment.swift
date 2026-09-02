// The appearance store (fidelity spec v2 §3.4): Background, Accent, Text
// size and Language, persisted in Preferences under the Web's own keys,
// switched independently and immediately with the Web's ~400 ms crossfade
// (none under Reduce Motion). Nothing relaunches, no tab or stack resets.

import SwiftUI
import HOneyCore

@MainActor
@Observable
final class ThemeStore {
    private let prefs: Preferences
    private(set) var background: HOneyBackground
    private(set) var accent: HOneyAccent
    private(set) var textSize: HOneyTextSize
    private(set) var language: AppLanguage
    /// Whether the student has chosen a Background (else the system's dark
    /// preference decides between Stone and Night, as the Web boot script does).
    private(set) var backgroundChosen: Bool
    private var systemPrefersDark: Bool

    init(prefs: Preferences, systemPrefersDark: Bool) {
        self.prefs = prefs
        self.systemPrefersDark = systemPrefersDark
        backgroundChosen = prefs.background != nil
        background = prefs.effectiveBackground(systemPrefersDark: systemPrefersDark)
        accent = prefs.accent
        textSize = prefs.textSize
        language = prefs.language
        L10n.language = language
    }

    var theme: HOneyTheme { HOneyTheme(background: background, accent: accent, textSize: textSize) }

    /// The system appearance changed: only matters until a Background is chosen.
    func systemAppearanceChanged(prefersDark: Bool) {
        systemPrefersDark = prefersDark
        guard !backgroundChosen else { return }
        let next = prefs.effectiveBackground(systemPrefersDark: prefersDark)
        if next != background { ThemeTransition.crossfade { self.background = next } }
    }

    func choose(background next: HOneyBackground) {
        prefs.background = next
        backgroundChosen = true
        ThemeTransition.crossfade { self.background = next }
    }

    func choose(accent next: HOneyAccent) {
        prefs.accent = next
        ThemeTransition.crossfade { self.accent = next }
    }

    func choose(textSize next: HOneyTextSize) {
        prefs.textSize = next
        textSize = next
    }

    func choose(language next: AppLanguage) {
        prefs.language = next
        L10n.language = next
        language = next
    }
}

/// Injects the live theme, forces the surface's colour scheme and keeps
/// the UIKit chrome (status bar, navigation bar) on the same surface.
struct ThemedRoot<Content: View>: View {
    @Environment(\.colorScheme) private var systemScheme
    let store: ThemeStore
    @ViewBuilder let content: () -> Content

    var body: some View {
        let theme = store.theme
        content()
            .environment(\.theme, theme)
            .environment(\.hType, HTypeRamp(scale: theme.scale))
            .tint(theme.accent)
            .preferredColorScheme(theme.colorScheme)
            .background(theme.surface.ignoresSafeArea())
            .onAppear { store.systemAppearanceChanged(prefersDark: systemScheme == .dark) }
            .onChange(of: systemScheme) { _, next in store.systemAppearanceChanged(prefersDark: next == .dark) }
            .onChange(of: theme, initial: true) { _, next in ThemeChrome.apply(next) }
    }
}

/// UIKit appearance proxies: the navigation bar sits on the surface with
/// the theme's ink, so a pushed screen never flashes system white/black.
enum ThemeChrome {
    @MainActor
    static func apply(_ theme: HOneyTheme) {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = theme.uiSurface
        nav.shadowColor = .clear
        let title = HOneyFont.uiFont(role: .navTitle, scale: theme.scale)
        nav.titleTextAttributes = [.foregroundColor: theme.uiInk, .font: title]
        nav.largeTitleTextAttributes = [.foregroundColor: theme.uiInk, .font: HOneyFont.uiFont(role: .pageTitle, scale: theme.scale)]
        let button = UIBarButtonItemAppearance(style: .plain)
        button.normal.titleTextAttributes = [.foregroundColor: theme.uiAccent, .font: HOneyFont.uiFont(role: .bodySemibold, scale: theme.scale)]
        nav.buttonAppearance = button
        nav.backButtonAppearance = button
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = theme.uiAccent
        // Live bars adopt the proxy only on their next layout; nudge the windows.
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = theme.isNight ? .dark : .light
                window.subviews.forEach { $0.setNeedsLayout() }
            }
        }
    }
}
