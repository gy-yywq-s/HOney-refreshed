// One voice in the stream (spec §11.5): context line → provenance · day →
// the student's own words at the largest weight → match/different (≥44 pt)
// and an overflow menu. No avatar, no badge, no shield, no card.

import SwiftUI
import HOneyCore

struct ExperiencePostRow: View {
    let exp: PublicExperience
    let reaction: ReactionState
    let onReact: (Int) -> Void
    let onReport: (ReportCategory) async -> Result<Void, Error>
    let openEntity: (AppRoute) -> Void

    @State private var expanded = false
    @State private var reporting = false
    @State private var reportNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            let parts = ExperienceDisplay.contextParts(exp)
            if !parts.isEmpty {
                contextLine(parts)
            }
            Text(ExperienceDisplay.provenanceText(exp))
                .font(HType.meta)
                .foregroundStyle(Color.honeyTertiary)
            if let rating = exp.rating {
                StarsView(value: rating)
            }
            let body = exp.body ?? ""
            let clamped = ExperienceDisplay.clampedBody(body, expanded: expanded)
            Text(clamped.text)
                .font(ExperienceDisplay.isFeature(body) ? HType.feature : HType.reading)
                .foregroundStyle(Color.honeyInk)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if clamped.clamped {
                Button(L10n.t("Read more")) { expanded = true }
                    .font(HType.secondary)
            }
            actions
            if let note = reaction.note ?? reportNote {
                Text(note).font(HType.meta).foregroundStyle(Color.honeySecondary)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.vertical, HSpace.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Report this experience", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(ExperienceDisplay.reportOptions, id: \.category) { option in
                Button(option.label) { send(option.category) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected.")
        }
    }

    private func contextLine(_ parts: [EntitySummary]) -> some View {
        // Wrapping text with tappable names: each name is its own button in a
        // flowing HStack; the dot separators stay with the names.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { contextButtons(parts) }
            VStack(alignment: .leading, spacing: 2) { contextButtons(parts) }
        }
    }

    @ViewBuilder
    private func contextButtons(_ parts: [EntitySummary]) -> some View {
        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
            HStack(spacing: 4) {
                if index > 0 { Text("·").foregroundStyle(Color.honeyTertiary) }
                if let route = ExperienceDisplay.route(for: part) {
                    Button(part.name ?? "") { openEntity(route) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.honeyAccent)
                } else {
                    Text(part.name ?? "").foregroundStyle(Color.honeyInk)
                }
            }
            .font(HType.secondary.weight(.medium))
            .lineLimit(1)
        }
    }

    private var actions: some View {
        HStack(spacing: HSpace.x2) {
            reactionButton(value: 1, symbol: "hand.thumbsup", label: L10n.t("Matches my experience"), count: reaction.counts?.likes)
            reactionButton(value: -1, symbol: "hand.thumbsdown", label: L10n.t("Doesn’t match my experience"), count: reaction.counts?.dislikes)
            Spacer()
            Menu {
                Button(L10n.t("Report"), systemImage: "flag") { reporting = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.honeySecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(L10n.t("More options"))
        }
        .padding(.top, HSpace.x1)
    }

    private func reactionButton(value: Int, symbol: String, label: String, count: Int?) -> some View {
        let on = reaction.myValue == value
        return Button {
            onReact(value)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? symbol + ".fill" : symbol)
                if let count { Text("\(count)").monospacedDigit() }
            }
            .font(HType.secondary)
            .foregroundStyle(on ? Color.honeyAccent : Color.honeySecondary)
            .padding(.horizontal, HSpace.x3)
            .frame(minWidth: 44, minHeight: 44)
            .background(on ? Color.honeyAccentTint : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : Color.honeyLine, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(ExperienceDisplay.reactionExplainer)
        .sensoryFeedback(.selection, trigger: reaction.myValue)
    }

    private func send(_ category: ReportCategory) {
        Task {
            switch await onReport(category) {
            case .success:
                reportNote = "Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote."
            case .failure(let error):
                reportNote = ExperienceDisplay.reportFailureNote(error)
            }
        }
    }
}
