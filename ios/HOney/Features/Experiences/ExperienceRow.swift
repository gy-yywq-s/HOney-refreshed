//
//  ExperienceRow.swift
//  HOney — a single experience in a feed or list.
//

import SwiftUI

struct ExperienceRow: View {
    let experience: Experience
    var showsPrivacyBadge: Bool = false
    var showsReactions: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                if let label = experience.provenanceLabel {
                    Text(label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.accent)
                }
                if let rating = experience.rating {
                    RatingStars(rating: rating)
                }
                Spacer()
                if showsPrivacyBadge {
                    Text(experience.isPrivate ? "Private" : "Public")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(experience.isPrivate ? Theme.Palette.warning.opacity(0.15) : Theme.Palette.accentSoft)
                        .foregroundStyle(experience.isPrivate ? Theme.Palette.warning : Theme.Palette.accent)
                        .clipShape(Capsule())
                }
            }
            Text(experience.bodyText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
            HStack(spacing: Theme.Spacing.md) {
                if showsReactions, let reactions = experience.reactions {
                    Label("\(reactions.likes)", systemImage: "hand.thumbsup")
                    Label("\(reactions.dislikes)", systemImage: "hand.thumbsdown")
                }
                if let published = experience.publishedDate {
                    Text(published, style: .date)
                }
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

struct RatingStars: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.warning)
            }
        }
        .accessibilityLabel("\(rating) out of 5")
    }
}
