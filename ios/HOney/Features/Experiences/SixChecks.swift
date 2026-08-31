//
//  SixChecks.swift
//  HOney — the Six Checks community rules, shown as contextual composer hints
//  (never a mandatory six-checkbox ritual). Source: master spec §4.
//

import Foundation

struct SixCheck: Identifiable {
    let id: Int
    let title: String
    let prompt: String
}

enum SixChecks {
    static let all: [SixCheck] = [
        SixCheck(id: 1, title: "Mine?", prompt: "Is this your own experience?"),
        SixCheck(id: 2, title: "How sure?", prompt: "Are you describing what you know, or what you infer?"),
        SixCheck(id: 3, title: "Some context?", prompt: "Can you add anything that helps another student understand?"),
        SixCheck(id: 4, title: "Private?", prompt: "Does this reveal something that is not yours to publish?"),
        SixCheck(id: 5, title: "Still human?", prompt: "Are you sharing an experience, or turning someone into an object of attack?"),
        SixCheck(id: 6, title: "Bigger than Honey?", prompt: "Would this require investigation, safeguarding or urgent action? Then use the school's channels.")
    ]
}
