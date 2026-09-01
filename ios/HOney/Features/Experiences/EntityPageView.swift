//
//  EntityPageView.swift
//  HOney — a teacher / course / room / dish page: its experiences + compose.
//

import SwiftUI

struct EntityPageView: View {
    let entity: Entity

    @Environment(AppModel.self) private var model
    @State private var experiences: [Experience] = []
    @State private var isLoading = true
    @State private var showCompose = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(entity.type.rawValue.capitalized)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text(entity.name)
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                }

                Button {
                    showCompose = true
                } label: {
                    Label("Share an experience", systemImage: "square.and.pencil")
                }
                .buttonStyle(HOneyPrimaryButtonStyle())

                if isLoading {
                    LoadingView().frame(height: 160)
                } else if experiences.isEmpty {
                    EmptyStateView(
                        systemImage: "bubble.left.and.bubble.right",
                        title: "No experiences yet"
                    )
                } else {
                    ForEach(experiences) { experience in
                        Card { InteractiveExperienceRow(experience: experience, services: model.services) }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showCompose, onDismiss: { Task { await load() } }) {
            ComposeExperienceView(context: .entity(entity)).environment(model)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let response = try? await model.services.honeyAPI.experiences(entityKey: entity.entityKey)
        experiences = response?.experiences ?? []
    }
}
