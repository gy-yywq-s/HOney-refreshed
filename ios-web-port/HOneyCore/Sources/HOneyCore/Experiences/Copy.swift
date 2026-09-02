// User-facing copy for API failures and moderation outcomes — the same
// tables the Web uses (api/client.ts describeApiError, useComposer.ts,
// pages/experiences/shared.tsx, MinePage.tsx). Raw reason codes never
// reach the screen: an unknown code renders nothing.

import Foundation

public enum APIErrorCopy {
    public static func describe(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api.code {
            case "school_credentials_rejected":
                return "The school portal rejected that username or password."
            case "portal_interactive_challenge":
                return "The school portal is asking for an interactive verification. Sign in once on the portal website, then try again here."
            case "portal_unavailable":
                return "The school portal is unreachable right now. Please try again in a few minutes."
            case "network_error":
                return "Could not reach the HOney server. Check your connection and try again."
            case "timeout":
                return "The HOney server took too long to answer. Please try again."
            case "session_expired", "not_authenticated":
                return "Your session has expired. Please sign in again."
            default:
                break
            }
            if api.status == 502 || api.status == 503 {
                return "The school portal is unreachable right now. Please try again in a few minutes."
            }
            return "Something went wrong (\(api.code))."
        }
        if error is CancellationError { return "" }
        return "Something went wrong. Please try again."
    }
}

public enum ModerationCopy {
    public static let editRequired = "This wording can’t be shared here yet. Remove the insult or private detail, then say what happened or how it felt. Nothing was kept — your draft is still here."
    public static let outOfScope = "This sounds like something that needs real support or action, not a public post. HOney won’t publish it or send it to the school. You can keep it for yourself instead."
    public static let blocked = "This can't be published under the community rules. Nothing was stored — your draft is still here if you want to reshape it."
    public static let failedClosed = "HOney could not check this reliably. Nothing was published, and your words remain on this iPhone."
    public static let failedClosedUnsaved = "HOney could not check this reliably. Nothing was published — and this iPhone could not save the draft either, so copy your words before leaving."
    public static let draftNotSaved = "This iPhone could not save the draft. Your words are only in this editor until it can."
    public static let keptPrivateNeverSent = "This note stayed on this iPhone — it was never sent anywhere. You can edit, delete or share it later from Your notes & posts."
    public static let keptPrivateAfterCheck = "It was not published. The text was processed once for the pre-publication check, then kept as a private note on this iPhone. You can edit, delete or share it later from Your notes & posts."
    public static let cooldownSaveFailed = "Publishing can wait, but this iPhone could not save the note. Copy your words, or fix the storage problem and try Keep private again."

    public static let nudgeQuestion = "This can be shared as it is. Is there anything that would help someone understand what you mean?"
    public static let cooldownTitle = "Publishing can wait"
    public static let cooldownNote = "This is a pause, not a judgment about your experience."
    public static let sharedTitle = "Shared."
    public static let sharedBody = "Your school identity is not shown with this public Experience. This iPhone keeps its control key so you can manage it later."
    public static let keptPrivateTitle = "Kept private"
    public static let keptPrivateBody = keptPrivateNeverSent
    public static let privacyLine = "Public sharing runs a text check. Published Experiences are stored without an ordinary author field."
    public static let keyUnsavedBody = "The post is already public, but this iPhone could not store its control key. Copy the key now — without it the post cannot be managed or removed later."

    /// Gate-prefixed check reason codes → the ONE boundary sentence shown.
    static let checkReasons: [String: String] = [
        "standing:hearsay": "It describes something you heard rather than your own experience.",
        "expression:targeted_profanity": "Part of the wording targets a person rather than describing the experience.",
        "expression:targets_student": "It evaluates or identifies another student — students aren't public subjects here.",
        "expression:privacy_invasion": "It includes private details that could identify or expose someone.",
        "expression:lexical:identifying_information": "It includes contact or identifying information. Remove it — the experience can still be told.",
        "expression:injection_attempt": "Part of the text reads as instructions to the system rather than an experience.",
        "expression:uncertain": "We couldn’t understand part of this well enough to publish it. Say it more directly.",
        "timing:high_arousal": "This can still be your experience. Publishing it can wait until you'd share it the same way tomorrow.",
        "composition:low_information": "A little context about what led you here can help another student — optional.",
        "rating_not_allowed_for_entity": "Star ratings only exist for canteen dishes.",
    ]

    public static func describeReasons(_ reasons: [String]) -> [String] {
        reasons.compactMap { checkReasons[$0] }
    }
}

public enum SubmitErrorCopy {
    static let byCode: [String: String] = [
        "publications_disabled": "Publishing is paused for everyone right now. You can still save this privately and publish once posting reopens.",
        "body_invalid": "The text is empty or longer than 5000 characters.",
        "rating_invalid": "Stars are whole numbers from 1 to 5.",
        "lesson_not_yours": "That lesson isn't in your imported history, so this account can't review it. Pick a lesson from your own History.",
        "entity_unknown": "This entry is no longer listed.",
        "entity_frozen": "New experiences for this entry are paused by the moderators right now.",
        "standalone_closed": "Reviews for this entry are closed right now.",
        "not_invited": "This entry is invite-only, and this account hasn't been invited to review it.",
        "no_verified_exposure": "You can review teachers and rooms your imported timetable shows you've actually had — nothing in your history matches this entry.",
        "rating_not_allowed": "Stars are for dishes only, never for people, lessons or rooms. Remove the rating to continue.",
        "cooldown_ticket_invalid": "You edited the text since the waiting period started, so the check needs to run once more. Nothing was lost.",
        "already_reviewed": "You've already shared an experience for this. Remove it in Your notes & posts if you want to write a new one.",
    ]

    public static func describe(_ error: Error) -> String {
        if let api = error as? APIError {
            if let text = byCode[api.code] { return text }
            if api.code == "network_error" {
                return "Could not reach the HOney server. Check your connection and try again."
            }
        }
        return "Something went wrong submitting this. Please try again."
    }
}

/// A "mine" row only ever exists for a post that was actually published, so
/// the only statuses are published, later-hidden (blocked) and revoked.
public enum MineStatusCopy {
    public struct Meta: Sendable, Equatable {
        public let label: String
        public let tone: ExitPermit.Tone
        public let explain: String
    }

    public static func meta(_ status: MyExperienceStatus) -> Meta {
        switch status {
        case .published: return Meta(label: "Shared", tone: .ok, explain: "")
        case .blocked: return Meta(label: "Hidden", tone: .danger, explain: "This was hidden after a re-check against the current community rules. You can remove it if you want to write a new one about this.")
        case .revoked: return Meta(label: "Removed", tone: .muted, explain: "You removed this post — you can write a new one about this whenever you want.")
        case .unknown(let raw): return Meta(label: raw, tone: .muted, explain: "")
        }
    }
}
