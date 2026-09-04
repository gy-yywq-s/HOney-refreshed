//
//  SanitationPipeline.swift
//  SanitationLab — the whole flow of spec §4, one call.
//
//  derivative → (classifier ‖ detectors) → decide → regions → sanitize →
//  verify → outcome + record. Uncertain paths return their best guess with an
//  explicit user-confirmation requirement instead of becoming dead ends.
//

import CoreGraphics
import Foundation
import UIKit

struct SanitationBudget: Equatable {
    static let maxModelCallsPerRun = 1

    /// Product hard gate: the full flow must stay below five seconds.
    var hardLimitMs: Int = 4_800
    /// Leave time for local blur and verification after the one model call.
    var classifierWaitMs: Int = 3_200
    /// Do not start the optional wider retry without this much headroom.
    var retryReserveMs: Int = 900

    static let production = SanitationBudget()
}

struct SanitationRun {
    var outcome: SanitationOutcome
    var record: SanitationRecord
    /// The bytes as picked — what CLEAN publishes, what the harness keeps as "before".
    var originalData: Data
    /// The sanitized encoding, or the best-guess bytes for REVIEW_REQUIRED.
    var outputData: Data?
    var outputImage: CGImage?
    var workingImage: CGImage?

    var requiresUserConfirmation: Bool {
        if case .reviewRequired = outcome { return true }
        return false
    }
}

final class SanitationPipeline {
    let classifier: CredentialClassifier
    let detectors: LocalDetectors
    let budget: SanitationBudget

    init(classifier: CredentialClassifier, detectors: LocalDetectors = LocalDetectors(), budget: SanitationBudget = .production) {
        self.classifier = classifier
        self.detectors = detectors
        self.budget = budget
    }

