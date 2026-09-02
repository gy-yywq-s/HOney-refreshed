// One voice in the stream (ExperiencePost.tsx + features.css `.post*`;
// fidelity spec v2 §7.4–7.6): context line → provenance · day → optional
// stars → the words at the largest weight (short posts at 20) → Read more →
// reactions left, the ··· overflow right, all in the footer family. No
// avatar, no badge, no shield, no card; a hairline rules beneath.

import SwiftUI
import HOneyCore

struct ExperiencePostRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let exp: PublicExperience
    let reaction: ReactionState
    let onReact: (Int) -> Void
    let onReport: (ReportCategory) async -> Result<Void, Error>
    let openEntity: (AppRoute) -> Void

    @State private var expanded = false
    @State private var reporting = false
    /// Counts deliberate reaction taps: the haptic follows these, never a
    /// rollback or a server update.
    @State private var reactionTaps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            let parts = ExperienceDisplay.contextParts(exp)
            if !parts.isEmpty {
                contextLine(parts)
            }
            Text(ExperienceDisplay.provenanceText(exp))
                .font(ramp.font(.caption))
                .foregroundStyle(theme.muted)
                .padding(.top, parts.isEmpty ? 0 : -HSpace.x1)
            if let rating = exp.rating {
                StarsView(value: rating)
            }
            let body = exp.body ?? ""
            let clamped = ExperienceDisplay.clampedBody(body, expanded: expanded)
            let role: TypeRole = ExperienceDisplay.isFeature(body) ? .feature : .reading
            Text(clamped.text)
                .font(ramp.font(role))
                .tracking(ramp.tracking(role))
                .lineSpacing(ramp.lineSpacing(role))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.top, HSpace.x1)
            if clamped.clamped {
                Button(L10n.t("Read more")) { expanded = true }
                    .buttonStyle(WebLinkStyle(role: .caption))
                    .frame(minHeight: 0)
            }
            actions
                .padding(.top, HSpace.x1)
            if let note = reaction.note {
                Text(note).font(ramp.font(.caption)).foregroundStyle(theme.ink2)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.top, HSpace.x5)
        .padding(.bottom, HSpace.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { HairlineDivider() }
        .sheet(isPresented: $reporting) {
            PostReportSheet(onReport: onReport) { reporting = false }
        }
    }

    /// `.post__context`: caption 600 in ink-2; names are links that inherit
    /// the line's colour (features.css `.post__context a { color: inherit }`).
    private func contextLine(_ parts: [EntitySummary]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { contextButtons(parts) }
            VStack(alignment: .leading, spacing: 2) { contextButtons(parts) }
        }
    }

    @ViewBuilder
    private func contextButtons(_ parts: [EntitySummary]) -> some View {
        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
            HStack(spacing: 4) {
                if index > 0 { Text("·").foregroundStyle(theme.ink2) }
                if let route = ExperienceDisplay.route(for: part) {
                    Button(part.name ?? "") { openEntity(route) }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.ink2)
                } else {
                    Text(part.name ?? "").foregroundStyle(theme.ink2)
                }
            }
            .font(ramp.font(.captionSemibold))
            .lineLimit(1)
        }
    }

    /// `.post__actions`: one line, reactions left, the overflow right.
    private var actions: some View {
        HStack(spacing: HSpace.x2) {
            reactionButton(value: 1, symbol: "hand.thumbsup", label: L10n.t("Matches my experience"), count: reaction.counts?.likes)
            reactionButton(value: -1, symbol: "hand.thumbsdown", label: L10n.t("Doesn’t match my experience"), count: reaction.counts?.dislikes)
            Spacer(minLength: 0)
            Menu {
                Button(L10n.t("Report")) { reporting = true }
            } label: {
                Text("···")
                    .font(ramp.font(.captionSemibold))
                    .foregroundStyle(theme.muted)
                    .frame(minWidth: HSize.control, minHeight: HSize.control)
                    .contentShape(RoundedRectangle(cornerRadius: HRadius.field, style: .continuous))
            }
            .accessibilityLabel(L10n.t("More options"))
        }
    }

    private func reactionButton(value: Int, symbol: String, label: String, count: Int?) -> some View {
        let on = reaction.myValue == value
        return ReactionPill(on: on, pending: reaction.pending == value, placement: .streamFooter) {
            reactionTaps += 1
            onReact(value)
        } label: {
            Image(systemName: symbol).font(.system(size: 16, weight: .regular))
            if let count { Text("\(count)") }
        }
        .accessibilityLabel(label)
        .accessibilityHint(ExperienceDisplay.reactionExplainer)
        .sensoryFeedback(.selection, trigger: reactionTaps)
    }
}

/// `PostReportDialog`: the explanatory paragraph, six ghost block buttons
/// (category only, no free text), the error banner; then the thanks and Done.
struct PostReportSheet: View {
    @Environment(\.theme) private var theme
    let onReport: (ReportCategory) async -> Result<Void, Error>
    let close: () -> Void
    @State private var busy = false
    @State private var done = false
    @State private var error: String?

    var body: some View {
        WebSheet(title: "Report this experience", onClose: close) {
            if done {
                Text("Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote.")
                    .hfont(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                SheetActions {
                    Button("Done", action: close).buttonStyle(.webBlockPrimary)
                }
            } else {
                Text("Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected.")
                    .hfont(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: HSpace.x2) {
                    ForEach(ExperienceDisplay.reportOptions, id: \.category) { option in
                        Button(option.label) { send(option.category) }
                            .buttonStyle(.webBlockGhost)
                            .disabled(busy)
                    }
                }
                .padding(.vertical, HSpace.x3)
                if let error {
                    InlineStatusBanner(text: error, tone: .danger)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func send(_ category: ReportCategory) {
        busy = true
        error = nil
        Task {
            switch await onReport(category) {
            case .success: done = true
            case .failure(let err): error = ExperienceDisplay.reportFailureNote(err)
            }
            busy = false
        }
    }
}
