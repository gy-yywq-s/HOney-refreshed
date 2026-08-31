//
//  NextLessonPresentation.swift
//  HOney — pure temporal formatting for the Home "Next Lesson" surface.
//  No SwiftUI; unit-tested.
//

import Foundation

enum NextLessonPresentation {
    /// Short temporal summary shown under the Next Lesson header.
    ///   nil lesson        → "No more lessons today"
    ///   now / <= 0 min    → "Now"
    ///   < 60 min          → "in N min"
    ///   >= 60 min         → "in H hr" / "in H hr M min"
    static func summary(for lesson: NextLesson?) -> String {
        guard let lesson else { return "No more lessons today" }

        if let minutes = lesson.minutesUntilStart {
            if minutes <= 0 { return "Now" }
            if minutes < 60 { return "in \(minutes) min" }
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "in \(hours) hr" : "in \(hours) hr \(remainder) min"
        }

        switch lesson.temporalState {
        case .now: return "Now"
        case .none: return "No more lessons today"
        case .upcoming, .later: return "Upcoming"
        }
    }
}
