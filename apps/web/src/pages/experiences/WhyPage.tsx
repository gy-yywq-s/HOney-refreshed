// /experiences/why — the readable community ground (review v3 §9.4B).
// Scroll model: DOCUMENT (one of the few long-reading pages, by design).
// This page never claims teachers can't see posts, and never promises
// absolute anonymity — copy stays inside what the implementation guarantees.

import { Link } from "react-router-dom";

export function ExperiencesWhyPage() {
  return (
    <article className="doc">
      <header>
        <h1 className="page-title">Why this space exists</h1>
      </header>

      <section>
        <h2>For students, between students.</h2>
        <p>
          School is partly understood through what people who share it tell one another.
          Experiences is a place for that student-to-student understanding. Teachers may be
          discussed here, but this is not a feedback inbox addressed to them, and no post is a
          final judgment of a person. Saying something to a peer, giving a teacher direct
          feedback, and reporting formally to the school are three different acts — this space
          carries the first one.
        </p>
      </section>

      <section>
        <h2>Why share?</h2>
        <p>
          Something can be worth sharing because another student may find it useful, because it
          mattered to you and you want it represented, or both. You don’t have to dress a
          feeling up as advice for it to belong here.
        </p>
      </section>

      <section>
        <h2>Partial, but still meaningful.</h2>
        <p>
          People are more than one experience. Experiences still matter. Read each post as one
          situated account, and read more than one when the context matters.
        </p>
      </section>

      <section>
        <h2>Negative and mixed experiences belong.</h2>
        <p>
          You do not need to make an experience positive, balanced, or perfectly articulated
          before it can matter. <em>Negative is allowed. Cruelty is not.</em>
        </p>
      </section>

      <section>
        <h2>More context, fewer verdicts.</h2>
        <p>
          Specific context makes an experience easier to use, but it is not an entry
          requirement. “I cannot fully explain it, but…” is still a valid experience.
        </p>
      </section>

      <section>
        <h2>What verification means.</h2>
        <p>
          HOney verifies relevant exposure where possible — that a post about a class comes from
          someone who took it. It does not verify every interpretation as fact. Reactions show
          resonance among students with relevant experience; they are not a truth vote.
        </p>
      </section>

      <section>
        <h2>Why anonymity is protected.</h2>
        <p>
          HOney narrows what the public space will carry <em>before</em> publication, so ordinary
          peer speech can be strongly protected. Published posts are stored without your school
          account attached. What you write may still make you recognisable to people who know the
          situation — anonymity is a design boundary, not magic.
        </p>
      </section>

      <section>
        <h2>What this space does not carry.</h2>
        <p>
          When something reasonably calls for investigation, safeguarding, protection, or urgent
          action, a public peer feed is the wrong instrument. HOney will not post it — and will
          not secretly forward it anywhere either; it points you to the right channel and leaves
          the decision with you.
        </p>
      </section>

      <section>
        <h2>How to read Experiences.</h2>
        <ul>
          <li>Read each post as one person’s situated account.</li>
          <li>Compare several when the stakes matter.</li>
          <li>Disagreement does not automatically mean fabrication.</li>
          <li>A reaction means “this matches / doesn’t match my experience” — nothing more.</li>
          <li>Entity pages give context, never a final score.</li>
        </ul>
      </section>

      <footer className="doc__footer">
        <Link className="btn btn--ghost" to="/experiences">Back to Experiences</Link>
      </footer>
    </article>
  );
}
