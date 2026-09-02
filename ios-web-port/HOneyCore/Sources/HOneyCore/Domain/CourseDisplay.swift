// Human display of the school portal's raw labels (Web: lib/displayNames.ts).
// A portal course string such as
//   "CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅"
// is one administrative concatenation — subject, term + class code + class
// type, teacher — with no separators. The domain keeps the raw string (it is
// the identity the portal uses); presentation splits it ONCE here into a
// title and secondary metadata. Deterministic: nothing is invented.

import Foundation

public struct CourseDisplay: Sendable, Equatable {
    /// "CIE Chinese Language & Literature"
    public let title: String
    /// "2026 Autumn · 中文备考班 · 赵流畅" — empty when the raw name had no term token.
    public let meta: String
}

public enum DisplayNames {
    private static let seasons: [Character: String] = ["春": "Spring", "夏": "Summer", "秋": "Autumn", "冬": "Winter"]
    private static let term = #/^(20\d\d)年?([春夏秋冬])/#
    private static let cjkRun = #/[㐀-鿿][㐀-鿿0-9A-Za-z]*班?/#
    private static let leadingAlnum = #/^[0-9A-Za-z]+/#

    public static func parseCourseName(_ raw: String, teacherName: String? = nil) -> CourseDisplay {
        let tokens = raw.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let termAt = tokens.firstIndex(where: { $0.firstMatch(of: term) != nil }), termAt > 0 else {
            return CourseDisplay(title: raw.trimmingCharacters(in: .whitespaces), meta: "")
        }
        let title = tokens[..<termAt].joined(separator: " ")
        var rest = Array(tokens[termAt...])
        let match = rest[0].firstMatch(of: term)!
        let season = match.output.2.first.flatMap { seasons[$0] } ?? String(match.output.2)
        let termLabel = "\(match.output.1) \(season)"
        // The teacher is the last token when it matches the known name, or
        // when it carries no digits and is not the term token itself.
        var teacher = ""
        if rest.count > 1, let last = rest.last, last == teacherName || !last.contains(where: { $0.isNumber }) {
            teacher = last
            rest.removeLast()
        }
        // Class type: the CJK run(s) after the season, e.g. 中文备考班 / 强化班 / 活动课.
        let afterSeason = ([String(rest[0][match.range.upperBound...])] + rest.dropFirst()).joined(separator: " ")
        let runs = afterSeason.matches(of: cjkRun).map { String($0.output) }
        let classType = runs
            .map { $0.replacing(leadingAlnum, with: "") }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let meta = [termLabel, classType, teacher].filter { !$0.isEmpty }.joined(separator: " · ")
        return CourseDisplay(title: title, meta: meta)
    }

    /// The human title of a course entity name; other entity types pass through.
    public static func entityTitle(type: EntityType, name: String) -> String {
        type == .course ? parseCourseName(name).title : name
    }

    /// Secondary line for a course entity; empty for everything else.
    public static func entityMeta(type: EntityType, name: String) -> String {
        type == .course ? parseCourseName(name).meta : ""
    }

    /// "Room 309" — a bare room number gets the word; a named place keeps its name.
    public static func roomLabel(_ room: String?) -> String {
        guard let room, !room.isEmpty else { return "" }
        let trimmed = room.trimmingCharacters(in: .whitespaces)
        return trimmed.wholeMatch(of: #/[0-9]+[A-Za-z]?/#) != nil ? "Room \(trimmed)" : room
    }

    private static let boardWords = #/^(?i:Edexcel|CIE|Cambridge|AQA|OCR|IGCSE|GCSE|IAL|IB|AP)\b\s*/#
    private static let unitSuffix = #/[-\s](?i:U\d+|A[12]|AS|P\d+|L\d+|Y\d+)$/#
    private static let hyphenQualifier = #/^([A-Za-z]{3,8})-([A-Za-z].*)$/#

    /// The subject as a Week-matrix cell reads it: a stable, meaningful short
    /// form — never initials invented from every capital.
    /// "Edexcel Economics-U4" → "Economics"; "CIE Chinese Language & Literature"
    /// → "Chinese"; "IELTS-Speaking" → "IELTS"; "CIE Physics-A2" → "Physics".
    public static func compactSubjectName(_ subject: String) -> String {
        var s = subject.trimmingCharacters(in: .whitespaces)
            .replacing(boardWords, with: "")
            .replacing(unitSuffix, with: "")
            .trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return subject.trimmingCharacters(in: .whitespaces) }
        if let hy = s.wholeMatch(of: hyphenQualifier) { s = String(hy.output.1) }
        if s.count <= 16 { return s }
        let head = s.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? s
        return head.count >= 4 ? head : s
    }

    private static let short: [String: String] = [
        "Economics": "Econ", "Mathematics": "Maths", "Chemistry": "Chem", "Geography": "Geog",
        "Literature": "Lit", "Psychology": "Psych", "Computing": "Comp", "Business": "Bus",
        "Accounting": "Acc", "Sociology": "Soc", "Philosophy": "Phil", "Statistics": "Stats",
    ]

    /// The narrowest tier for phone columns: a curated map, never initials;
    /// anything unmapped keeps its compact name.
    public static func shortSubjectName(_ subject: String, maxChars: Int = 8) -> String {
        let compact = compactSubjectName(subject)
        if compact.count <= maxChars { return compact }
        return short[compact] ?? compact
    }
}
