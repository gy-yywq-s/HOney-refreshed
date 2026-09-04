// Why this space exists (WhyPage.tsx + features.css `.doc`; fidelity spec
// v2 §15): the page title, then sections — a 17 pt heading and 15 pt
// reading paragraphs at 1.6 — as an open document, no cards. It never
// claims teachers cannot see posts and never promises absolute anonymity.

import SwiftUI
import HOneyCore

struct WhyView: View {
    @Environment(\.theme) private var theme
    @Environment(\.hType) private var ramp

    private let sections: [(String, String)] = [
        ("For students, between students.",
         "School is partly understood through what people who share it tell one another. Experiences is a place for that student-to-student understanding. Teachers may be discussed here, but this is not a feedback inbox addressed to them, and no post is a final judgment of a person. Saying something to a peer, giving a teacher direct feedback, and reporting formally to the school are three different acts — this space carries the first one."),
        ("Why share?",
         "Something can be worth sharing because another student may find it useful, because it mattered to you and you want it represented, or both. You don’t have to dress a feeling up as advice for it to belong here."),
        ("Partial, but still meaningful.",
         "People are more than one experience. Experiences still matter. Read each post as one situated account, and read more than one when the context matters."),
        ("Negative and mixed experiences belong.",
         "You do not need to make an experience positive, balanced, or perfectly articulated before it can matter. Negative is allowed. Cruelty is not."),
        ("More context, fewer verdicts.",
         "Specific context makes an experience easier to use, but it is not an entry requirement. “I cannot fully explain it, but…” is still a valid experience."),
        ("What verification means.",
         "HOney verifies relevant exposure where possible — that a post about a class comes from someone who took it. It does not verify every interpretation as fact. Reactions show resonance among students with relevant experience; they are not a truth vote."),
        ("Why anonymity is protected.",
         "HOney narrows what the public space will carry before publication, so ordinary peer speech can be strongly protected. Published posts are stored without your school account attached. What you write may still make you recognisable to people who know the situation — anonymity is a design boundary, not magic."),
        ("What this space does not carry.",
         "When something reasonably calls for investigation, safeguarding, protection, or urgent action, a public peer feed is the wrong instrument. HOney will not post it — and will not secretly forward it anywhere either; it points you to the right channel and leaves the decision with you."),
    ]

    private let howToRead = [
        "Read each post as one person’s situated account.",
        "Compare several when the stakes matter.",
        "Disagreement does not automatically mean fabrication.",
        "A reaction means “this matches / doesn’t match my experience” — nothing more.",
        "Entity pages give context, never a final score.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HSpace.x2) {
                PageTitle(text: L10n.t("Why this space exists"))
                    .padding(.bottom, HSpace.x2)
                ForEach(sections, id: \.0) { title, body in
                    DocSection(title: title) {
                        Text(body).hfont(.docBody).foregroundStyle(theme.ink)
                    }
                }
                DocSection(title: L10n.t("How to read Experiences.")) {
                    VStack(alignment: .leading, spacing: HSpace.x1) {
                        ForEach(howToRead, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: HSpace.x2) {
                                Text("•")
                                Text(line)
                            }
                            .hfont(.docBody)
                            .foregroundStyle(theme.ink)
                        }
                    }
                    .padding(.leading, HSpace.x4)
                }
            }
            .pageInset()
            .padding(.top, HSpace.x2)
            .padding(.bottom, HSpace.x4)
            .frame(maxWidth: 640 + 2 * HSpace.pageX, alignment: .leading)
        }
        .webScreen(title: L10n.t("Why this space exists"))
    }
}

/// `.doc section`: an h2 at the reading size, then the prose.
struct DocSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: HSpace.x2) {
            Text(title)
                .hfont(.docHeading)
                .foregroundStyle(theme.ink)
                .padding(.top, HSpace.x4)
                .accessibilityAddTraits(.isHeader)
            content().fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, HSpace.x3)
    }
}

extension TypeRole {
    /// `.doc h2`: the reading size in the browser's heading weight.
    static let docHeading = TypeRole(size: 17, weight: 700, textStyle: .body, tracking: 0, lineHeight: 1.3)
    /// `.doc p, .doc li`: 15 pt at 1.6.
    static let docBody = TypeRole(size: 15, weight: 400, textStyle: .subheadline, tracking: 0, lineHeight: 1.6)
}
