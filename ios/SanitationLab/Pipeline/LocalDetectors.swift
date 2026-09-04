//
//  LocalDetectors.swift
//  SanitationLab — the deterministic, on-device half: Apple Vision finds
//  faces, barcodes/QR and text lines with boxes. These give the precise
//  regions; the model never does.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
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
        d.used = ["VNDetectFaceRectanglesRequest[multiscale-enhanced]", "CIDetectorTypeFace", "VNDetectBarcodesRequest", "VNRecognizeTextRequest"]
        d.elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        return d
    }

    // MARK: - Individual detectors (also used by verification)

    static func faces(in cg: CGImage) async -> [CGRect] {
        await Task.detached(priority: .userInitiated) {
            var candidates = visionFaces(in: cg)

            // Low-contrast monochrome/duotone portraits printed as a security
            // watermark are easier to see after local contrast is increased.
            if let enhanced = enhancedForFaces(cg) {
                candidates.append(contentsOf: visionFaces(in: enhanced))
                for tile in faceTiles(in: enhanced) {
                    candidates.append(contentsOf: visionFaces(in: tile.image).map {
                        $0.offsetBy(dx: tile.rect.minX, dy: tile.rect.minY)
                    })
                }
                candidates.append(contentsOf: coreImageFaces(in: enhanced))
            }

            // A small secondary passport portrait may be below the detector's
            // full-image scale. Overlapping tiles make it larger without a
            // separate model or any server round-trip.
            for tile in faceTiles(in: cg) {
                candidates.append(contentsOf: visionFaces(in: tile.image).map {
                    $0.offsetBy(dx: tile.rect.minX, dy: tile.rect.minY)
                })
            }

            // Core Image uses a different face detector and catches some
            // stylised printed portraits Vision misses.
            candidates.append(contentsOf: coreImageFaces(in: cg))
            return deduplicatedFaces(candidates)
        }.value
    }

    private static func visionFaces(in cg: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        return (request.results ?? []).map { pixelRect($0.boundingBox, in: cg) }
    }

    private static func enhancedForFaces(_ cg: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cg)
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.saturation = 0
        controls.contrast = 1.9
        controls.brightness = 0.04
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = controls.outputImage
        sharpen.radius = 2.2
        sharpen.intensity = 0.7
        guard let output = sharpen.outputImage?.cropped(to: input.extent) else { return nil }
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: input.extent)
    }

    private static func faceTiles(in cg: CGImage) -> [(image: CGImage, rect: CGRect)] {
        guard cg.width >= 500, cg.height >= 400 else { return [] }
        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        let tileWidth = width * 0.62, tileHeight = height * 0.62
        let origins = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: width - tileWidth, y: 0),
            CGPoint(x: 0, y: height - tileHeight),
            CGPoint(x: width - tileWidth, y: height - tileHeight),
        ]
        return origins.compactMap { origin in
            let rect = CGRect(origin: origin, size: CGSize(width: tileWidth, height: tileHeight)).integral
            guard let image = cg.cropping(to: rect) else { return nil }
            return (image, rect)
        }
    }

    private static func coreImageFaces(in cg: CGImage) -> [CGRect] {
        guard let detector = CIDetector(
            ofType: CIDetectorTypeFace,
            context: CIContext(options: [.cacheIntermediates: false]),
            options: [
                CIDetectorAccuracy: CIDetectorAccuracyHigh,
                CIDetectorTracking: false,
                CIDetectorMinFeatureSize: 0.01,
                CIDetectorNumberOfAngles: 11,
            ]
        ) else { return [] }
        let height = CGFloat(cg.height)
        return detector.features(in: CIImage(cgImage: cg)).compactMap { feature in
            guard let face = feature as? CIFaceFeature else { return nil }
            return CGRect(x: face.bounds.minX, y: height - face.bounds.maxY, width: face.bounds.width, height: face.bounds.height)
        }
    }

    /// Keeps distinct main/secondary portraits while collapsing detections of
    /// the same face from the original, enhanced, tiled and Core Image passes.
    static func deduplicatedFaces(_ faces: [CGRect]) -> [CGRect] {
        let candidates = faces.filter { $0.width >= 8 && $0.height >= 8 }.sorted { $0.width * $0.height > $1.width * $1.height }
        var kept: [CGRect] = []
        for face in candidates {
            let duplicate = kept.contains { existing in
                let intersection = existing.intersection(face)
                guard !intersection.isNull, !intersection.isEmpty else { return false }
                let overlap = intersection.width * intersection.height
                let smaller = min(existing.width * existing.height, face.width * face.height)
                return smaller > 0 && overlap / smaller >= 0.55
            }
            if !duplicate { kept.append(face) }
        }
        return kept.sorted { lhs, rhs in
            lhs.minY == rhs.minY ? lhs.minX < rhs.minX : lhs.minY < rhs.minY
        }
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
