//
//  InteractiveExperienceRow.swift
//  HOney — a browse-feed row with participation affordances (react + report).
//  Wraps the display-only ExperienceRow; My-submissions/Home use the plain row.
//

import SwiftUI

struct InteractiveExperienceRow: View {
    let experience: Experience
    let services: AppServices

    @State private var reporting = false
    /// Session-local highlight only; the server keeps no per-user reaction state
    /// it can hand back, so we reflect the last tap this session.
    @State private var myVote = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ExperienceRow(experience: experience, showsReactions: false)
            HStack(spacing: Theme.Spacing.lg) {
                reactionButton(value: 1, symbol: "hand.thumbsup", count: experience.reactions?.likes)
                reactionButton(value: -1, symbol: "hand.thumbsdown", count: experience.reactions?.dislikes)
                Spacer()
                Button {
                    reporting = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
                .buttonStyle(.plain)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
            .font(Theme.Typography.caption)
        }
        .sheet(isPresented: $reporting) {
            ReportSheet { category, note in
                try? await services.honeyAPI.report(experienceId: experience.id, category: category, note: note)
            }
        }
    }

    // Only verified-exposure users can react; the backend enforces that and
    // small-cohort counts stay hidden (count == nil) until the threshold.
    private func reactionButton(value: Int, symbol: String, count: Int?) -> some View {
        let selected = myVote == value
        return Button {
            myVote = selected ? 0 : value
            let sending = myVote
            Task { try? await services.honeyAPI.react(experienceId: experience.id, value: sending) }
        } label: {
            Label(count.map(String.init) ?? "", systemImage: selected ? "\(symbol).fill" : symbol)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.textSecondary)
        .accessibilityLabel(value == 1 ? "This matched my experience" : "This did not match my experience")
    }
}
