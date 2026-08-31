//
//  MySubmissionsView.swift
//  HOney — the user's own posts, recovered via device-held ownership keys.
//  Public and private notes are visually distinct; revoke + reconfirm supported.
//

import SwiftUI

struct MySubmissionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var experiences: [Experience] = []
    @State private var isLoading = true
    @State private var busyId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if experiences.isEmpty {
                    EmptyStateView(
                        systemImage: "person.crop.circle",
                        title: "No submissions on this device",
                        message: "Experiences you post are recovered using keys stored only on this device."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(experiences) { experience in
                                Card {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                        ExperienceRow(experience: experience, showsPrivacyBadge: true)
                                        HStack {
                                            Button(role: .destructive) {
                                                Task { await revoke(experience) }
                                            } label: { Label("Revoke", systemImage: "trash") }
                                                .font(Theme.Typography.caption)
                                            Spacer()
                                            Button {
                                                Task { await reconfirm(experience) }
                                            } label: { Label("Re-confirm", systemImage: "checkmark.seal") }
                                                .font(Theme.Typography.caption)
                                        }
                                        .disabled(busyId == experience.id)
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                }
            }
            .screenBackground()
            .navigationTitle("My submissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let keys = await model.services.ownershipKeyStore.keys()
        guard !keys.isEmpty else { experiences = []; return }
        let response = try? await model.services.honeyAPI.myExperiences(keys: keys)
        experiences = response?.experiences ?? []
    }

    private func revoke(_ experience: Experience) async {
        busyId = experience.id
        defer { busyId = nil }
        guard let key = await model.services.ownershipKeyStore.ownershipKey(for: experience.id) else { return }
        try? await model.services.honeyAPI.revokeExperience(ownershipKey: key)
        await model.services.ownershipKeyStore.remove(experienceId: experience.id)
        await load()
    }

    private func reconfirm(_ experience: Experience) async {
        busyId = experience.id
        defer { busyId = nil }
        guard let key = await model.services.ownershipKeyStore.ownershipKey(for: experience.id) else { return }
        try? await model.services.honeyAPI.reconfirmExperience(ownershipKey: key)
    }
}
