//
//  Components.swift
//  HOney — reusable UI components (Band: DesignSystem).
//

import SwiftUI

// MARK: - Wordmark

struct HOneyWordmark: View {
    var size: CGFloat = 28
    var body: some View {
        Text("HOney")
            .font(Theme.Typography.wordmark(size: size))
            .foregroundStyle(Theme.Palette.textPrimary)
            .accessibilityLabel("HOney")
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = Theme.Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.Palette.line, lineWidth: 1)
            )
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }
}

// MARK: - Loading

struct LoadingView: View {
    var label: String = "Loading…"
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(HOneyPrimaryButtonStyle())
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Banner

enum BannerKind {
    case info, success, warning, error

    var tint: Color {
        switch self {
        case .info: return Theme.Palette.accent
        case .success: return Theme.Palette.success
        case .warning: return Theme.Palette.warning
        case .error: return Theme.Palette.danger
        }
    }

    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct Banner: View {
    let kind: BannerKind
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(kind.tint)
            Text(message)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(kind.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

// MARK: - List row

struct ListRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var trailingText: String? = nil
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.line)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Button styles

struct HOneyPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Palette.accent.opacity(enabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: Theme.Motion.fast), value: configuration.isPressed)
    }
}

struct HOneySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Palette.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Palette.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: Theme.Motion.fast), value: configuration.isPressed)
    }
}

// MARK: - Screen background

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Palette.background.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}
