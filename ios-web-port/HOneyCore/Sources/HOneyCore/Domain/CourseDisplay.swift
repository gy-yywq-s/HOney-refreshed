// Display helpers for canonical names (Web: lib/displayNames.ts). Domain
// meaning is settled at the import boundary on the backend (canonical
// Course "AL ECON U4", section "2026 Autumn · Prep Class", teacher, room);
// nothing here corrects a name — these helpers only abbreviate and typeset
// for narrow places.

import Foundation

public enum DisplayNames {
    /// The lesson's title: the canonical Course students mean ("AL ECON U4"), else its Subject.
    public static func lessonTitle(courseName: String?, subjectName: String) -> String {
        courseName ?? subjectName
    }

    public static func lessonTitle(_ lesson: Lesson) -> String {
        lessonTitle(courseName: lesson.courseName, subjectName: lesson.subjectName)
    }

    private static let levelPrefix = #/^(AL|AS|A2|IGCSE|GCSE|IB|AP)\s+/#

    /// Week-matrix cell form of the title: a course code drops its level ("ECON U4"); a subject compacts.
    public static func compactLessonTitle(courseName: String?, subjectName: String, phone: Bool = false) -> String {
        if let courseName {
            let code = courseName.replacing(levelPrefix, with: "").trimmingCharacters(in: .whitespaces)
            return phone && code.count > 8 ? shortSubjectName(code) : code
        }
        return phone ? shortSubjectName(subjectName) : compactSubjectName(subjectName)
    }

    public static func compactLessonTitle(_ lesson: Lesson, phone: Bool = false) -> String {
        compactLessonTitle(courseName: lesson.courseName, subjectName: lesson.subjectName, phone: phone)
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
