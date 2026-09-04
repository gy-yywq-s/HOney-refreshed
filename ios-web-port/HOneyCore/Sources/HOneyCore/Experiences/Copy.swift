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
                return L10n.t("The school portal rejected that username or password.")
            case "portal_interactive_challenge":
                return L10n.t("The school portal is asking for an interactive verification. Sign in once on the portal website, then try again here.")
            case "portal_unavailable":
                return L10n.t("The school portal is unreachable right now. Please try again in a few minutes.")
            case "network_error":
                return L10n.t("Could not reach the HOney server. Check your connection and try again.")
            case "timeout":
                return L10n.t("The HOney server took too long to answer. Please try again.")
            case "session_expired", "not_authenticated":
                return L10n.t("Your session has expired. Please sign in again.")
            default:
                break
            }
            if api.status == 502 || api.status == 503 {
                return L10n.t("The school portal is unreachable right now. Please try again in a few minutes.")
            }
            return L10n.t("Something went wrong ({}).", api.code)
        }
        if error is CancellationError { return "" }
        return L10n.t("Something went wrong. Please try again.")
    }
}

public enum ModerationCopy {
    public static var editRequired: String { L10n.t("This wording can’t be shared here yet. Remove the insult or private detail, then say what happened or how it felt. Nothing was kept — your draft is still here.") }
    public static var outOfScope: String { L10n.t("This sounds like something that needs real support or action, not a public post. HOney won’t publish it or send it to the school. You can keep it for yourself instead.") }
    public static var blocked: String { L10n.t("This can't be published under the community rules. Nothing was stored — your draft is still here if you want to reshape it.") }
    public static var failedClosed: String { L10n.t("HOney could not check this reliably. Nothing was published, and your words remain on this iPhone.") }
    public static var failedClosedUnsaved: String { L10n.t("HOney could not check this reliably. Nothing was published — and this iPhone could not save the draft either, so copy your words before leaving.") }
    public static var draftNotSaved: String { L10n.t("This iPhone could not save the draft. Your words are only in this editor until it can.") }
    public static var restoreNeeded: String { L10n.t("Your post controls exist, but not on this iPhone yet. Restore them in Settings › Post controls, then share. Your draft stays here.") }
    public static var keptPrivateNeverSent: String { L10n.t("This note stayed on this iPhone — it was never sent anywhere. You can edit, delete or share it later from Your notes & posts.") }
    public static var keptPrivateAfterCheck: String { L10n.t("It was not published. The text was processed once for the pre-publication check, then kept as a private note on this iPhone. You can edit, delete or share it later from Your notes & posts.") }
    public static var cooldownSaveFailed: String { L10n.t("Publishing can wait, but this iPhone could not save the note. Copy your words, or fix the storage problem and try Keep private again.") }

    public static var nudgeQuestion: String { L10n.t("This can be shared as it is. Is there anything that would help someone understand what you mean?") }
    public static var cooldownTitle: String { L10n.t("Publishing can wait") }
    public static var cooldownNote: String { L10n.t("This is a pause, not a judgment about your experience.") }
    public static var sharedTitle: String { L10n.t("Shared.") }
    public static var sharedBody: String { L10n.t("Your school identity is not shown with this public Experience. This iPhone keeps its control key so you can manage it later.") }
    public static var keptPrivateTitle: String { L10n.t("Kept private") }
    public static var keptPrivateBody: String { keptPrivateNeverSent }
    public static var privacyLine: String { L10n.t("Public sharing runs a text check. Published Experiences are stored without an ordinary author field.") }
    public static var keyUnsavedBody: String { L10n.t("The post is already public, but this iPhone could not store its control key. Copy the key now — without it the post cannot be managed or removed later.") }

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
        reasons.compactMap { checkReasons[$0].map(L10n.t) }
    }
}

