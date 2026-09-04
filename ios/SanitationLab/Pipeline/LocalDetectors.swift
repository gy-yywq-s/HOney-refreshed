//
//  LocalDetectors.swift
//  SanitationLab — the deterministic, on-device half: Apple Vision finds
//  faces, barcodes/QR and text lines with boxes. These give the precise
//  regions; the model never does.
//

import CoreGraphics
import Foundation
import Vision

/// One recognised line of text in pixel coordinates (top-left origin), with a
/// way to ask for the box of a sub-range (Vision gives per-range boxes; the
/// tests give a linear estimate).
struct TextLine {
    var string: String
    var rect: CGRect
    var confidence: Float
    var subrect: (Range<String.Index>) -> CGRect?

    init(string: String, rect: CGRect, confidence: Float = 1, subrect: ((Range<String.Index>) -> CGRect?)? = nil) {
        self.string = string
        self.rect = rect
        self.confidence = confidence
        if let subrect {
            self.subrect = subrect
        } else {
            // Linear estimate: characters share the line's width evenly.
            let s = string, r = rect
            self.subrect = { range in
                let total = max(1, s.count)
                let start = CGFloat(s.distance(from: s.startIndex, to: range.lowerBound))
                let len = CGFloat(s.distance(from: range.lowerBound, to: range.upperBound))
                let unit = r.width / CGFloat(total)
                return CGRect(x: r.minX + start * unit, y: r.minY, width: len * unit, height: r.height)
            }
        }
    }
}

struct CodeDetection: Equatable {
    var rect: CGRect
    var symbology: String
    var payload: String?
}

struct Detections {
    var faces: [CGRect] = []
    var codes: [CodeDetection] = []
    var lines: [TextLine] = []
    var used: [String] = []
    var elapsedMs: Int = 0
}

struct LocalDetectors {
    var recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

    /// Runs the three detectors concurrently, each on its own request handler.
    func detect(_ cg: CGImage) async -> Detections {
        let started = Date()
        async let faces = Self.faces(in: cg)
        async let codes = Self.codes(in: cg)
        async let lines = Self.text(in: cg, languages: recognitionLanguages)
        var d = Detections()
        d.faces = await faces
        d.codes = await codes
        d.lines = await lines
        d.used = ["VNDetectFaceRectanglesRequest", "VNDetectBarcodesRequest", "VNRecognizeTextRequest"]
        d.elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        return d
    }

    // MARK: - Individual detectors (also used by verification)

    static func faces(in cg: CGImage) async -> [CGRect] {
        await Task.detached(priority: .userInitiated) {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).map { pixelRect($0.boundingBox, in: cg) }
        }.value
    }

    static func codes(in cg: CGImage) async -> [CodeDetection] {
        await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).map {
                CodeDetection(rect: pixelRect($0.boundingBox, in: cg), symbology: $0.symbology.rawValue, payload: $0.payloadStringValue)
            }
        }.value
    }

    static func text(in cg: CGImage, languages: [String]) async -> [TextLine] {
        await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = false // numbers must come back as read
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).compactMap { observation -> TextLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let lineRect = pixelRect(observation.boundingBox, in: cg)
                let string = candidate.string
                return TextLine(string: string, rect: lineRect, confidence: candidate.confidence) { range in
                    guard let box = try? candidate.boundingBox(for: range) else { return nil }
                    return pixelRect(box.boundingBox, in: cg)
                }
            }
        }.value
    }

    /// Vision boxes are normalised with a bottom-left origin; the pipeline
    /// works in pixels with a top-left origin.
    static func pixelRect(_ normalized: CGRect, in cg: CGImage) -> CGRect {
        let r = VNImageRectForNormalizedRect(normalized, cg.width, cg.height)
        return CGRect(x: r.minX, y: CGFloat(cg.height) - r.maxY, width: r.width, height: r.height)
    }
}
