//
//  ReportSheet.swift
//  HOney — report a published experience against the community rules.
//  A report is a rule-based flag, NOT a disagreement vote (App A §22).
//  Category-only (audit §3.9): there is no free-text box, and nothing is
//  preselected. The post is automatically re-checked against the current
//  rules — no human queue, and no way to see who wrote it.
//

import SwiftUI

struct ReportSheet: View {
    /// Submits the chosen category (the wire `ReportCategory`).
    let onSubmit: (ReportCategory) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: ReportCategory?
    @State private var submitting = false
    @State private var done = false
    @State private var errorMessage: String?

    private static let rowBackground = Palette.surface

    var body: some View {
        NavigationStack {
            Form {
                if done {
                    Section {
                        Text("Thanks. The post has been automatically re-checked against the current community rules. The report adds no author field or free-text note.")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(Palette.ink)
                    }
                    .listRowBackground(Self.rowBackground)
                } else {
                    if let errorMessage {
                        Section {
                            AppBanner(text: errorMessage, style: .error)
                        }
                        .listRowBackground(Color.clear)
                    }
                    Section {
                        ForEach(ReportCategory.allCases) { option in
                            Button {
                                category = option
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .font(AppTheme.Typography.subheadline)
                                        .foregroundStyle(Palette.navy)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if category == option {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Palette.ocean)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("A report is for a rule violation — it is not a disagreement vote. If you simply disagree, that is what Dislike is for.")
                    } footer: {
                        Text("Reports are a category only — there is no free-text box. The post is automatically re-checked against the current rules; sensitive detail belongs with the school, not here.")
                    }
                    .listRowBackground(Self.rowBackground)
                }
            }
            .textCase(nil)
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .tint(Palette.ocean)
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(done ? "Done" : "Cancel") { dismiss() }
                }
                if !done {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(submitting ? "Sending…" : "Send report") {
                            guard let category else { return }
                            submitting = true
                            Task {
                                do {
                                    try await onSubmit(category)
                                    done = true
                                    errorMessage = nil
                                } catch {
                                    errorMessage = "The report was not sent. Check your connection and try again."
                                }
                                submitting = false
                            }
                        }
                        .disabled(category == nil || submitting)
                    }
                }
            }
        }
    }
}
