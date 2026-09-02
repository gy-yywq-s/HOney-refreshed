// Why this space exists (spec §21): the Web's reading page as native prose.
// It never claims teachers cannot see posts and never promises absolute
// anonymity — copy stays inside what the implementation guarantees.

import SwiftUI
import HOneyCore

struct WhyView: View {
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
            VStack(alignment: .leading, spacing: HSpace.x6) {
                Text("Written by students, for students.")
                    .font(HType.pageTitle)
                    .foregroundStyle(Color.honeyInk)
                ForEach(sections, id: \.0) { title, body in
                    VStack(alignment: .leading, spacing: HSpace.x2) {
                        Text(title).font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                        Text(body).font(HType.body).foregroundStyle(Color.honeyInk).lineSpacing(3)
                    }
                }
                VStack(alignment: .leading, spacing: HSpace.x2) {
                    Text("How to read Experiences.").font(HType.body.weight(.semibold)).foregroundStyle(Color.honeyInk)
                    ForEach(howToRead, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: HSpace.x2) {
                            Text("•")
                            Text(line)
                        }
                        .font(HType.body)
                        .foregroundStyle(Color.honeyInk)
                    }
                }
            }
            .pageInset()
            .padding(.vertical, HSpace.x4)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .background(Color.honeyCanvas.ignoresSafeArea())
        .navigationTitle(L10n.t("Why this space exists"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