    func run(imageData: Data, fixtureId: String? = nil, onStage: @escaping @MainActor (SanitationStage) -> Void = { _ in }) async -> SanitationRun {
        let startedAt = Date()
        var record = SanitationRecord(
            fixtureId: fixtureId, startedAt: startedAt, imageSize: .zero, derivativeBytes: 0,
            classifier: .unavailable(latencyMs: 0), decision: .noSignalsWithClassifierDown, detectorsUsed: [],
            facesFound: 0, codesFound: 0, textLinesFound: 0, regions: [], classificationMs: 0, detectionMs: 0,
            sanitationMs: 0, verification: nil, outcome: "", reason: nil)

        func finish(_ outcome: SanitationOutcome, output: (Data, CGImage)? = nil, working: CGImage? = nil) async -> SanitationRun {
            record.totalMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            record.outcome = outcome.label
            record.reason = nil
            record.reviewReasons = nil
            switch outcome {
            case .couldNotSanitize(let reason): record.reason = reason
            case .reviewRequired(let reasons): record.reviewReasons = reasons
            case .clean, .sanitized: break
            }
            await onStage(.done(outcome))
            return SanitationRun(outcome: outcome, record: record, originalData: imageData, outputData: output?.0, outputImage: output?.1, workingImage: working)
        }

        guard let picked = UIImage(data: imageData), let cg = AnalysisDerivative.normalised(picked),
              let derivative = AnalysisDerivative.make(from: cg) else {
            return await finish(.couldNotSanitize(.imageUnusable))
        }
        record.imageSize = CGSize(width: cg.width, height: cg.height)
        record.derivativeBytes = derivative.data.count
        await onStage(.checking)

        // Classifier and detectors in parallel (spec §6).
        let detectionTask = Task { await detectors.detect(cg) }
        let classification = Date()
        let answer = await classifyOnce(jpeg: derivative.data)
        record.classifier = answer
        record.classificationMs = Int(Date().timeIntervalSince(classification) * 1000)

        var reviewReasons: [ReviewReason] = []
        func requireReview(_ reason: ReviewReason) {
            if !reviewReasons.contains(reason) { reviewReasons.append(reason) }
        }
        func elapsedMs() -> Int { Int(Date().timeIntervalSince(startedAt) * 1000) }

        // The fixed pipeline, not the model, decides which detailed rules run.
        // A clean model verdict can be overridden by labels, MRZ or codes.
        let d = await detectionTask.value
        note(d, into: &record)
        let probe = SensitiveRegionFinder.find(
            RegionFinderInput(faces: d.faces, codes: d.codes, lines: d.lines, imageSize: record.imageSize),
            credentialLike: false)
        let faceRegions = probe.regions.filter { $0.kind == .portrait }
        var runCredentialRules = false
        var faceOnlyRegions: [SensitiveRegion]?

        if answer.available, answer.credentialLike {
            record.decision = .classifierSaidCredential
            runCredentialRules = true
        } else if probe.credentialSignal {
            record.decision = answer.available ? .localSignalsOverrodeClassifierClean : .localSignalsWithClassifierDown
            runCredentialRules = true
        } else if !faceRegions.isEmpty {
            record.decision = answer.available ? .classifierSaidCleanFacesFound : .localSignalsWithClassifierDown
            faceOnlyRegions = faceRegions
        } else if answer.available, answer.uncertain {
            record.decision = .classifierSaidClean
            requireReview(.classifierUncertain)
            return await finish(.reviewRequired(reviewReasons), output: (imageData, cg), working: cg)
        } else {
            record.decision = answer.available ? .classifierSaidClean : .noSignalsWithClassifierDown
            return await finish(.clean, working: cg)
        }

        await onStage(.processing)
        let sanitation = Date()
        let found: RegionFinderResult
        if runCredentialRules {
            found = SensitiveRegionFinder.find(
                RegionFinderInput(faces: d.faces, codes: d.codes, lines: d.lines, imageSize: record.imageSize),
                credentialLike: true)
        } else {
            found = RegionFinderResult(regions: faceOnlyRegions ?? [], labelWithoutValue: false, labelsSeen: [])
        }
        record.regions = found.regions
        if found.labelWithoutValue { requireReview(.sensitiveDetailNotLocated) }
        if found.regions.isEmpty {
            requireReview(.nothingSensitiveLocated)
            if !answer.available { requireReview(.classifierUnavailable) }
            record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
            return await finish(.reviewRequired(reviewReasons), output: (imageData, cg), working: cg)
        }

        // Sanitize and verify. The second, wider pass is optional and only
        // starts when enough of the 4.8 s product budget remains.
        var grow: CGFloat = 0
        var verification: SanitationRecord.Verification?
        var lastOutput: CGImage?
        for attempt in 0..<2 {
            if attempt > 0, elapsedMs() + budget.retryReserveMs >= budget.hardLimitMs {
                requireReview(.timeBudgetReached)
                break
            }
            guard let output = Sanitizer.sanitize(cg, regions: found.regions, grow: grow) else { break }
            lastOutput = output
            if elapsedMs() + budget.retryReserveMs >= budget.hardLimitMs {
                requireReview(.timeBudgetReached)
                break
            }
            var v = await Sanitizer.verify(output, regions: found.regions, languages: detectors.recognitionLanguages)
            v.retriedWider = attempt > 0
            verification = v
            if v.codesStillDecodable == 0, v.valuesStillReadable.isEmpty {
                guard let data = AnalysisDerivative.encodeOutput(output) else { break }
                record.verification = v
                record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
                if elapsedMs() >= budget.hardLimitMs { requireReview(.timeBudgetReached) }
                let outcome: SanitationOutcome = reviewReasons.isEmpty ? .sanitized : .reviewRequired(reviewReasons)
                return await finish(outcome, output: (data, output), working: cg)
            }
            grow = 0.25
        }
        record.verification = verification
        record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
        if let lastOutput, let data = AnalysisDerivative.encodeOutput(lastOutput) {
            if !reviewReasons.contains(.timeBudgetReached) { requireReview(.verificationIncomplete) }
            return await finish(.reviewRequired(reviewReasons), output: (data, lastOutput), working: cg)
        }
        return await finish(.couldNotSanitize(.imageUnusable), working: cg)
    }

    /// Exactly one classifier request competes with a local deadline. There is
    /// no retry or second model, keeping remote cost at 1x the original flow.
    private func classifyOnce(jpeg: Data) async -> ClassifierAnswer {
        let started = Date()
        return await withTaskGroup(of: ClassifierAnswer.self) { group in
            group.addTask { await self.classifier.classify(jpeg: jpeg) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.budget.classifierWaitMs) * 1_000_000)
                return .unavailable(latencyMs: Int(Date().timeIntervalSince(started) * 1000))
            }
            let first = await group.next() ?? .unavailable(latencyMs: 0)
            group.cancelAll()
            return first
        }
    }

    private func note(_ d: Detections, into record: inout SanitationRecord) {
        record.detectorsUsed = d.used
        record.facesFound = d.faces.count
        record.codesFound = d.codes.count
        record.textLinesFound = d.lines.count
        record.detectionMs = d.elapsedMs
    }
}
