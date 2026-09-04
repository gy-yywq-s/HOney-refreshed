//
//  LabRootView.swift
//  SanitationLab — the upload flow of spec §7, nothing else on the screen.
//
//  pick → preview → Checking… → (Processing your image…) → result.
//  No implementation words in the copy: no AI, OCR, classifier, pipeline.
//

import PhotosUI
import SwiftUI

struct LabRootView: View {
    @StateObject private var model = LabFlowModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showTestSet = false
    @State private var showRuns = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                preview
                copy
                actions
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Share a photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Run the test set") { showTestSet = true }
                        Button("Past runs") { showRuns = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showTestSet) { TestSetView() }
            .sheet(isPresented: $showRuns) { RunsView() }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await model.load(item) }
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: LabTheme.radius).fill(LabTheme.surface)
            if let image = model.shownImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: LabTheme.radius))
                    .overlay {
                        if model.state == .processing {
                            RoundedRectangle(cornerRadius: LabTheme.radius).fill(.white.opacity(0.35))
                            ProgressView().controlSize(.large)
                        }
                    }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 34))
                        Text("Choose a photo").font(.body)
                    }
                    .foregroundStyle(LabTheme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    @ViewBuilder private var copy: some View {
        switch model.state {
        case .idle, .picked:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking…")
            }
            .font(.subheadline)
            .foregroundStyle(LabTheme.muted)
        case .processing:
            VStack(spacing: 4) {
                Text("Processing your image…").font(.subheadline.weight(.semibold))
                Text("Hiding sensitive parts.").font(.subheadline).foregroundStyle(LabTheme.muted)
            }
        case .clean:
            Text("Ready.").font(.subheadline).foregroundStyle(LabTheme.ok)
        case .sanitized:
            Text("Sensitive parts were hidden before sharing.").font(.subheadline).foregroundStyle(LabTheme.ok)
        case .review:
            VStack(spacing: 4) {
                Text("Please review this image before using it.").font(.subheadline.weight(.semibold))
                Text(model.reviewMessage).font(.subheadline).foregroundStyle(LabTheme.warn)
            }
            .multilineTextAlignment(.center)
        case .confirmed:
            Text("Ready after your review.").font(.subheadline).foregroundStyle(LabTheme.ok)
        case .failed:
            Text("We couldn't safely hide the sensitive parts in this image.")
                .font(.subheadline)
                .foregroundStyle(LabTheme.bad)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var actions: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .picked:
            Button("Share") { Task { await model.submit() } }.buttonStyle(LabButtonStyle())
            PhotosPicker(selection: $pickerItem, matching: .images) { Text("Choose another") }.buttonStyle(LabButtonStyle(filled: false))
        case .checking, .processing:
            Button("Share") {}.buttonStyle(LabButtonStyle()).disabled(true).opacity(0.5)
        case .clean, .sanitized, .confirmed:
            Button("Continue") { model.reset(); pickerItem = nil }.buttonStyle(LabButtonStyle())
            if let ms = model.lastTimings { Text(ms).font(.caption).foregroundStyle(LabTheme.muted) }
        case .review:
            Button("I reviewed it — Use this image") { model.confirmReview() }.buttonStyle(LabButtonStyle())
            PhotosPicker(selection: $pickerItem, matching: .images) { Text("Try another photo") }.buttonStyle(LabButtonStyle(filled: false))
            Button("Remove image") { model.reset(); pickerItem = nil }.buttonStyle(LabButtonStyle(filled: false))
            if let ms = model.lastTimings { Text(ms).font(.caption).foregroundStyle(LabTheme.muted) }
        case .failed:
            PhotosPicker(selection: $pickerItem, matching: .images) { Text("Try another photo") }.buttonStyle(LabButtonStyle())
            Button("Remove image") { model.reset(); pickerItem = nil }.buttonStyle(LabButtonStyle(filled: false))
        }
    }
}

// MARK: - Flow state

@MainActor
final class LabFlowModel: ObservableObject {
    enum State: Equatable { case idle, picked, checking, processing, clean, sanitized, review, confirmed, failed }

    @Published var state: State = .idle
    @Published var shownImage: UIImage?
    @Published var lastTimings: String?
    @Published var reviewMessage = "Check that every detail you want hidden is blurred."

    private var pickedData: Data?
    private let pipeline = SanitationPipeline(classifier: RemoteCredentialClassifier(baseURL: LabConfig.baseURL))

    func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        pickedData = data
        shownImage = image
        lastTimings = nil
        reviewMessage = "Check that every detail you want hidden is blurred."
        state = .picked
    }

    func submit() async {
        guard let data = pickedData else { return }
        let run = await pipeline.run(imageData: data) { [weak self] stage in
            guard let self else { return }
            switch stage {
            case .checking: self.state = .checking
            case .processing: self.state = .processing
            case .done: break
            }
        }
        RunStore.save(run)
        let r = run.record
        lastTimings = "total \(r.totalMs ?? 0) ms · check \(r.classificationMs) ms · detect \(r.detectionMs) ms · hide \(r.sanitationMs) ms"
        switch run.outcome {
        case .clean:
            state = .clean
        case .sanitized:
            if let cg = run.outputImage { shownImage = UIImage(cgImage: cg) }
            state = .sanitized
        case .reviewRequired(let reasons):
            if let cg = run.outputImage { shownImage = UIImage(cgImage: cg) }
            if reasons.contains(.nothingSensitiveLocated) || reasons.contains(.sensitiveDetailNotLocated) {
                reviewMessage = "Some sensitive details may not have been found. Check the whole image carefully."
            } else if reasons.contains(.verificationIncomplete) {
                reviewMessage = "This is the best available result, but something may still be readable."
            } else if reasons.contains(.timeBudgetReached) {
                reviewMessage = "This is the best result completed in time. Check the whole image carefully."
            } else {
                reviewMessage = "This is the best available result. Check every blurred area and any detail still visible."
            }
            state = .review
        case .couldNotSanitize:
            state = .failed
        }
    }

    func confirmReview() {
        guard state == .review else { return }
        state = .confirmed
    }

    func reset() {
        pickedData = nil
        shownImage = nil
        reviewMessage = "Check that every detail you want hidden is blurred."
        state = .idle
    }
}

enum LabConfig {
    /// The HOney edge; the classifier route needs no account.
    static let baseURL = URL(string: "https://honey.gaelisus.com")!
}
