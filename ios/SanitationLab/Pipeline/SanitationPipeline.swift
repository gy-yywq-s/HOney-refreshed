//
//  SanitationPipeline.swift
//  SanitationLab — the whole flow of spec §4, one call.
//
//  derivative → (classifier ‖ detectors) → decide → regions → sanitize →
//  verify → outcome + record. Clean images return the ORIGINAL bytes as soon
//  as the classifier answers; only credential images wait for the detectors.
//

import CoreGraphics
import Foundation
import UIKit

struct SanitationRun {
    var outcome: SanitationOutcome
    var record: SanitationRecord
    /// The bytes as picked — what CLEAN publishes, what the harness keeps as "before".
    var originalData: Data
    /// The sanitized encoding — only for SANITIZED.
    var outputData: Data?
    var outputImage: CGImage?
    var workingImage: CGImage?
}

final class SanitationPipeline {
    let classifier: CredentialClassifier
    let detectors: LocalDetectors

    init(classifier: CredentialClassifier, detectors: LocalDetectors = LocalDetectors()) {
        self.classifier = classifier
        self.detectors = detectors
    }

    func run(imageData: Data, fixtureId: String? = nil, onStage: @escaping @MainActor (SanitationStage) -> Void = { _ in }) async -> SanitationRun {
        let startedAt = Date()
        var record = SanitationRecord(
            fixtureId: fixtureId, startedAt: startedAt, imageSize: .zero, derivativeBytes: 0,
            classifier: .unavailable(latencyMs: 0), decision: .noSignalsWithClassifierDown, detectorsUsed: [],
            facesFound: 0, codesFound: 0, textLinesFound: 0, regions: [], classificationMs: 0, detectionMs: 0,
            sanitationMs: 0, verification: nil, outcome: "", reason: nil)

        func finish(_ outcome: SanitationOutcome, output: (Data, CGImage)? = nil, working: CGImage? = nil) async -> SanitationRun {
            record.outcome = outcome.label
            if case .couldNotSanitize(let reason) = outcome { record.reason = reason }
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
        let answer = await classifier.classify(jpeg: derivative.data)
        record.classifier = answer
        record.classificationMs = Int(Date().timeIntervalSince(classification) * 1000)

        // Decide. Face privacy is unconditional: a classifier-clean image is
        // still sanitized when local detection finds one or more faces. In
        // that branch only faces are touched; credential-only text/code rules
        // remain gated by the classifier.
        var classifierCleanFaceRegions: [SensitiveRegion]?
        if answer.available {
            if answer.credentialLike {
                record.decision = .classifierSaidCredential
            } else {
                let d = await detectionTask.value
                note(d, into: &record)
                let bounds = CGRect(origin: .zero, size: record.imageSize)
                let faces = d.faces.map {
                    SensitiveRegion(kind: .portrait, rect: SensitiveRegionFinder.portraitFrame(around: $0, in: bounds), value: nil, detail: nil)
                }
                guard !faces.isEmpty else {
                    record.decision = .classifierSaidClean
                    return await finish(.clean, working: cg)
                }
                record.decision = .classifierSaidCleanFacesFound
                classifierCleanFaceRegions = faces
            }
        } else {
            let d = await detectionTask.value
            note(d, into: &record)
            let probe = SensitiveRegionFinder.find(RegionFinderInput(faces: d.faces, codes: d.codes, lines: d.lines, imageSize: record.imageSize), credentialLike: false)
            record.decision = probe.strongSignal ? .localSignalsWithClassifierDown : .noSignalsWithClassifierDown
            if !probe.strongSignal { return await finish(.clean, working: cg) }
        }

        await onStage(.processing)
        let sanitation = Date()
        let d = await detectionTask.value
        note(d, into: &record)
        let found: RegionFinderResult
        if let classifierCleanFaceRegions {
            found = RegionFinderResult(regions: classifierCleanFaceRegions, labelWithoutValue: false, labelsSeen: [])
        } else {
            found = SensitiveRegionFinder.find(RegionFinderInput(faces: d.faces, codes: d.codes, lines: d.lines, imageSize: record.imageSize), credentialLike: true)
        }
        record.regions = found.regions
        if found.labelWithoutValue {
            record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
            return await finish(.couldNotSanitize(.numberNotLocated), working: cg)
        }
        if found.regions.isEmpty {
            record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
            return await finish(.couldNotSanitize(.nothingLocated), working: cg)
        }

        // Sanitize, verify, one wider retry.
        var grow: CGFloat = 0
        var verification: SanitationRecord.Verification?
        for attempt in 0..<2 {
            guard let output = Sanitizer.sanitize(cg, regions: found.regions, grow: grow) else { break }
            var v = await Sanitizer.verify(output, regions: found.regions, languages: detectors.recognitionLanguages)
            v.retriedWider = attempt > 0
            verification = v
            if v.codesStillDecodable == 0, v.valuesStillReadable.isEmpty {
                guard let data = AnalysisDerivative.encodeOutput(output) else { break }
                record.verification = v
                record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
                return await finish(.sanitized, output: (data, output), working: cg)
            }
            grow = 0.25
        }
        record.verification = verification
        record.sanitationMs = Int(Date().timeIntervalSince(sanitation) * 1000)
        let reason: CouldNotSanitizeReason = (verification?.codesStillDecodable ?? 0) > 0 ? .codeStillReadable : .numberStillReadable
        return await finish(.couldNotSanitize(reason), working: cg)
    }

    private func note(_ d: Detections, into record: inout SanitationRecord) {
        record.detectorsUsed = d.used
        record.facesFound = d.faces.count
        record.codesFound = d.codes.count
        record.textLinesFound = d.lines.count
        record.detectionMs = d.elapsedMs
    }
}
