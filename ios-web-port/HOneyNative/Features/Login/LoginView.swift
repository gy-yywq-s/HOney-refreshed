// Login (spec §9): one school-account doorway, no separate sign-up, no HOney
// password. A focused composition, not a Form. The long Web footer is
// condensed here; the full explanation lives in a sheet.

import SwiftUI
import HOneyCore

struct LoginView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showHow = false
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x6) {
                WordmarkView(height: 54)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HSpace.x8)
                    .padding(.bottom, HSpace.x2)

                VStack(alignment: .leading, spacing: HSpace.x2) {
                    Text("Your school day, without the portal friction.")
                        .font(HType.pageTitle)
                        .foregroundStyle(Color.honeyInk)
                    Text("Use your school account. HOney creates no separate password.")
                        .font(HType.secondary)
                        .foregroundStyle(Color.honeySecondary)
                }

                if let error {
                    InlineStatusBanner(text: error, tone: .danger)
                }

                VStack(alignment: .leading, spacing: HSpace.x4) {
                    field("School account") {
                        TextField("", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .submitLabel(.next)
                            .focused($focus, equals: .username)
                            .onSubmit { focus = .password }
                    }
                    field("School password") {
                        SecureField("", text: $password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focus, equals: .password)
                            .onSubmit { submit() }
                    }
                }

                Button(action: submit) {
                    HStack {
                        if busy { ProgressView().tint(Color.honeyOnAccent) }
                        Text(busy ? "Signing in…" : "Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy || username.isEmpty || password.isEmpty)

                Button("How sign-in works") { showHow = true }
                    .font(HType.secondary)
                    .frame(maxWidth: .infinity)
            }
            .pageInset()
            .padding(.bottom, HSpace.x7)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.honeyCanvas.ignoresSafeArea())
        .sheet(isPresented: $showHow) { HowSignInWorksSheet() }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HSpace.x1) {
            Text(label).font(HType.meta.weight(.medium)).foregroundStyle(Color.honeySecondary)
            content()
                .font(HType.body)
                .padding(.horizontal, HSpace.x3)
                .frame(minHeight: 46)
                .background(Color.honeyCell, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).stroke(Color.honeyLine, lineWidth: 1))
        }
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

struct HowSignInWorksSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HSpace.x4) {
                    Text("There is no separate sign-up — your school account is your HOney account, created on first sign-in.")
                    Text("Your timetable and history come along with it, and again whenever you sync: Sync with school in the Timetable menu, or Sync now in Settings.")
                    Text("HOney keeps your school login in this iPhone's Keychain so routine portal time-outs reconnect on their own. Turn that off any time in Settings › School connection.")
                    Text("HOney's own session is separate from the school portal's; a portal problem never signs you out of HOney.")
                }
                .font(HType.body)
                .foregroundStyle(Color.honeyInk)
                .pageInset()
                .padding(.vertical, HSpace.x4)
            }
            .background(Color.honeyCanvas.ignoresSafeArea())
            .navigationTitle("How sign-in works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
