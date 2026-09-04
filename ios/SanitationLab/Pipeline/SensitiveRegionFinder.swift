//
//  SensitiveRegionFinder.swift
//  SanitationLab — turns detections into the regions a credential must lose
//  (spec §3, §5): portrait, credential number, barcode/QR. Nothing else —
//  names, school, class, dates stay.
//
//  Pure: takes rectangles and strings, returns rectangles. Unit-tested
//  without Vision.
//

import CoreGraphics
import Foundation

struct RegionFinderInput {
    var faces: [CGRect]
    var codes: [CodeDetection]
    var lines: [TextLine]
    var imageSize: CGSize
}

struct RegionFinderResult: Equatable {
    var regions: [SensitiveRegion]
    /// An id label was read but no value could be tied to it (→ COULD_NOT_SANITIZE).
    var labelWithoutValue: Bool
    var labelsSeen: [String]
    /// A local signal strong enough to call the image credential-like on its own.
    var strongSignal: Bool { labelsSeen.isEmpty == false || regions.contains { $0.kind == .code } }
}

enum SensitiveRegionFinder {
    // The labels the spec names, plus the obvious siblings seen on real cards.
    private static let labelPattern =
        #"(student\s*(id|no\.?|number)|id\s*(no\.?|number)|card\s*(no\.?|number)|staff\s*(no\.?|number)|reader\s*(no\.?|number)|member\s*(no\.?|number)|学生\s*id|学号|學號|编号|編號|证件号|證件號|卡号|卡號|工号|工號|借书证号|證號|证号)"#
    private static let labelRegex = try! NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive])
    /// Label, optional separator, then a value token: letters/digits/dashes, 3+ chars.
    private static let labelledValueRegex = try! NSRegularExpression(
        pattern: labelPattern + #"\s*[:：.．]?\s*([A-Za-z0-9][A-Za-z0-9\-]{2,})"#, options: [.caseInsensitive])
    private static let digitRun = try! NSRegularExpression(pattern: #"\d{5,}"#)
    private static let tokenRegex = try! NSRegularExpression(pattern: #"[A-Za-z0-9][A-Za-z0-9\-]*"#)

    /// Padding around what was found, so masks cover anti-aliasing and quiet zones.
    static let portraitPad: CGFloat = 0.10
    static let codePad: CGFloat = 0.12
    static let numberPad: CGFloat = 0.18

    /// `credentialLike` gates the layout-association rules (standalone long
    /// ids, faces). Codes and labelled values are reported regardless, so a
    /// caller with the classifier down can still see the strong signals.
    static func find(_ input: RegionFinderInput, credentialLike: Bool) -> RegionFinderResult {
        var regions: [SensitiveRegion] = []
        var labelsSeen: [String] = []
        var labelWithoutValue = false
        let bounds = CGRect(origin: .zero, size: input.imageSize)

        // 1. Codes: always sensitive on a credential; always a strong signal.
        for code in input.codes {
            regions.append(SensitiveRegion(kind: .code, rect: pad(code.rect, by: codePad, in: bounds), value: code.payload, detail: code.symbology))
        }

        // 2. Labelled numbers.
        var consumedLines = Set<Int>()
        for (i, line) in input.lines.enumerated() {
            let ns = line.string as NSString
            let whole = NSRange(location: 0, length: ns.length)
            guard let labelMatch = labelRegex.firstMatch(in: line.string, options: [], range: whole) else { continue }
            labelsSeen.append(ns.substring(with: labelMatch.range))
            if let m = labelledValueRegex.firstMatch(in: line.string, options: [], range: whole), m.numberOfRanges >= 2 {
                let valueRange = m.range(at: m.numberOfRanges - 1)
                let value = ns.substring(with: valueRange)
                if value.contains(where: \.isNumber), let range = Range(valueRange, in: line.string) {
                    let rect = line.subrect(range) ?? line.rect
                    regions.append(SensitiveRegion(kind: .number, rect: pad(rect, by: numberPad, in: bounds), value: value, detail: "labelled"))
                    consumedLines.insert(i)
                    continue
                }
            }
            // Label without a value on its line: the id-like line to the right or just below.
            if let j = nearestIdLikeLine(to: line, in: input.lines, excluding: consumedLines.union([i])) {
                let other = input.lines[j]
                regions.append(SensitiveRegion(kind: .number, rect: pad(other.rect, by: numberPad, in: bounds), value: other.string, detail: "label-adjacent"))
                consumedLines.insert(j)
                consumedLines.insert(i)
            } else {
                labelWithoutValue = true
            }
        }

        guard credentialLike else {
            return RegionFinderResult(regions: regions, labelWithoutValue: labelWithoutValue, labelsSeen: labelsSeen)
        }

        // 3. Standalone long identifiers — only when the layout is a credential.
        for (i, line) in input.lines.enumerated() where !consumedLines.contains(i) {
            let ns = line.string as NSString
            for m in tokenRegex.matches(in: line.string, options: [], range: NSRange(location: 0, length: ns.length)) {
                let token = ns.substring(with: m.range)
                guard isIdLike(token), let range = Range(m.range, in: line.string) else { continue }
                let rect = line.subrect(range) ?? line.rect
                regions.append(SensitiveRegion(kind: .number, rect: pad(rect, by: numberPad, in: bounds), value: token, detail: "standalone"))
            }
        }

        // 4. Portrait: every face on a credential image, widened to the photo
        //    frame a card portrait sits in (head plus shoulders), not just the face.
        for face in input.faces {
            regions.append(SensitiveRegion(kind: .portrait, rect: portraitFrame(around: face, in: bounds), value: nil, detail: nil))
        }

        return RegionFinderResult(regions: regions, labelWithoutValue: labelWithoutValue, labelsSeen: labelsSeen)
    }

    /// Five digits in a row, or eight+ alphanumerics carrying four+ digits.
    static func isIdLike(_ token: String) -> Bool {
        let ns = token as NSString
        if digitRun.firstMatch(in: token, options: [], range: NSRange(location: 0, length: ns.length)) != nil { return true }
        let alnum = token.filter { $0.isLetter || $0.isNumber }.count
        let digits = token.filter(\.isNumber).count
        return alnum >= 8 && digits >= 4
    }

    private static func nearestIdLikeLine(to label: TextLine, in lines: [TextLine], excluding: Set<Int>) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (j, other) in lines.enumerated() where !excluding.contains(j) {
            guard isIdLike(other.string) else { continue }
            let sameRow = abs(other.rect.midY - label.rect.midY) < label.rect.height * 0.7 && other.rect.minX >= label.rect.minX
            let below = other.rect.minY > label.rect.midY && other.rect.minY - label.rect.maxY < label.rect.height * 1.5
                && other.rect.maxX > label.rect.minX && other.rect.minX < label.rect.maxX + label.rect.width
            guard sameRow || below else { continue }
            let distance = hypot(other.rect.midX - label.rect.midX, other.rect.midY - label.rect.midY)
            if best == nil || distance < best!.distance { best = (j, distance) }
        }
        return best?.index
    }

    /// Vision returns the face; an ID photo is roughly 1.8 faces wide and runs
    /// from above the hair to below the shoulders. Blurring that frame hides
    /// the portrait rather than a square in its middle.
    static func portraitFrame(around face: CGRect, in bounds: CGRect) -> CGRect {
        let frame = CGRect(x: face.midX - face.width * 0.9, y: face.minY - face.height * 0.6, width: face.width * 1.8, height: face.height * 2.8)
        return frame.union(pad(face, by: portraitPad, in: bounds)).intersection(bounds)
    }

    static func pad(_ rect: CGRect, by fraction: CGFloat, in bounds: CGRect) -> CGRect {
        let dx = rect.width * fraction, dy = rect.height * fraction
        return rect.insetBy(dx: -dx, dy: -dy).intersection(bounds)
    }
}
