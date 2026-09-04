//
//  SanitationTypes.swift
//  SanitationLab — the vocabulary of the credential-image pipeline.
//
//  Pure values, no UIKit drawing here: the pipeline reports one of three
//  outcomes (spec §2) and one record per run (spec §11).
//

import CoreGraphics
import Foundation

/// What the image turned out to be. Exactly one of these leaves the pipeline.
enum SanitationOutcome: Equatable {
    /// Not credential-like — the original bytes, untouched.
    case clean
    /// Credential-like and sanitized — a NEW encoding with the regions hidden.
    case sanitized
    /// A best-guess image is available, but the user must review it before use.
    case reviewRequired([ReviewReason])
    /// Credential-like but not safely sanitizable — the original must not be published.
    case couldNotSanitize(CouldNotSanitizeReason)

    var label: String {
        switch self {
        case .clean: return "CLEAN"
        case .sanitized: return "SANITIZED"
        case .reviewRequired: return "REVIEW_REQUIRED"
        case .couldNotSanitize: return "COULD_NOT_SANITIZE"
        }
    }
}

enum ReviewReason: String, Codable, Equatable, CaseIterable {
    /// The remote classifier returned a verdict but marked it uncertain.
    case classifierUncertain
    /// The remote classifier did not return a usable verdict.
    case classifierUnavailable
    /// A sensitive label was seen but its value could not be located confidently.
    case sensitiveDetailNotLocated
    /// The image may be a credential, but no sensitive region was found locally.
    case nothingSensitiveLocated
    /// The best-effort blur still produced a verification warning after retry.
    case verificationIncomplete
    /// Further refinement would exceed the end-to-end latency budget.
    case timeBudgetReached
}

enum CouldNotSanitizeReason: String, Codable, Equatable {
    /// The classifier said credential, the detectors found nothing to hide.
    case nothingLocated
    /// An id label was read (e.g. "学号") but no value could be tied to it.
    case numberNotLocated
    /// After masking (and one wider retry) a barcode/QR still decodes.
    case codeStillReadable
    /// After masking a value string is still recognised by OCR.
    case numberStillReadable
    /// The image could not be decoded or drawn at all.
    case imageUnusable
}

enum RegionKind: String, Codable, CaseIterable {
    case portrait
    case number
    case code
    case personalText
    case signature
}

/// A region to hide, in pixel coordinates of the working image (top-left origin).
struct SensitiveRegion: Codable, Equatable {
    var kind: RegionKind
    var rect: CGRect
    /// For text-bearing regions: the exact string that was hidden, so verification can look for it again.
    var value: String?
    /// For codes: the symbology Vision reported, for the record.
    var detail: String?
}

/// Where the stage machine is, for the UI (spec §7) and for timing.
enum SanitationStage: Equatable {
    case checking
    case processing
    case done(SanitationOutcome)
}

/// The classifier's answer, or its absence.
struct ClassifierAnswer: Codable, Equatable {
    var available: Bool
    var credentialLike: Bool
    var uncertain: Bool
    var latencyMs: Int
    var model: String?
}

/// One run's instrumentation (spec §11). Written next to the before/after
/// JPEGs; also the row the harness prints.
struct SanitationRecord: Codable, Equatable {
    var fixtureId: String?
    var startedAt: Date
    var imageSize: CGSize
    var derivativeBytes: Int
    var classifier: ClassifierAnswer
    /// How the credential decision was actually made.
    var decision: Decision
    var detectorsUsed: [String]
    var facesFound: Int
    var codesFound: Int
    var textLinesFound: Int
    var regions: [SensitiveRegion]
    var classificationMs: Int
    var detectionMs: Int
    var sanitationMs: Int
    /// End-to-end wall time. Optional so older stored records still decode.
    var totalMs: Int? = nil
    var verification: Verification?
    var outcome: String
    var reason: CouldNotSanitizeReason?
    /// Present only for REVIEW_REQUIRED. Optional so older stored records still decode.
    var reviewReasons: [ReviewReason]? = nil

    enum Decision: String, Codable {
        case classifierSaidClean
        /// The classifier said clean, but local face privacy still required sanitation.
        case classifierSaidCleanFacesFound
        /// Deterministic credential signals overrode a clean classifier verdict.
        case localSignalsOverrodeClassifierClean
        case classifierSaidCredential
        /// Classifier down; a local signal (code / id label / long id) decided.
        case localSignalsWithClassifierDown
        /// Classifier down and nothing local fired — treated as clean, recorded.
        case noSignalsWithClassifierDown
    }

    struct Verification: Codable, Equatable {
        var codesStillDecodable: Int
        var valuesStillReadable: [String]
        var retriedWider: Bool
    }

    var regionCounts: [RegionKind: Int] {
        Dictionary(grouping: regions, by: \.kind).mapValues(\.count)
    }


    var requiresUserConfirmation: Bool {
        !(reviewReasons ?? []).isEmpty
    }
}
