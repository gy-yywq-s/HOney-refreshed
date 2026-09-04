//
//  Sanitizer.swift
//  SanitationLab — hides the regions on a COPY and checks its own work.
//
//  Every sensitive region → the same strong, rounded Gaussian blur.
//  Verification re-runs the detectors on the output:
//  a code that still decodes or a value that still reads back is a failure.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum Sanitizer {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Draws the working image with every region hidden. `grow` inflates the
    /// regions (fraction of their size) for the wider retry.
    static func sanitize(_ cg: CGImage, regions: [SensitiveRegion], grow: CGFloat = 0) -> CGImage? {
        let size = CGSize(width: cg.width, height: cg.height)
        let bounds = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        var blurFailed = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: bounds)
            for region in regions {
                let rect = (grow > 0 ? SensitiveRegionFinder.pad(region.rect, by: grow, in: bounds) : region.rect).integral.intersection(bounds)
                guard !rect.isEmpty else { continue }
                guard let blurred = blurredCrop(of: cg, rect: rect) else {
                    blurFailed = true
                    continue
                }
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius(for: rect)).addClip()
                UIImage(cgImage: blurred).draw(in: rect)
                ctx.cgContext.restoreGState()
            }
        }
        return blurFailed ? nil : image.cgImage
    }

    /// Gaussian blur strong enough for thin text as well as large portraits
    /// and codes, while retaining the visual texture beneath the redaction.
    private static func blurredCrop(of cg: CGImage, rect: CGRect) -> CGImage? {
        guard let crop = cg.cropping(to: rect) else { return nil }
        let input = CIImage(cgImage: crop)
        let radius = max(28, min(72, min(rect.width, rect.height) * 0.38))
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input.clampedToExtent()
        filter.radius = Float(radius)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }

    static func cornerRadius(for rect: CGRect) -> CGFloat {
        max(7, min(24, min(rect.width, rect.height) * 0.22))
    }

    /// Re-detects on the output. Returns what is still readable.
    static func verify(_ output: CGImage, regions: [SensitiveRegion], languages: [String]) async -> SanitationRecord.Verification {
        async let codes = LocalDetectors.codes(in: output)
        async let lines = LocalDetectors.text(in: output, languages: languages)
        let decodable = await codes.count
        let recognised = await lines
        let values = valuesStillReadable(in: recognised, regions: regions)
        return SanitationRecord.Verification(codesStillDecodable: decodable, valuesStillReadable: values, retriedWider: false)
    }

    /// A repeated word elsewhere on a credential is not evidence that the
    /// blurred field leaked. Count it only when the recognised text overlaps
    /// that field's own region.
    static func valuesStillReadable(in lines: [TextLine], regions: [SensitiveRegion]) -> [String] {
        let values = regions.compactMap { region -> String? in
            guard region.kind != .portrait, region.kind != .code, let value = region.value else { return nil }
            let key = normalise(value)
            guard key.count >= 4 else { return nil }
            return lines.contains { line in
                line.rect.intersects(region.rect) && normalise(line.string).contains(key)
            } ? value : nil
        }
        return values
    }

    /// Digits and letters only, lowercased — OCR spacing/dash differences must not hide a leak.
    static func normalise(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