public enum SubmitErrorCopy {
    static let byCode: [String: String] = [
        "publications_disabled": "Publishing is paused for everyone right now. You can still save this privately and publish once posting reopens.",
        "body_invalid": "The text is empty or longer than 5000 characters.",
        "rating_invalid": "Stars are whole numbers from 1 to 5.",
        "lesson_not_yours": "That lesson isn't in your imported history, so this account can't review it. Pick a lesson from your own History.",
        "lesson_not_started": "This lesson hasn't started yet. You can share what it was like once it has begun.",
        "entity_unknown": "This entry is no longer listed.",
        "entity_frozen": "New experiences for this entry are paused by the moderators right now.",
        "standalone_closed": "Reviews for this entry are closed right now.",
        "not_invited": "This entry is invite-only, and this account hasn't been invited to review it.",
        "no_verified_exposure": "You can review teachers and rooms your imported timetable shows you've actually had — nothing in your history matches this entry.",
        "rating_not_allowed": "Stars are for dishes only, never for people, lessons or rooms. Remove the rating to continue.",
        "cooldown_ticket_invalid": "You edited the text since the waiting period started, so the check needs to run once more. Nothing was lost.",
        "already_posted": "You've already shared an experience for this. Remove it in Your notes & posts if you want to write a new one.",
        "temporarily_suspended": "Sharing from this posting identity is paused for a while after repeated rule problems.",
        "issuer_unavailable": "Sharing isn't available right now (the eligibility service is not ready). Your words stay on this iPhone.",
        "issuance_rate_limited": "You've asked to share many times today. Try again tomorrow — your words stay on this iPhone.",
        "token_invalid": "The eligibility check didn't verify. Try again; your words are still here.",
        "token_scope_mismatch": "The eligibility check was for something else. Try again from the same lesson or entry.",
        "token_expired": "The eligibility check expired. Try again; your words are still here.",
        "token_used": "That eligibility check was already used. Try again; your words are still here.",
        "envelope_invalid": "Something in the post's packaging was wrong. Try again; your words are still here.",
        "signature_invalid": "This iPhone's post controls could not sign the post. Check Settings › Post controls.",
        "pass_invalid": "The pre-publication check has expired. Run it again; your words are still here.",
        "pass_mismatch": "The text changed after the check. Run it again; your words are still here.",
    ]

    public static func describe(_ error: Error) -> String {
        if let api = error as? APIError {
            if let text = byCode[api.code] { return L10n.t(text) }
            if api.code == "network_error" {
                return L10n.t("Could not reach the HOney server. Check your connection and try again.")
            }
        }
        return L10n.t("Something went wrong submitting this. Please try again.")
    }
}

/// A "mine" row only ever exists for a post that was actually published and
/// is still controlled: published, or later hidden (blocked). A removed post
/// is deleted outright (v2: revoke frees the slot), so it has no row.
public enum MineStatusCopy {
    public struct Meta: Sendable, Equatable {
        public let label: String
        public let tone: ExitPermit.Tone
        public let explain: String
    }

    public static func meta(_ status: MineStatus) -> Meta {
        switch status {
        case .published: return Meta(label: L10n.t("Shared"), tone: .ok, explain: "")
        case .blocked: return Meta(label: L10n.t("Hidden"), tone: .danger, explain: L10n.t("This was hidden after a re-check against the current community rules. You can remove it if you want to write a new one about this."))
        case .unknown(let raw): return Meta(label: raw, tone: .muted, explain: "")
        }
    }

    public static var removed: String { L10n.t("Removed. The post is gone — you can write a new one about this any time.") }
    public static var removeFailed: String { L10n.t("Could not remove the post. Please try again.") }
    public static var rootNotHere: String { L10n.t("The post control that manages this post is not on this iPhone. Restore your post controls first (Settings › Post controls).") }
}

/// Post controls copy (Settings › Post controls; Web: PostControlsPage.tsx).
public enum PostControlsCopy {
    public static var createdLocal: String { L10n.t("Post controls created on this device") }
    public static var ready: String { L10n.t("Post controls are on this device and backed up.") }
    public static var restoreNeeded: String { L10n.t("Restore on this device") }
    public static var restoreExplain: String { L10n.t("Your post controls exist, but not on this iPhone. Restore them with a passkey, another device, or your 12 recovery words.") }
    public static var wordsExplain: String { L10n.t("Write these 12 words down and keep them somewhere safe. They restore your post controls on a new device. HOney never sees them.") }
    public static var wordsWrong: String { L10n.t("Those words don't match. Check the spelling and the order.") }
    public static var pairExplain: String { L10n.t("On the device that already has your post controls, open Settings › Post controls › Another device and enter this code.") }
    public static var replaceExplain: String { L10n.t("Future posts will be signed by a new root. If saving the backup fails, nothing changes.") }
    public static var eraseExplain: String { L10n.t("Removes the post controls from this iPhone only. The encrypted backup stays; you can restore later with a passkey, another device or the recovery words.") }
}
