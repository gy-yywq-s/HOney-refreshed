//
//  ExperienceRow.swift
//  HOney — a single public experience in a feed or list. Raw-first: the body is
//  rendered verbatim; provenance is labeled honestly; the only date shown is
//  the coarse public day bucket; reactions stay hidden while the server
//  withholds counts (small-cohort threshold → `reactions == nil`).
//  Legacy grammar: provenance as an ocean chip, navy opacity ladder.
//

import SwiftUI

struct ExperienceRow: View {
    let experience: PublicExperience
    var showsReactions: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(spacing: AppTheme.Spacing.small) {
                Text(experience.provenance.label)
                    .font(AppTheme.Typography.caption2Bold)
                    .foregroundStyle(Palette.ocean)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Palette.ocean.opacity(0.10), in: Capsule())
                if let rating = experience.rating {
                    RatingStars(rating: rating)
                }
                Spacer()
                if let published = experience.publishedDate {
                    Text(published, style: .date)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Palette.navy.opacity(0.48))
                }
            }
            Text(experience.bodyText)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(Palette.navy.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            if showsReactions, let reactions = experience.reactions {
                HStack(spacing: AppTheme.Spacing.medium) {
                    Label("\(reactions.likes)", systemImage: "hand.thumbsup")
                    Label("\(reactions.dislikes)", systemImage: "hand.thumbsdown")
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(Palette.navy.opacity(0.48))
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
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(Palette.warning)
            }
        }
        .accessibilityLabel("\(rating) out of 5")
    }
}
