//
//  AppComponents.swift
//  HOney
//
//  Small reusable building blocks for the editorial, content-first system.
//  Keep them behaviorally plain and visually consistent across all screens.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    var isActive = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(AppTheme.Typography.caption2Bold)
        }
        .font(AppTheme.Typography.captionSemibold)
        .foregroundStyle(isActive ? Palette.accent : Palette.inkSecondary)
        .padding(.horizontal, 13)
        .frame(minHeight: 44)
        .background(isActive ? Palette.accentSoft : Palette.surface, in: Capsule())
        .overlay(Capsule().stroke(isActive ? Palette.accent.opacity(0.45) : Palette.line, lineWidth: 1))
        .contentShape(Capsule())
    }
}
#if canImport(UIKit)
import UIKit
#endif

struct AppCard<Content: View>: View {
    let padding: CGFloat
    let background: Color
    let border: Color
    let content: Content

    init(
        padding: CGFloat = AppTheme.Spacing.large,
        background: Color = Palette.surface,
        border: Color = Palette.line,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.background = background
        self.border = border
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(border, lineWidth: 1)
            )
            .appDebugBorder()
    }
}

struct AppSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTheme.Typography.sectionTitle)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AppLoadingState: View {
    let title: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ProgressView()
                .tint(Palette.ocean)
            Text(title)
                .font(AppTheme.Typography.subheadlineSemibold)
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(AppTheme.Spacing.large)
    }
}

struct AppEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Typography.subheadlineSemibold)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.medium)
    }
}

struct AppBanner: View {
    enum Style {
        case error
        case success
        /// The portal connector and composer preflight need a softer warning.
        case warning

        var foreground: Color {
            switch self {
            case .error:
                return Palette.error
            case .success:
                return Palette.success
            case .warning:
                return Palette.warning
            }
        }

        var background: Color {
            switch self {
            case .error:
                return Palette.error.opacity(0.10)
            case .success:
                return Palette.success.opacity(0.10)
            case .warning:
                return Palette.warning.opacity(0.10)
            }
        }

        var systemImage: String {
            switch self {
            case .error:
                return "exclamationmark.circle"
            case .success:
                return "checkmark.circle"
            case .warning:
                return "exclamationmark.triangle"
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Label(text, systemImage: style.systemImage)
            .font(AppTheme.Typography.footnoteMedium)
            .foregroundStyle(style.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.medium)
            .background(style.background, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .appDebugBorder()
    }
}

struct AppListRow<Leading: View, Content: View, Trailing: View>: View {
    let leading: Leading
    let content: Content
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            leading
            content
            Spacer(minLength: AppTheme.Spacing.small)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headlineSemibold)
            .foregroundStyle(isEnabled ? Palette.accentForeground : Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AppTheme.Spacing.large)
            .background(
                isEnabled ? Palette.accent : Palette.surfaceMuted,
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headlineSemibold)
            .foregroundStyle(isEnabled ? Palette.ink : Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, AppTheme.Spacing.large)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.controlBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

struct PageBackground: View {
    var body: some View {
        Palette.canvas.ignoresSafeArea()
    }
}

/// Temporary asset slot for the user-selected thin wordmark. Replacing the
/// imageset swaps the brand without changing Login or consent layout.
struct BrandWordmarkPlaceholder: View {
    var body: some View {
        Image("BrandWordmarkPlaceholder")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 240, height: 80)
            .foregroundStyle(Palette.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("HOney")
    }
}

private struct DebugBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        if AppConfig.showDebugBorders {
            content.border(.pink.opacity(0.7), width: 1)
        } else {
            content
        }
    }
}

extension View {
    func appDebugBorder() -> some View {
        modifier(DebugBorderModifier())
    }

    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    // MARK: - Shared style modifiers

    func formFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.controlBorder, lineWidth: 1)
            )
    }

    func loginFieldStyle() -> some View {
        self
            .font(AppTheme.Typography.loginField)
            .padding(.horizontal, AppTheme.Spacing.large)
            .frame(height: AppTheme.Typography.loginControlHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.controlBorder, lineWidth: 1)
            )
    }

    func sectionTitle() -> some View {
        self
            .font(AppTheme.Typography.sectionTitle)
            .foregroundStyle(Palette.navy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    func fullHitArea() -> some View {
        self.contentShape(Rectangle())
    }

    func preferenceCard() -> some View {
        self
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(KeyboardDismissInstaller().allowsHitTesting(false))
    }
}

#if canImport(UIKit)
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        func install(from view: UIView) {
            guard let window = view.window, installedWindow !== window else { return }

            if let recognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(recognizer)
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self

            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
            installedWindow = window
        }

        @objc private func dismissKeyboard() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !touch.view.isTextInputOrDescendant
        }
    }
}

private extension Optional where Wrapped == UIView {
    var isTextInputOrDescendant: Bool {
        var currentView = self
        while let view = currentView {
            if view is UITextField || view is UITextView || view is UISearchBar {
                return true
            }
            currentView = view.superview
        }
        return false
    }
}
#else
private struct KeyboardDismissInstaller: View {
    var body: some View {
        EmptyView()
    }
}
#endif
