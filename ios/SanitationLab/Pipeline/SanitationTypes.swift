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
    /// Credential-like but not safely sanitizable — the original must not be published.
    case couldNotSanitize(CouldNotSanitizeReason)

    var label: String {
        switch self {
        case .clean: return "CLEAN"
        case .sanitized: return "SANITIZED"
        case .couldNotSanitize: return "COULD_NOT_SANITIZE"
        }
    }
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
    var verification: Verification?
    var outcome: String
    var reason: CouldNotSanitizeReason?

    enum Decision: String, Codable {
        case classifierSaidClean
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
}
