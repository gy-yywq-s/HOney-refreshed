// The school's own feedback channel (SchoolFeedbackSheet.tsx, Gary
// 2026-09-04): its `student_complaints` form. This is NOT the Experiences
// space — the request carries the student's portal session, so the school
// knows which account wrote it; the body is only the text. Both entries (the
// composer's small line and the standalone Settings row) open this one sheet.

import SwiftUI
import HOneyCore

struct SchoolFeedbackSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    var draft = ""
    let close: () -> Void

    @State private var text = ""
    @State private var busy = false
    @State private var sent = false
    @State private var error: String?
    @FocusState private var editing: Bool

    var body: some View {
        WebSheet(title: L10n.t("Feedback to the school"), onClose: close) {
            if sent {
                Text(L10n.t("Sent to the school.")).hfont(.body).foregroundStyle(theme.ink)
                SheetActions {
                    Button(L10n.t("Done"), action: close).buttonStyle(.webBlockPrimary)
                }
            } else {
                Text(L10n.t("Sent from your school account — not anonymous."))
                    .hfont(.caption)
                    .foregroundStyle(theme.muted)
                    .padding(.bottom, HSpace.x3)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L10n.t("What should the school know?"))
                            .font(ramp.font(.body))
                            .foregroundStyle(theme.muted)
                            .padding(.horizontal, HSpace.x3 + 5)
                            .padding(.vertical, HSpace.x3 + 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(ramp.font(.body))
                        .foregroundStyle(theme.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 132)
                        .padding(HSpace.x2)
                        .focused($editing)
                        .disabled(busy)
                        .accessibilityLabel(L10n.t("What should the school know?"))
                }
                .background(theme.surfaceSolid, in: RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous).strokeBorder(theme.line, lineWidth: 1))
                .fieldShadow(theme)
                if let error {
                    InlineStatusBanner(text: error, tone: .danger).padding(.top, HSpace.x3)
                }
                SheetActions {
                    Button(busy ? L10n.t("Saving…") : L10n.t("Send to the school")) { send() }
                        .buttonStyle(.webBlockPrimary)
                        .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
                    Button(L10n.t("Cancel"), action: close).buttonStyle(.webBlockGhost).disabled(busy)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if text.isEmpty { text = draft }
            editing = true
        }
    }

    private func send() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 4, !busy else { return }
        busy = true
        error = nil
        editing = false
        Task {
            do {
                switch try await env.api.schoolComplaint(body) {
                case .ok: sent = true
                case .refused(let reason): error = reason
                case .portalReconnectRequired: error = L10n.t("The school connection needs renewing.")
                case .unavailable: error = L10n.t("The school could not be reached.")
                }
            } catch {
                self.error = APIErrorCopy.describe(error)
            }
            busy = false
        }
    }
}
