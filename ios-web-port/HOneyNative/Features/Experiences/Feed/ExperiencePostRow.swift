// One voice in the stream (ExperiencePost.tsx + features.css `.post*`;
// fidelity spec v2 §7.4–7.6, Web 2026-09-03): context line → Yours ·
// provenance · day → optional stars → the words at the largest weight (short
// posts at 20) → Read more → the footer: resonance (a centre and its rings,
// not a thumb), "Write your own" (disagreement is written, never scored),
// the ··· that opens the post's options as a sheet. On your own post the
// count is a reading, not a control. No avatar, no badge, no shield, no
// card; a hairline rules beneath.

import SwiftUI
import HOneyCore

struct ExperiencePostRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp
    let exp: PublicExperienceV2
    let reaction: ReactionState
    /// Names are joined on the device (the wire carries ids only).
    let name: NameResolver
    /// The reader's own words — the id is known on this device, never on the server.
    var mine = false
    let onReact: (Int) -> Void
    let onReport: (ReportCategory) async -> Result<Void, Error>
    let openEntity: (AppRoute) -> Void
    /// "Write your own": the same subject when it has a public one.
    var writeOwn: ((ComposeTarget?) -> Void)?

    @State private var expanded = false
    @State private var options = false
    /// Counts deliberate reaction taps: the haptic follows these, never a
    /// rollback or a server update.
    @State private var reactionTaps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            let parts = ExperienceDisplay.contextParts(exp, name: name)
            if !parts.isEmpty {
                contextLine(parts)
            }
            provenanceLine
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
        .sheet(isPresented: $options) {
            PostOptionsSheet(onReport: onReport) { options = false }
        }
    }

    /// `.post__provenance`: "Yours · " in the accent for the reader alone.
    private var provenanceLine: some View {
        HStack(spacing: 0) {
            if mine {
                Text("\(L10n.t("Yours")) · ").font(ramp.font(.captionBold)).foregroundStyle(theme.accent)
            }
            Text(ExperienceDisplay.provenanceText(exp))
                .font(ramp.font(.caption))
                .foregroundStyle(theme.muted)
        }
    }

    /// `.post__context`: caption 600 in ink-2; names are links that inherit
    /// the line's colour (features.css `.post__context a { color: inherit }`).
    private func contextLine(_ parts: [NamedRef]) -> some View {
        // Inline links that flow and wrap like the Web's text run.
        FlowLayout(spacing: 4, rowSpacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 { Text("·").font(ramp.font(.captionSemibold)).foregroundStyle(theme.ink2) }
                if let route = ExperienceDisplay.route(for: part.ref) {
                    Button { openEntity(route) } label: {
                        Text(part.name)
                            .font(ramp.font(.captionSemibold))
                            .foregroundStyle(theme.ink2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(part.name)
                        .font(ramp.font(.captionSemibold))
                        .foregroundStyle(theme.ink2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    /// `.post__actions`: ONE line, always — resonance and Write your own at
    /// the left, the overflow at the right. The footer is not a row of form
    /// controls: the line is 32 pt while the tap zone stays 44 and reaches
    /// into the margins (Gary 2026-09-03: 共鸣和 write your own 高度太高).
    private var actions: some View {
        HStack(spacing: HSpace.x2) {
            if mine {
                // Your own words: the count is there to read, but you cannot
                // resonate with yourself and there is nothing to answer.
                HStack(spacing: HSpace.x2) {
                    ResonanceGlyph()
                    if let count = reaction.counts?.likes { Text("\(count)") }
                }
                .font(ramp.font(.captionSemibold))
                .monospacedDigit()
                .foregroundStyle(theme.muted)
                .padding(.horizontal, HSpace.x2)
                .frame(minHeight: 32)
                .accessibilityLabel(L10n.t("This resonates with me"))
                .accessibilityValue(reaction.counts.map { "\($0.likes)" } ?? "")
            } else {
                let on = reaction.myValue == 1
                ReactionPill(on: on, pending: reaction.pending == 1, placement: .streamFooter) {
                    reactionTaps += 1
                    onReact(1)
                } label: {
                    ResonanceGlyph()
                    if let count = reaction.counts?.likes { Text("\(count)") }
                }
                .accessibilityLabel(L10n.t("This resonates with me"))
                .accessibilityHint(ExperienceDisplay.reactionExplainer)
                .sensoryFeedback(.selection, trigger: reactionTaps)
                Button {
                    writeOwn?(ExperienceDisplay.writeOwnTarget(exp))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.line").font(.system(size: 16, weight: .regular))
                        Text(L10n.t("Write your own")).font(ramp.font(.caption))
                    }
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, HSpace.x2)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            // Post options open as a sheet, not a floating menu (Gary
            // 2026-09-03: report 选项打不开) — the same grammar as every sheet.
            Button { options = true } label: {
                Text("···")
                    .font(ramp.font(.captionSemibold))
                    .foregroundStyle(theme.muted)
                    .frame(minWidth: HSize.control, minHeight: 32)
                    .contentShape(Rectangle().inset(by: -6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("More options"))
        }
        .frame(minHeight: 32)
    }
}

/// Resonance (Gary 2026-09-03: 共鸣) — a centre and the rings it sets going,
/// not a thumb: the reaction says "this rings true for me". 16 pt, stroke
/// 1.7, drawn like the Web's SVG.
struct ResonanceGlyph: View {
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24
            var style = StrokeStyle(lineWidth: 1.7 * s, lineCap: .round, lineJoin: .round)
            style.lineWidth = max(1.2, 1.7 * s)
            func arc(cx: CGFloat, cy: CGFloat, r: CGFloat, from: Double, to: Double) {
                var path = Path()
                path.addArc(center: CGPoint(x: cx * s, y: cy * s), radius: r * s, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
                context.stroke(path, with: .foreground, style: style)
            }
            // The centre.
            var dot = Path()
            dot.addEllipse(in: CGRect(x: (12 - 2.1) * s, y: (12 - 2.1) * s, width: 4.2 * s, height: 4.2 * s))
            context.stroke(dot, with: .foreground, style: style)
            // Inner rings (left and right), then the outer ones.
            arc(cx: 12, cy: 12, r: 5.2, from: 135, to: 225)
            arc(cx: 12, cy: 12, r: 5.2, from: -45, to: 45)
            arc(cx: 12, cy: 12, r: 9.3, from: 135, to: 225)
            arc(cx: 12, cy: 12, r: 9.3, from: -45, to: 45)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension ExperienceDisplay {
    /// Where "write your own" goes from a post: the same subject when it has
    /// a public one; a lesson is the writer's own and never the reader's, so
    /// those fall back to the course or teacher, and finally to the picker.
    static func writeOwnTarget(_ exp: PublicExperienceV2) -> ComposeTarget? {
        let own: EntityRefV2? = (exp.primary.type != .lesson ? exp.primary : nil)
            ?? exp.contexts.first { $0.type == .course }
            ?? exp.contexts.first { $0.type == .teacher }
        return own.map { .entity(key: $0.entityKey) }
    }
}

/// The post's options, as one sheet (PostOptionsSheet): step 1 is what you
/// can do with this post; step 2 the report's categories — no free text is
/// ever collected, and the report carries no account. Then the thanks.
struct PostOptionsSheet: View {
    @Environment(\.theme) private var theme
    let onReport: (ReportCategory) async -> Result<Void, Error>
    let close: () -> Void
    @State private var step: Step = .options
    @State private var busy = false
    @State private var error: String?

    enum Step { case options, report, done }

    private var title: String {
        switch step {
        case .options: return L10n.t("Post options")
        case .report: return L10n.t("Report this experience")
        case .done: return L10n.t("Report sent")
        }
    }

    var body: some View {
        WebSheet(title: title, onClose: close) {
            switch step {
            case .options:
                VStack(spacing: HSpace.x2) {
                    Button(L10n.t("Report this experience")) { step = .report }.buttonStyle(.webBlockGhost)
                }
                .padding(.vertical, HSpace.x3)
            case .report:
                Text(L10n.t("Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected."))
                    .hfont(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: HSpace.x2) {
                    ForEach(ExperienceDisplay.reportOptions, id: \.category) { option in
                        Button(L10n.t(option.label)) { send(option.category) }
                            .buttonStyle(.webBlockGhost)
                            .disabled(busy)
                    }
                }
                .padding(.vertical, HSpace.x3)
                if let error {
                    InlineStatusBanner(text: error, tone: .danger)
                }
            case .done:
                Text(L10n.t("Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote."))
                    .hfont(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                SheetActions {
                    Button(L10n.t("Done"), action: close).buttonStyle(.webBlockPrimary)
                }
            }
        }
        .presentationDetents(step == .options ? [.fraction(0.3), .large] : [.large])
    }

    private func send(_ category: ReportCategory) {
        busy = true
        error = nil
        Task {
            switch await onReport(category) {
            case .success: step = .done
            case .failure(let err): error = ExperienceDisplay.reportFailureNote(err)
            }
            busy = false
        }
    }
}
