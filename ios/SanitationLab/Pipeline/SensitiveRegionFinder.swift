//
//  SensitiveRegionFinder.swift
//  SanitationLab — turns detections into the regions a credential must lose
//  (spec §3, §5): portraits, credential numbers, codes, signatures and
//  labelled personal details. Names, school, class and validity stay.
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
    /// A sensitive label was read but no value could be tied to it (→ COULD_NOT_SANITIZE).
    var labelWithoutValue: Bool
    var labelsSeen: [String]
    /// A local signal strong enough to call the image credential-like on its own.
    var strongSignal: Bool { labelsSeen.isEmpty == false || regions.contains { $0.kind == .code || $0.kind == .portrait } }
}

enum SensitiveRegionFinder {
    // Credential-number labels, including passport/document/residence-card siblings.
    private static let labelPattern =
        #"(student\s*(id|no\.?|number)|id\s*(no\.?|number)|card\s*(no\.?|number)|staff\s*(no\.?|number)|reader\s*(no\.?|number)|member\s*(no\.?|number)|passport\s*(no\.?|number)|document\s*(no\.?|number)|licen[cs]e\s*(no\.?|number)|permit\s*(no\.?|number)|personal\s*(no\.?|number)|registration\s*(no\.?|number)|学生\s*id|学号|學號|编号|編號|证件号|證件號|卡号|卡號|工号|工號|借书证号|護照號碼|护照号码|居留證號|居留证号|證號|证号)"#
    private static let labelRegex = try! NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive])
    /// Label, optional separator, then a value token: letters/digits/dashes, 3+ chars.
    private static let labelledValueRegex = try! NSRegularExpression(
        pattern: labelPattern + #"\s*[:：.．]?\s*([A-Za-z0-9][A-Za-z0-9\-]{2,})"#, options: [.caseInsensitive])
    private static let digitRun = try! NSRegularExpression(pattern: #"\d{5,}"#)
    private static let tokenRegex = try! NSRegularExpression(pattern: #"[A-Za-z0-9][A-Za-z0-9\-]*"#)
    private static let personalLabelPattern =
        #"(residential\s+address|home\s+address|mailing\s+address|address|residence|domicile|place\s+of\s+birth|date\s+of\s+birth|birth\s+date|d\.?o\.?b\.?|nationality|citizenship|sex|gender|phone|mobile|telephone|tel\.?|e-?mail|guardian|parent|emergency\s+contact|blood\s*(type|group)|住址|地址|住所|居住地址|户籍地址|戶籍地址|通讯地址|通訊地址|出生日期|出生年月日|出生地|出生地点|出生地點|国籍|國籍|性别|性別|电话|電話|手机|手機|邮箱|郵箱|电邮|電郵|监护人|監護人|家长|家長|紧急联系人|緊急聯絡人|血型)"#
    private static let personalLabelRegex = try! NSRegularExpression(pattern: personalLabelPattern, options: [.caseInsensitive])
    private static let addressLabelRegex = try! NSRegularExpression(
        pattern: #"(residential\s+address|home\s+address|mailing\s+address|address|residence|domicile|住址|地址|住所|居住地址|户籍地址|戶籍地址|通讯地址|通訊地址)"#,
        options: [.caseInsensitive])
    private static let signatureRegex = try! NSRegularExpression(
        pattern: #"(holder'?s\s+signature|signature|signed|签名|簽名|持证人签名|持證人簽名)"#,
        options: [.caseInsensitive])
    private static let knownFieldRegex = try! NSRegularExpression(
        pattern: labelPattern + "|" + personalLabelPattern + #"|(name|surname|given\s+names?|valid|expiry|expires|issued?|school|class|姓名|姓氏|名字|有效|签发|簽發|学校|學校|班级|班級)"#,
        options: [.caseInsensitive])

    /// Padding around what was found, so masks cover anti-aliasing and quiet zones.
    static let portraitPad: CGFloat = 0.30
    static let codePad: CGFloat = 0.12
    static let numberPad: CGFloat = 0.18

    /// `credentialLike` gates standalone long ids and credential-only
    /// personal-field expansion. Faces are always privacy-sensitive. Codes
    /// and labelled values are reported regardless, so a caller with the
    /// classifier down can still see the strong signals.
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

        // 3. Labelled personal details. Unlike credential numbers, these may
        // contain spaces and punctuation. Keep the printed label when Vision
        // gives a separable value; otherwise use the nearest value line.
        for (i, line) in input.lines.enumerated() where !consumedLines.contains(i) {
            let ns = line.string as NSString
            let whole = NSRange(location: 0, length: ns.length)
            guard let labelMatch = personalLabelRegex.firstMatch(in: line.string, options: [], range: whole) else { continue }
            labelsSeen.append(ns.substring(with: labelMatch.range))

            if let value = valueAfter(labelMatch, in: line) {
                regions.append(SensitiveRegion(kind: .personalText, rect: pad(value.rect, by: numberPad, in: bounds), value: value.text, detail: "labelled-personal"))
                consumedLines.insert(i)
                if addressLabelRegex.firstMatch(in: line.string, options: [], range: whole) != nil {
                    for j in addressContinuationLines(after: line, valueRect: value.rect, in: input.lines, excluding: consumedLines) {
                        let continuation = input.lines[j]
                        regions.append(SensitiveRegion(kind: .personalText, rect: pad(continuation.rect, by: numberPad, in: bounds), value: continuation.string, detail: "address-continuation"))
                        consumedLines.insert(j)
                    }
                }
                continue
            }

            if let j = nearestPersonalValueLine(to: line, in: input.lines, excluding: consumedLines.union([i])) {
                let other = input.lines[j]
                regions.append(SensitiveRegion(kind: .personalText, rect: pad(other.rect, by: numberPad, in: bounds), value: other.string, detail: "label-adjacent-personal"))
                consumedLines.insert(i)
                consumedLines.insert(j)
                if addressLabelRegex.firstMatch(in: line.string, options: [], range: whole) != nil {
                    for k in addressContinuationLines(after: other, valueRect: other.rect, in: input.lines, excluding: consumedLines) {
                        let continuation = input.lines[k]
                        regions.append(SensitiveRegion(kind: .personalText, rect: pad(continuation.rect, by: numberPad, in: bounds), value: continuation.string, detail: "address-continuation"))
                        consumedLines.insert(k)
                    }
                }
            } else {
                labelWithoutValue = true
            }
        }

        // Signatures are often graphics rather than OCR text. A recognised
        // signature label therefore protects the nearby signature area even
        // when no value string can be read.
        for (i, line) in input.lines.enumerated() where !consumedLines.contains(i) {
            let whole = NSRange(location: 0, length: (line.string as NSString).length)
            guard signatureRegex.firstMatch(in: line.string, options: [], range: whole) != nil else { continue }
            labelsSeen.append(line.string)
            regions.append(SensitiveRegion(kind: .signature, rect: signatureFrame(around: line.rect, in: bounds), value: nil, detail: "labelled-signature"))
            consumedLines.insert(i)
        }

        // Every detected face is private, whether or not the image is a
        // credential. This also covers ordinary photos and classifier misses.
        for face in input.faces {
            regions.append(SensitiveRegion(kind: .portrait, rect: portraitFrame(around: face, in: bounds), value: nil, detail: nil))
        }

        guard credentialLike else {
            return RegionFinderResult(regions: regions, labelWithoutValue: labelWithoutValue, labelsSeen: labelsSeen)
        }

        // 4. Standalone long identifiers and MRZ lines — only when the layout is a credential.
        for (i, line) in input.lines.enumerated() where !consumedLines.contains(i) {
            if isMRZ(line.string) {
                regions.append(SensitiveRegion(kind: .personalText, rect: pad(line.rect, by: numberPad, in: bounds), value: line.string, detail: "mrz"))
                consumedLines.insert(i)
                continue
            }
            let ns = line.string as NSString
            for m in tokenRegex.matches(in: line.string, options: [], range: NSRange(location: 0, length: ns.length)) {
                let token = ns.substring(with: m.range)
                guard isIdLike(token), let range = Range(m.range, in: line.string) else { continue }
                let rect = line.subrect(range) ?? line.rect
                regions.append(SensitiveRegion(kind: .number, rect: pad(rect, by: numberPad, in: bounds), value: token, detail: "standalone"))
            }
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

    /// Machine-readable-zone lines are long, dense and usually contain '<'.
    static func isMRZ(_ text: String) -> Bool {
        let compact = text.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "<" }
        return compact.count >= 20 && compact.filter { $0 == "<" }.count >= 2
    }

    private static func valueAfter(_ match: NSTextCheckingResult, in line: TextLine) -> (text: String, rect: CGRect)? {
        let ns = line.string as NSString
        var location = match.range.location + match.range.length
        while location < ns.length {
            let scalar = ns.substring(with: NSRange(location: location, length: 1))
            if scalar.range(of: #"[\s:：.．/|-]"#, options: .regularExpression) == nil { break }
            location += 1
        }
        guard location < ns.length else { return nil }
        let range = NSRange(location: location, length: ns.length - location)
        let text = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.contains(where: { $0.isLetter || $0.isNumber }), let swiftRange = Range(range, in: line.string) else { return nil }
        return (text, line.subrect(swiftRange) ?? line.rect)
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

    private static func nearestPersonalValueLine(to label: TextLine, in lines: [TextLine], excluding: Set<Int>) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (j, other) in lines.enumerated() where !excluding.contains(j) {
            let trimmed = other.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            let whole = NSRange(location: 0, length: (trimmed as NSString).length)
            guard knownFieldRegex.firstMatch(in: trimmed, options: [], range: whole) == nil else { continue }
            let sameRow = abs(other.rect.midY - label.rect.midY) < label.rect.height * 0.8 && other.rect.minX >= label.rect.midX
            let below = other.rect.minY >= label.rect.maxY - label.rect.height * 0.2
                && other.rect.minY - label.rect.maxY < label.rect.height * 1.8
                && abs(other.rect.minX - label.rect.minX) < max(label.rect.width, other.rect.height * 3)
            guard sameRow || below else { continue }
            let distance = hypot(other.rect.midX - label.rect.midX, other.rect.midY - label.rect.midY)
            if best == nil || distance < best!.distance { best = (j, distance) }
        }
        return best?.index
    }

    private static func addressContinuationLines(after line: TextLine, valueRect: CGRect, in lines: [TextLine], excluding: Set<Int>) -> [Int] {
        var result: [Int] = []
        var previous = line.rect
        for _ in 0..<2 {
            let candidate = lines.enumerated().filter { j, other in
                guard !excluding.contains(j), !result.contains(j), other.rect.minY >= previous.maxY - previous.height * 0.2 else { return false }
                let gap = other.rect.minY - previous.maxY
                guard gap < max(previous.height, other.rect.height) * 1.4 else { return false }
                guard abs(other.rect.minX - valueRect.minX) < max(valueRect.height * 3, valueRect.width * 0.25) else { return false }
                let whole = NSRange(location: 0, length: (other.string as NSString).length)
                return knownFieldRegex.firstMatch(in: other.string, options: [], range: whole) == nil
            }.min { $0.element.rect.minY < $1.element.rect.minY }
            guard let candidate else { break }
            result.append(candidate.offset)
            previous = candidate.element.rect
        }
        return result
    }

    static func signatureFrame(around label: CGRect, in bounds: CGRect) -> CGRect {
        let width = max(label.width * 3, bounds.width * 0.35)
        let frame = CGRect(x: label.minX, y: label.minY - label.height * 3, width: width, height: label.height * 4.2)
        return frame.intersection(bounds)
    }

    /// Blur the face, hairline and immediate surround without allowing the
    /// portrait region to expand into adjacent text columns.
    static func portraitFrame(around face: CGRect, in bounds: CGRect) -> CGRect {
        pad(face, by: portraitPad, in: bounds)
    }

    static func pad(_ rect: CGRect, by fraction: CGFloat, in bounds: CGRect) -> CGRect {
        let dx = rect.width * fraction, dy = rect.height * fraction
        return rect.insetBy(dx: -dx, dy: -dy).intersection(bounds)
    }
}
