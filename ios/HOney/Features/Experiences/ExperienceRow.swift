//
//  ExperienceRow.swift
//  HOney — a single public experience in a feed or list. Raw-first: the body is
//  rendered verbatim; provenance is labeled honestly; the only date shown is
//  the coarse public day bucket; reactions stay hidden while the server
//  withholds counts (small-cohort threshold → `reactions == nil`).
//

import SwiftUI

struct ExperienceRow: View {
    let experience: PublicExperience
    var showsReactions: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(experience.provenance.label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.accent)
                if let rating = experience.rating {
                    RatingStars(rating: rating)
                }
                Spacer()
                if let published = experience.publishedDate {
                    Text(published, style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Text(experience.bodyText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
            if showsReactions, let reactions = experience.reactions {
                HStack(spacing: Theme.Spacing.md) {
                    Label("\(reactions.likes)", systemImage: "hand.thumbsup")
                    Label("\(reactions.dislikes)", systemImage: "hand.thumbsdown")
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            }
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
