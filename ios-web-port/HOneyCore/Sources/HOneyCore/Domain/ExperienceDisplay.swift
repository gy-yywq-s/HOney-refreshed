// How one post reads (Web: features/experiences/ExperiencePost.tsx +
// pages/experiences/shared.tsx): context line → provenance · day → the
// student's own words at the largest weight → reactions · overflow. No
// avatars, no anonymous badges, no verification shields.

import Foundation

public enum ExperienceDisplay {
    /// ~8–12 lines before "Read more".
    public static let clampChars = 700
    /// At/below this, the words set larger.
    public static let featureChars = 180

    /// "Further Mathematics · Ms Lin" — course first, then teacher, then the
    /// primary (unless it is the lesson), then the room; deduplicated.
    public static func contextParts(_ exp: PublicExperience) -> [EntitySummary] {
        var parts: [EntitySummary] = []
        var seen = Set<String>()
        func push(_ e: EntitySummary?) {
            guard let e, let name = e.name, !name.isEmpty else { return }
            let key = "\(e.type.rawValue):\(e.id)"
            guard !seen.contains(key) else { return }
            seen.insert(key)
            parts.append(e)
        }
        push(exp.contexts?.first { $0.type == .course })
        push(exp.contexts?.first { $0.type == .teacher })
        if let primary = exp.primary, primary.type != .lesson { push(primary) }
        push(exp.contexts?.first { $0.type == .room })
        return parts
    }

    /// The Home preview caption: course · teacher (or the non-lesson primary) · day.
    public static func previewCaption(_ exp: PublicExperience) -> String {
        let course = exp.contexts?.first { $0.type == .course }?.name
        let teacher = exp.contexts?.first { $0.type == .teacher }?.name
            ?? (exp.primary?.type != .lesson ? exp.primary?.name : nil)
        var text = [course, teacher].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        if let day = exp.publishedDay {
            text += text.isEmpty ? Formatters.dayBucket(day) : " · \(Formatters.dayBucket(day))"
        }
        return text
    }

    /// One register for provenance everywhere (stream line and Mine chip).
    public static func provenanceLine(_ p: ExperienceProvenance) -> String {
        switch p {
        case .verifiedLesson: return "from a class you’ve taken"
        case .verifiedRetrospective: return "from someone who has taken this over time"
        case .verifiedMember, .unknown: return "from a student here"
        }
    }

    public static func provenanceLabel(_ p: ExperienceProvenance) -> String {
        switch p {
        case .unknown: return "Verified school member"
        default: return provenanceLine(p)
        }
    }

    /// The provenance · day line under the context.
    public static func provenanceText(_ exp: PublicExperience) -> String {
        var text = provenanceLine(exp.provenance)
        if let day = exp.publishedDay { text += " · \(Formatters.dayBucket(day))" }
        return text
    }

    public static func isFeature(_ body: String) -> Bool { body.count <= featureChars }

    /// The clamped body (cut at a word boundary + "…") or the full text.
    public static func clampedBody(_ body: String, expanded: Bool) -> (text: String, clamped: Bool) {
        guard !expanded, body.count > clampChars else { return (body, false) }
        var cut = String(body.prefix(clampChars))
        if let match = cut.firstMatch(of: #/\s+\S*$/#) { cut.removeSubrange(match.range) }
        return (cut + "…", true)
    }

    /// Deep-link route for a named context; lessons have no public page.
    public static func route(for summary: EntitySummary) -> AppRoute? {
        switch summary.type {
        case .teacher: return .entity(.teacher, summary.id)
        case .course: return .entity(.course, summary.id)
        case .room: return .entity(.room, summary.id)
        case .dish: return .entity(.dish, summary.id)
        case .lesson, .unknown: return nil
        }
    }

    public static func route(for entity: EntityRef) -> AppRoute? {
        guard let colon = entity.entityKey.firstIndex(of: ":") else { return nil }
        let id = String(entity.entityKey[entity.entityKey.index(after: colon)...])
        switch entity.type {
        case .teacher, .course, .room, .dish: return .entity(entity.type, id)
        case .unknown: return nil
        }
    }

    public static let reactionExplainer =
        "Reactions show whether this matches the experience of students who have had the same class or place. They do not verify a post as fact."

    /// Category-only reporting; disagreement is a reaction, not a report.
    public static let reportOptions: [(category: ReportCategory, label: String)] = [
        (.doxxing, "Private or identifying information"),
        (.slur, "Targeted abuse or a slur"),
        (.targetsStudent, "It is about a student"),
        (.seriousAllegation, "A serious matter that should not be in the feed"),
        (.notExperience, "Rumor, spam, or not a real experience"),
        (.otherRule, "Another community-rule problem"),
    ]

    public static func reactionFailureNote(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api.code {
            case "reactions_disabled": return "Reactions are paused right now."
            case "not_eligible": return "Reactions are open to students who have had the same class or place."
            default: break
            }
        }
        return "Could not save that reaction. Please try again."
    }

    public static func reportFailureNote(_ error: Error) -> String {
        if let api = error as? APIError, api.code == "report_rate_limited" {
            return "You have reported a lot recently — please wait a while."
        }
        return "Could not send that report. Please try again."
    }
}

/// The app's route vocabulary (spec §6.5), mirroring the Web paths. The
/// DeepLinkRouter parses `honey://` URLs into these; feature stacks push them.
public enum AppRoute: Sendable, Equatable, Hashable {
    case home
    case timetable(date: String?, view: TimetableViewMode?)
    case history(select: Bool)
    case experiences
    case explore
    case why
    case mine
    case compose(ComposeTarget?)
    case entity(EntityType, String)
    case settings
    case settingsConnection
    case settingsPrivacy
    case settingsAccount
    case settingsAppearance
}

public enum TimetableViewMode: String, Sendable, Equatable, Hashable, Codable {
    case day, week
}

/// What a composer is about — chosen before the editor exists.
public enum ComposeTarget: Sendable, Equatable, Hashable {
    /// A lesson; `date` lets today's/upcoming lessons resolve from that day's
    /// timetable instead of History.
    case lesson(id: String, date: String?)
    case entity(key: String)
    /// Re-open a private note (its own target travels with it).
    case note(id: String)

    /// `lesson:<id>` or the entity_key — the draft slot key.
    public var draftKey: String? {
        switch self {
        case .lesson(let id, _): return "lesson:\(id)"
        case .entity(let key): return key
        case .note: return nil
        }
    }
}
