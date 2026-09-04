//
//  Sanitizer.swift
//  SanitationLab — hides the regions on a COPY and checks its own work.
//
//  Portrait → strong Gaussian blur scaled to the face; number and code →
//  opaque neutral mask. Verification re-runs the detectors on the output:
//  a code that still decodes or a value that still reads back is a failure.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum Sanitizer {
    static let maskColor = UIColor(white: 0.55, alpha: 1)
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Draws the working image with every region hidden. `grow` inflates the
    /// regions (fraction of their size) for the wider retry.
    static func sanitize(_ cg: CGImage, regions: [SensitiveRegion], grow: CGFloat = 0) -> CGImage? {
        let size = CGSize(width: cg.width, height: cg.height)
        let bounds = CGRect(origin: .zero, size: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: bounds)
            for region in regions {
                let rect = (grow > 0 ? SensitiveRegionFinder.pad(region.rect, by: grow, in: bounds) : region.rect).integral.intersection(bounds)
                guard !rect.isEmpty else { continue }
                switch region.kind {
                case .portrait:
                    if let blurred = blurredCrop(of: cg, rect: rect) {
                        UIImage(cgImage: blurred).draw(in: rect)
                    } else {
                        maskColor.setFill()
                        ctx.fill(rect)
                    }
                case .number, .code, .personalText, .signature:
                    maskColor.setFill()
                    ctx.fill(rect)
                }
            }
        }
        return image.cgImage
    }

    /// Gaussian blur of one region, strong enough that the face is gone at any
    /// zoom (radius grows with the region) but the area still reads as "a photo".
    private static func blurredCrop(of cg: CGImage, rect: CGRect) -> CGImage? {
        guard let crop = cg.cropping(to: rect) else { return nil }
        let input = CIImage(cgImage: crop)
        let radius = max(14, rect.width / 6)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input.clampedToExtent()
        filter.radius = Float(radius)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }

    /// Re-detects on the output. Returns what is still readable.
    static func verify(_ output: CGImage, regions: [SensitiveRegion], languages: [String]) async -> SanitationRecord.Verification {
        async let codes = LocalDetectors.codes(in: output)
        async let lines = LocalDetectors.text(in: output, languages: languages)
        let decodable = await codes.count
        let read = await lines.map { normalise($0.string) }
        let values = regions.compactMap { region -> String? in
            guard region.kind != .portrait, region.kind != .code, let value = region.value else { return nil }
            let key = normalise(value)
            guard key.count >= 4 else { return nil }
            return read.contains { $0.contains(key) } ? value : nil
        }
        return SanitationRecord.Verification(codesStillDecodable: decodable, valuesStillReadable: values, retriedWider: false)
    }

    /// Digits and letters only, lowercased — OCR spacing/dash differences must not hide a leak.
    static func normalise(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
