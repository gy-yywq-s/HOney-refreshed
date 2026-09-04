//
//  AnalysisDerivative.swift
//  SanitationLab — the small JPEG that goes to the classifier, and the
//  orientation-normalised working bitmap the detectors and the sanitizer use.
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum AnalysisDerivative {
    /// Long edge of the classifier derivative. 768 px was enough for every
    /// bench fixture; the edge caps bodies at 256 KB.
    static let longEdge: CGFloat = 768
    static let byteBudget = 200_000

    /// Redraws the image with `.up` orientation so every pixel coordinate the
    /// pipeline uses matches what the user sees. Drops EXIF on the way.
    static func normalised(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage { return cg }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }

    /// Downscales to `longEdge` and encodes as JPEG, lowering quality until
    /// the bytes fit the budget. Returns the bytes and the scale applied.
    static func make(from cg: CGImage) -> (data: Data, scale: CGFloat)? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let scale = min(1, longEdge / max(w, h))
        let target = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let small = UIGraphicsImageRenderer(size: target, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .high
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: target))
        }
        var quality: CGFloat = 0.72
        while quality >= 0.4 {
            if let data = small.jpegData(compressionQuality: quality) {
                if data.count <= byteBudget { return (data, scale) }
            }
            quality -= 0.08
        }
        return small.jpegData(compressionQuality: 0.4).map { ($0, scale) }
    }

    /// A fresh JPEG of a working bitmap — the "newly encoded" output the spec
    /// requires. Drawn through UIKit so no source metadata survives.
    static func encodeOutput(_ cg: CGImage, quality: CGFloat = 0.9) -> Data? {
        UIImage(cgImage: cg).jpegData(compressionQuality: quality)
    }
}
