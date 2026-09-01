//
//  ExperienceSubmitCopy.swift
//  HOney — user-facing copy for publication-flow failures (Band 1, no SwiftUI).
//  Mirrors `describeSubmitError` / SUBMIT_ERROR_COPY in the web
//  apps/web/src/pages/experiences/shared.tsx verbatim.
//

import Foundation

enum ExperienceSubmitCopy {
    /// Friendly copy for every submit 422 the backend can return.
    static let byCode: [String: String] = [
        "publications_disabled":
            "Publishing is paused for everyone right now. You can still save this privately and publish once posting reopens.",
        "body_invalid": "The text is empty or longer than 5000 characters.",
        "rating_invalid": "Stars are whole numbers from 1 to 5.",
        "lesson_not_yours":
            "That lesson isn't in your imported history, so this account can't review it. Pick a lesson from your own History.",
        "entity_unknown": "This entry isn't in the registry any more — it may have been removed.",
        "entity_frozen": "New experiences for this entry are paused by the moderators right now.",
        "standalone_closed": "Reviews for this entry are closed right now.",
        "not_invited": "This entry is invite-only, and this account hasn't been invited to review it.",
        "no_verified_exposure":
            "You can review teachers and rooms your imported timetable shows you've actually had — nothing in your history matches this entry.",
        "rating_not_allowed":
            "Stars are for dishes only, never for people, lessons or rooms. Remove the rating to continue.",
        "already_reviewed":
            "You've already shared an experience for this. You can revoke it in My contributions if you want to write a new one."
    ]

    static let networkError = "Could not reach the HOney server. Check your connection and try again."
    static let fallback = "Something went wrong submitting this. Please try again."

    static func describe(_ error: Error) -> String {
        if let code = (error as? HOneyAPIError)?.apiErrorCode, let copy = byCode[code] {
            return copy
        }
        if error is URLError {
            return networkError
        }
        return fallback
    }
}
