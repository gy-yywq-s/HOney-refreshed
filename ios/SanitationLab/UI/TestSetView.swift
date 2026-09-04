//
//  TestSetView.swift
//  SanitationLab — runs the bundled fixtures on the phone and shows what
//  came back against what was expected, with the latencies the spec asks
//  to measure separately (classification / detection / sanitation).
//

import SwiftUI

struct TestSetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var runner = TestSetRunner()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Use the live classifier", isOn: $runner.live).disabled(runner.running)
                    HStack {
                        Text(runner.summary).font(.footnote).foregroundStyle(LabTheme.muted)
                        Spacer()
                        Button(runner.running ? "Running…" : "Run all") { Task { await runner.runAll() } }
                            .disabled(runner.running)
                    }
                }
                ForEach(runner.rows) { row in
                    NavigationLink(value: row) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.id).font(.footnote.monospaced())
                                Text("expected \(row.item.expected)").font(.caption2).foregroundStyle(LabTheme.muted)
                            }
                            Spacer()
                            if let r = row.record {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(r.outcome).font(.caption.weight(.semibold)).foregroundStyle(row.tone)
                                    Text("\(r.classificationMs)/\(r.detectionMs)/\(r.sanitationMs) ms").font(.caption2).foregroundStyle(LabTheme.muted)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Test set")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TestSetRunner.Row.self) { row in RunDetailView(before: row.before, after: row.after, record: row.record) }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .task { runner.loadIfNeeded() }
        }
    }
}

@MainActor
final class TestSetRunner: ObservableObject {
    struct Row: Identifiable, Hashable {
        var item: FixtureManifest.Item
        var record: SanitationRecord?
        var before: UIImage?
        var after: UIImage?
        var id: String { item.id }
        static func == (a: Row, b: Row) -> Bool { a.id == b.id && a.record == b.record }
        func hash(into h: inout Hasher) { h.combine(id) }

        var tone: Color {
            guard let r = record else { return LabTheme.muted }
            switch (item.expected, r.outcome) {
            case ("CLEAN", "CLEAN"), ("SANITIZED", "SANITIZED"): return LabTheme.ok
            case ("UNCERTAIN", _): return LabTheme.warn
            case (_, "REVIEW_REQUIRED"): return LabTheme.warn
            case ("SANITIZED", "COULD_NOT_SANITIZE"): return LabTheme.warn
            default: return LabTheme.bad
            }
        }
    }

    @Published var rows: [Row] = []
    @Published var running = false
    @Published var live = true
    @Published var summary = ""

    private var folder: URL?
    private var manifest: FixtureManifest?

    func loadIfNeeded() {
        guard rows.isEmpty, let loaded = FixtureManifest.load() else { return }
        manifest = loaded.manifest
        folder = loaded.folder
        rows = loaded.manifest.items.map { Row(item: $0) }
        summary = "\(rows.count) fixtures"
    }

    func runAll() async {
        guard let manifest, let folder else { return }
        running = true
        var right = 0, judged = 0, reviewRequired = 0
        var totals: [Int] = []
        for (i, item) in manifest.items.enumerated() {
            guard let data = manifest.data(for: item, in: folder) else { continue }
            let classifier: CredentialClassifier = live
                ? RemoteCredentialClassifier(baseURL: LabConfig.baseURL)
                : StubCredentialClassifier(credentialLike: item.expected != "CLEAN", delayMs: 0)
            let pipeline = SanitationPipeline(classifier: classifier)
            let run = await pipeline.run(imageData: data, fixtureId: item.id)
            RunStore.save(run)
            rows[i].record = run.record
            rows[i].before = UIImage(data: data)
            rows[i].after = run.outputImage.map { UIImage(cgImage: $0) }
            if item.expected != "UNCERTAIN" {
                judged += 1
                if run.outcome.label == item.expected { right += 1 }
            }
            if run.requiresUserConfirmation { reviewRequired += 1 }
            totals.append(run.record.totalMs ?? 0)
            summary = "\(i + 1)/\(rows.count) · \(right)/\(judged) as expected · review \(reviewRequired)"
        }
        let sorted = totals.sorted()
        let p50 = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let p90 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
        summary = "\(right)/\(judged) as expected · review \(reviewRequired) · total p50 \(p50) ms p90 \(p90) ms"
        running = false
    }
}

struct RunDetailView: View {
    var before: UIImage?
    var after: UIImage?
    var record: SanitationRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let before { labelled("Before", before) }
                if let after { labelled("After", after) }
                if let r = record {
                    Group {
                        let review = (r.reviewReasons ?? []).map(\.rawValue).joined(separator: ", ")
                        Text(r.outcome + (r.reason.map { " · \($0.rawValue)" } ?? "") + (review.isEmpty ? "" : " · \(review)")).font(.headline)
                        Text("decision \(r.decision.rawValue)")
                        Text("classifier \(r.classifier.available ? (r.classifier.credentialLike ? "credential" : "clean") : "unavailable")\(r.classifier.uncertain ? " (uncertain)" : "") · \(r.classifier.model ?? "—")")
                        Text("total \(r.totalMs ?? 0) ms · check \(r.classificationMs) ms · detect \(r.detectionMs) ms · hide \(r.sanitationMs) ms")
                        Text("faces \(r.facesFound) · codes \(r.codesFound) · text lines \(r.textLinesFound) · derivative \(r.derivativeBytes / 1024) KB")
                        Text("regions " + r.regionCounts.map { "\($0.key.rawValue) \($0.value)" }.sorted().joined(separator: ", "))
                        if let v = r.verification {
                            Text("verify: codes left \(v.codesStillDecodable), values left \(v.valuesStillReadable.count)\(v.retriedWider ? " (after wider retry)" : "")")
                        }
                    }
                    .font(.footnote.monospaced())
                }
            }
            .padding(16)
        }
        .navigationTitle(record?.fixtureId ?? "Run")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labelled(_ title: String, _ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(LabTheme.muted)
            Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
