//
//  ComposeExperienceView.swift
//  HOney — compose a lesson-linked, entity-linked or standalone experience.
//  Dish entities get an optional 1–5 rating; nothing else does. The Six Checks
//  appear as contextual hints, not checkboxes.
//

import SwiftUI

enum ComposeContext {
    case standalone
    case lesson(Lesson)
    case entity(Entity)

    var title: String {
        switch self {
        case .standalone: return "Share an experience"
        case .lesson(let lesson): return lesson.subjectName
        case .entity(let entity): return entity.name
        }
    }

    var subtitle: String? {
        switch self {
        case .standalone: return "Standalone — not linked to a lesson"
        case .lesson(let lesson): return lesson.teacherName.map { "with \($0)" }
        case .entity(let entity): return entity.type.rawValue.capitalized
        }
    }

    var allowsRating: Bool {
        if case .entity(let entity) = self { return entity.type == .dish }
        return false
    }

    var lessonId: String? {
        if case .lesson(let lesson) = self { return lesson.id }
        return nil
    }

    var entityKey: String? {
        if case .entity(let entity) = self { return entity.entityKey }
        return nil
    }
}

struct ComposeExperienceView: View {
    let context: ComposeContext

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var body_ = ""
    @State private var rating = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.title)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if let subtitle = context.subtitle {
                            Text(subtitle)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }

                Section("Your experience") {
                    TextEditor(text: $body_)
                        .frame(minHeight: 140)
                        .font(Theme.Typography.body)
                }

                if context.allowsRating {
                    Section("Rating (optional)") {
                        Stepper(value: $rating, in: 0...5) {
                            HStack {
                                Text(rating == 0 ? "No rating" : "\(rating) / 5")
                                if rating > 0 { RatingStars(rating: rating) }
                            }
                        }
                    }
                }

                Section("A few things to keep in mind") {
                    ForEach(SixChecks.all) { check in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(Theme.Typography.caption.weight(.semibold))
                                .foregroundStyle(Theme.Palette.accent)
                            Text(check.prompt)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }

                if let errorMessage {
                    Section { Banner(kind: .error, message: errorMessage) }
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") { submit() }
                        .disabled(!canSubmit || isSubmitting)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        let request = CreateExperienceRequest(
            lessonId: context.lessonId,
            entityKey: context.entityKey,
            body: body_.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: context.allowsRating && rating > 0 ? rating : nil
        )
        Task {
            defer { isSubmitting = false }
            do {
                let response = try await model.services.honeyAPI.createExperience(request)
                // Persist the ownership key on-device so this post can later be
                // seen, re-confirmed or revoked. The server keeps no author id.
                await model.services.ownershipKeyStore.add(experienceId: response.experienceId, ownershipKey: response.ownershipKey)
                dismiss()
            } catch {
                errorMessage = "Could not post your experience. Please try again."
            }
        }
    }
}
