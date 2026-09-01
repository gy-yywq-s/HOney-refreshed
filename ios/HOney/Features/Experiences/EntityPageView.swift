//
//  EntityPageView.swift
//  HOney — a teacher / place / dish page: its experiences + compose.
//  Legacy grammar: AppCard hero, primary button, card feed.
//

import SwiftUI

struct EntityPageView: View {
    let entity: EntityRef

    @Environment(AppModel.self) private var model
    @State private var experiences: [PublicExperience] = []
    @State private var isLoading = true
    @State private var showCompose = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                        Text(entity.type.rawValue.capitalized)
                            .font(AppTheme.Typography.caption2Bold)
                            .foregroundStyle(Palette.ocean)
                        Text(entity.name)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundStyle(Palette.navy)
                    }
                }

                Button {
                    showCompose = true
                } label: {
                    Label("Share an experience", systemImage: "square.and.pencil")
                        .font(AppTheme.Typography.subheadlineSemibold)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                if isLoading {
                    AppLoadingState(title: "Loading experiences")
                } else if let errorMessage {
                    AppBanner(text: errorMessage, style: .error)
                } else if experiences.isEmpty {
                    AppEmptyState(title: "No experiences yet", systemImage: "bubble.left.and.bubble.right")
                } else {
                    ForEach(experiences) { experience in
                        AppCard { InteractiveExperienceRow(experience: experience, services: model.services) }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.pageHorizontal)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showCompose, onDismiss: { Task { await load() } }) {
            ComposeExperienceView(context: .entity(entity)).environment(model)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await model.services.honeyAPI.experiences(entityKey: entity.entityKey)
            experiences = response.experiences
        } catch {
            experiences = []
            errorMessage = "Experiences could not be loaded. Try again."
        }
    }
}
