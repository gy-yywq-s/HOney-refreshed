//
//  InteractiveExperienceRow.swift
//  HOney — a browse-feed row with participation affordances (react + report).
//  Wraps the display-only ExperienceRow; My-submissions/Home use the plain row.
//

import SwiftUI

struct InteractiveExperienceRow: View {
    let experience: PublicExperience
    let services: AppServices
    var targetLabel: String? = nil

    @State private var reporting = false
    /// Session-local highlight only; the server keeps no per-user reaction state
    /// it can hand back, so we reflect the last tap this session.
    @State private var myVote = 0
    @State private var sendingVote: Int?
    @State private var reactionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            ExperienceRow(experience: experience, targetLabel: targetLabel, showsReactions: false)
            HStack(spacing: AppTheme.Spacing.large) {
                reactionButton(value: 1, symbol: "hand.thumbsup", count: experience.reactions?.likes)
                reactionButton(value: -1, symbol: "hand.thumbsdown", count: experience.reactions?.dislikes)
                Spacer()
                Button {
                    reporting = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
                .buttonStyle(.plain)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 44, minHeight: 44)
            }
            .font(AppTheme.Typography.caption)

            if let reactionError {
                Text(reactionError)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Palette.error)
            }
        }
        .sheet(isPresented: $reporting) {
            ReportSheet { category in
                try await services.honeyAPI.report(experienceId: experience.id, category: category)
            }
        }
    }

    // Only verified-exposure users can react; the backend enforces that and
    // small-cohort counts stay hidden (count == nil) until the threshold.
    private func reactionButton(value: Int, symbol: String, count: Int?) -> some View {
        let selected = myVote == value
        return Button {
            let sending = selected ? 0 : value
            sendingVote = sending
            reactionError = nil
            Task {
                do {
                    try await services.honeyAPI.react(experienceId: experience.id, value: sending)
                    myVote = sending
                } catch {
                    reactionError = "Reaction not saved. Try again."
                }
                sendingVote = nil
            }
        } label: {
            Label(count.map(String.init) ?? "", systemImage: selected ? "\(symbol).fill" : symbol)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Palette.ocean : Palette.inkSecondary)
        .frame(minWidth: 44, minHeight: 44)
        .disabled(sendingVote != nil)
        .accessibilityLabel(value == 1 ? "This matched my experience" : "This did not match my experience")
    }
}
