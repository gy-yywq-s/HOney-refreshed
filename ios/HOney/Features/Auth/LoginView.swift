//
//  LoginView.swift
//  HOney — sign in with the school account (no signup).
//  Ported legacy LoginScreen: white→mist gradient, serif wordmark,
//  48pt opaque-white fields (deliberately off the navy system).
//

import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 70)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxLarge) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    HOneyLoginMark()
                        .frame(width: 48, height: 48)

                    Text("HOney")
                        .font(AppTheme.Typography.loginTitle)
                        .foregroundStyle(Palette.navy)

                    Text("your school account signs you in — there is no separate signup.")
                        .font(AppTheme.Typography.footnote)
                        .foregroundStyle(Palette.navy.opacity(0.58))
                }

                VStack(spacing: AppTheme.Spacing.medium) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.next)
                        .focused($focus, equals: .username)
                        .loginFieldStyle()
                        .onSubmit {
                            focus = .password
                        }

                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .keyboardType(.asciiCapable)
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .loginFieldStyle()
                        .onSubmit {
                            submit()
                        }

                    if let errorMessage = model.loginError {
                        Text(errorMessage)
                            .font(AppTheme.Typography.footnote)
                            .foregroundStyle(.red.opacity(0.86))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Button {
                        submit()
                    } label: {
                        HStack(spacing: AppTheme.Spacing.small) {
                            if model.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(model.isAuthenticating ? "Signing In" : "Sign In")
                                .font(AppTheme.Typography.loginButton)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: AppTheme.Typography.loginControlHeight)
                        .background(
                            canSubmit ? Palette.ocean : Palette.navy.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(!canSubmit || model.isAuthenticating)

                    Text("your password is used only to sign in to the school portal and is stored securely on this device.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.navy.opacity(0.48))
                }
            }
            .padding(.horizontal, AppTheme.Spacing.loginHorizontal)

            Spacer(minLength: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.white, Palette.mist.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focus = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focus = nil
                }
            }
        }
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        // Import consent is NOT part of signing in — it is a separate, active
        // choice on the next step (audit §3.2).
        Task {
            await model.login(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }
}
