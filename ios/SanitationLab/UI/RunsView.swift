//
//  RunsView.swift
//  SanitationLab — every run kept on this phone, before/after and record.
//

import SwiftUI

struct RunsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runs: [StoredRun] = []

    var body: some View {
        NavigationStack {
            List {
                if runs.isEmpty {
                    Text("No runs yet.").foregroundStyle(LabTheme.muted)
                }
                ForEach(runs) { run in
                    NavigationLink(value: run.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(run.record.fixtureId ?? "photo").font(.footnote.monospaced())
                            Text("\(run.record.outcome) · \(run.record.startedAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption2).foregroundStyle(LabTheme.muted)
                        }
                    }
                }
            }
            .navigationTitle("Past runs")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let run = runs.first(where: { $0.id == id }) {
                    RunDetailView(before: UIImage(contentsOfFile: run.beforeURL.path), after: UIImage(contentsOfFile: run.afterURL.path), record: run.record)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { RunStore.clear(); runs = [] }.disabled(runs.isEmpty)
                }
            }
            .onAppear { runs = RunStore.list() }
        }
    }
}
