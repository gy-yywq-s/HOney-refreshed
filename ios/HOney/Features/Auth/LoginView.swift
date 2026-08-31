//
//  LoginView.swift
//  HOney — sign in with the school account (no signup).
//

import SwiftUI

struct LoginView: View {
    @Environment(AppModel.self) private var model

    @State private var username = ""
    @State private var password = ""
    @State private var importTimetable = true
    @FocusState private var focus: Field?

    private enum Field { case username, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HoneyWordmark(size: 40)
                    Text("Continue with your school account")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("HOney signs you in with your OASIS school portal account. There is no separate signup.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(.top, Theme.Spacing.xxl)

                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        LabeledField(title: "School username") {
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }
                        LabeledField(title: "Password") {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focus, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { submit() }
                        }
                        Toggle(isOn: $importTimetable) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import my timetable")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text("Lets HOney sync your lessons. You can change this later in Settings.")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                }

                if let error = model.loginError {
                    Banner(kind: .error, message: error)
                }

                Button {
                    submit()
                } label: {
                    if model.isAuthenticating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(HoneyPrimaryButtonStyle(enabled: canSubmit))
                .disabled(!canSubmit || model.isAuthenticating)

                Text("Your password is used only to sign in to the school portal and is stored securely on this device.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .scrollDismissesKeyboard(.interactively)
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
                password: password,
                consentTimetable: importTimetable
            )
        }
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            content
                .font(Theme.Typography.body)
                .padding(Theme.Spacing.md)
                .background(Theme.Palette.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(Theme.Palette.line, lineWidth: 1)
                )
        }
    }
}
