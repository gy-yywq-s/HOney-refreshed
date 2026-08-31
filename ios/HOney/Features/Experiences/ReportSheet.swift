//
//  ReportSheet.swift
//  HOney — report a published experience against the community rules.
//  A report is a rule-based flag, NOT a disagreement vote (App A §22).
//

import SwiftUI

struct ReportSheet: View {
    /// Submits (category, note). The category strings match the backend's
    /// rule-based report categories.
    let onSubmit: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: ReportCategory = .notExperience
    @State private var note = ""
    @State private var submitting = false

    enum ReportCategory: String, CaseIterable, Identifiable {
        case seriousAllegation = "serious_allegation"
        case doxxing = "doxxing"
        case slur = "slur"
        case targetsStudent = "targets_student"
        case notExperience = "not_experience"
        case otherRule = "other_rule"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .seriousAllegation: return "Serious allegation"
            case .doxxing: return "Private information"
            case .slur: return "Slur or dehumanizing"
            case .targetsStudent: return "Targets a student"
            case .notExperience: return "Not an experience"
            case .otherRule: return "Other rule break"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $category) {
                        ForEach(ReportCategory.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Add a note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text("Reports are checked against the community rules — they are not a disagreement vote. Disliking a post is not a reason to report it.")
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submitting = true
                        Task {
                            await onSubmit(category.rawValue, note)
                            dismiss()
                        }
                    }
                    .disabled(submitting)
                }
            }
        }
    }
}
