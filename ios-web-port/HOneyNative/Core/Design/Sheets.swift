// The Web's modal as a native sheet (components.css `.modal` ≤640px;
// fidelity spec v2 §4.8): surface-solid ground, 20 pt top radius, a 36 × 5
// grabber, the modal title at 22/650, actions stacked full width. Native
// sheet mechanics (drag, detents) are the approved platform adaptation;
// content order, copy and button hierarchy are the Web's.

import SwiftUI
import HOneyCore

struct WebSheet<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(theme.line)
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HSpace.x3)
                    .padding(.bottom, HSpace.x3)
                HStack(alignment: .top, spacing: HSpace.x3) {
                    Text(title)
                        .hfont(.modalTitle)
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    if let onClose {
                        Button(action: onClose) {
                            Text("×")
                                .hfont(.title)
                                .foregroundStyle(theme.muted)
                                .frame(width: HSize.control, height: HSize.control)
                                .overlay(Circle().strokeBorder(theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
                .padding(.bottom, HSpace.x3)
                content()
            }
            .padding(.horizontal, HSpace.x4)
            .padding(.bottom, HSpace.x6)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.surfaceSolid.ignoresSafeArea())
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(HRadius.modal)
        .presentationBackground(theme.surfaceSolid)
    }
}

/// `.modal__actions`: a column of full-width buttons, 8 pt apart, 16 above.
struct SheetActions<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: HSpace.x2) { content() }
            .padding(.top, HSpace.x4)
    }
}

/// `ConfirmDialog` (Modal.tsx): title, one muted paragraph, then the row —
/// ghost Cancel and the confirm (danger or primary) at the right.
struct ConfirmSheet: View {
    @Environment(\.theme) private var theme
    let title: String
    let message: String
    let confirmLabel: String
    var danger = false
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        WebSheet(title: title, onClose: onCancel) {
            Text(message)
                .hfont(.body)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: HSpace.x2) {
                Spacer(minLength: 0)
                Button(L10n.t("Cancel"), action: onCancel)
                    .buttonStyle(.webGhost)
                    .disabled(busy)
                Button(busy ? "Working…" : confirmLabel, action: onConfirm)
                    .buttonStyle(danger ? .webDanger : .webPrimary)
                    .disabled(busy)
            }
            .padding(.top, HSpace.x4)
        }
        .presentationDetents([.medium])
    }
}
