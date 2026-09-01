//
//  LoginView.swift
//  HOney — school-account sign in with a replaceable wordmark slot.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                brandAndIntroduction
                credentials
                actions
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.loginHorizontal)
            .padding(.top, 42)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(PageBackground())
        .contentShape(Rectangle())
        .onTapGesture { focus = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
    }

    private var brandAndIntroduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrandWordmarkPlaceholder()
                .frame(width: 240, height: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your school day, in one place.")
                    .font(AppTheme.Typography.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use your school account. HOney does not create a separate password.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var credentials: some View {
        VStack(alignment: .leading, spacing: 18) {
            loginField(label: "School account", focused: focus == .username) {
                TextField("Username or school email", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focus, equals: .username)
                    .onSubmit { focus = .password }
            }

            loginField(label: "Password", focused: focus == .password) {
                SecureField("School password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused($focus, equals: .password)
                    .onSubmit { submit() }
            }

            if let errorMessage = model.loginError {
                AppBanner(text: errorMessage, style: .error)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                submit()
            } label: {
                HStack(spacing: AppTheme.Spacing.small) {
                    if model.isAuthenticating {
                        ProgressView().tint(Palette.accentForeground)
                    }
                    Text(model.isAuthenticating ? "Signing in…" : "Sign in")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!canSubmit || model.isAuthenticating)

            Label {
                Text("Your credentials are sent to HOney to sign you into the school service and saved in this iPhone’s Keychain for automatic reauthentication.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Palette.accent)
            }
            .font(AppTheme.Typography.footnote)
            .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func loginField<Content: View>(
        label: String,
        focused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(Palette.inkSecondary)

            content()
                .font(AppTheme.Typography.loginField)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 15)
                .frame(minHeight: AppTheme.Typography.loginControlHeight)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(focused ? Palette.accent : Palette.controlBorder, lineWidth: focused ? 2 : 1)
                }
        }
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        Task {
            await model.login(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }
}
