// Login (LoginPage.tsx + features.css `.login*`; fidelity spec v2 §14): one
// calm doorway — the wordmark at 54, the tagline at the reading size, the
// muted support line, the two labelled Web fields, the ink-filled
// "Continue with school account", and the footnote. Centred when it fits,
// top-anchored and scrolling when it does not. No separate sign-up, no
// HOney password.

import SwiftUI
import HOneyCore

struct LoginView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    WordmarkView(height: 54)
                        .padding(.bottom, HSpace.x3)
                    Text(L10n.t("Your school day, without the portal friction."))
                        .font(ramp.font(.reading))
                        .lineSpacing(max(0, 17 * 1.45 * ramp.scale - HOneyFont.uiFont(role: .reading, scale: ramp.scale).lineHeight))
                        .foregroundStyle(theme.ink)
                        .padding(.bottom, HSpace.x6)
                    Text(L10n.t("Use your school account. HOney creates no separate password."))
                        .hfont(.body)
                        .foregroundStyle(theme.muted)
                        .padding(.bottom, HSpace.x6)

                    VStack(alignment: .leading, spacing: HSpace.x2) {
                        if let notice = env.signedOutNotice {
                            InlineStatusBanner(text: notice, tone: .warning, action: ("OK", { env.signedOutNotice = nil }))
                        }
                        if let error {
                            InlineStatusBanner(text: error, tone: .danger)
                        }
                        SchoolLoginFields(username: $username, password: $password, reading: true, onSubmit: submit)
                        Button(busy ? L10n.t("Signing in…") : L10n.t("Continue with school account"), action: submit)
                            .buttonStyle(.webLoginPrimary)
                            .disabled(busy || username.isEmpty || password.isEmpty)
                    }

                    Text(L10n.t("There is no separate sign-up — your school account is your HOney account, created on first sign-in. Your timetable and history come along with it, and again whenever you sync — Sync now in Settings, or Sync with school in the Timetable menu. HOney keeps your school login in this iPhone's Keychain so portal time-outs reconnect on their own; turn that off in Settings › School connection."))
                        .hfont(.caption)
                        .foregroundStyle(theme.muted)
                        .padding(.top, HSpace.x4)
                }
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, HSpace.x6)
                .padding(.vertical, HSpace.x7)
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(theme.surface.ignoresSafeArea())
    }

    private func submit() {
        guard !busy, !username.isEmpty, !password.isEmpty else { return }
        busy = true
        error = nil
        Task {
            do {
                try await env.login(username: username, password: password)
            } catch {
                self.error = APIErrorCopy.describe(error)
                busy = false
            }
        }
    }
}
