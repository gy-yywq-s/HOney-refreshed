// /experiences — the default surface is the STREAM (review v3 §9): real
// voices before any directory or control. Two scopes (Your classes / Around
// school), cursor pagination with an intersection sentinel, a quiet
// new-posts banner that never yanks the reader, an interleaved share
// invitation, and the persistent student-to-student identity line.
// Scroll model: FRAMED_SCROLL (web-lab.md).

import { useEffect, useRef, useState } from "react";
import {
  IonIcon,
  IonLabel,
  IonSegment,
  IonSegmentButton,
} from "@ionic/react";
import { createOutline, folderOpenOutline, searchOutline } from "ionicons/icons";
import { Link } from "react-router-dom";
import { ExperiencePost } from "../../features/experiences/ExperiencePost";
import { useFeedController } from "../../features/experiences/useFeedController";
import { Skeleton } from "../../lib/motion";
import type { FeedScope } from "../../api/types";

const SCOPE_STORAGE = "honey.exp.scope";
const SHARE_PROMPT_EVERY = 8;

export function ExperiencesFeedPage() {
  const [scope, setScope] = useState<FeedScope>(() =>
    localStorage.getItem(SCOPE_STORAGE) === "school" ? "school" : "my_classes",
  );
  const feed = useFeedController(scope);

  function switchScope(next: FeedScope) {
    setScope(next);
    localStorage.setItem(SCOPE_STORAGE, next);
  }

  const sentinel = useRef<HTMLDivElement>(null);
  const loadMore = feed.loadMore;
  useEffect(() => {
    const el = sentinel.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) void loadMore();
      },
      { rootMargin: "600px 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [loadMore]);

  return (
    <div className="feed-screen">
      <header className="feed-head">
        <div className="feed-head__row">
          <h1 className="page-title">Experiences</h1>
          <div className="feed-head__tools" aria-label="Experiences actions">
            <Link className="feed-tool feed-tool--primary" to="/experiences/compose">
              <IonIcon icon={createOutline} aria-hidden="true" />
              <span>Share</span>
            </Link>
            <Link
              className="feed-tool"
              to="/experiences/explore"
              aria-label="Find someone or something"
            >
              <IonIcon icon={searchOutline} aria-hidden="true" />
              <span>Find</span>
            </Link>
            <Link
              className="feed-tool"
              to="/experiences/mine"
              aria-label="Your notes and posts"
            >
              <IonIcon icon={folderOpenOutline} aria-hidden="true" />
              <span className="feed-tool__wide">Your notes &amp; posts</span>
              <span className="feed-tool__narrow">Your posts</span>
            </Link>
          </div>
        </div>
        <p className="feed-identity">
          For students, between students — not a teacher feedback channel.{" "}
          <Link to="/experiences/why">Why this space exists</Link>
        </p>
        <IonSegment
          className="scope-switch"
          value={scope}
          aria-label="Feed scope"
          onIonChange={(event) => {
            const next = event.detail.value;
            if (next === "my_classes" || next === "school") switchScope(next);
          }}
        >
          <IonSegmentButton
            className={scope === "my_classes" ? "scope-option scope-option--selected" : "scope-option"}
            value="my_classes"
          >
            <IonLabel>Your classes</IonLabel>
          </IonSegmentButton>
          <IonSegmentButton
            className={scope === "school" ? "scope-option scope-option--selected" : "scope-option"}
            value="school"
          >
            <IonLabel>Around school</IonLabel>
          </IonSegmentButton>
        </IonSegment>
      </header>

      {feed.newAvailable && (
        <button type="button" className="feed-new" onClick={() => void feed.jumpToNew()}>
          New experiences are available
        </button>
      )}

      <div className="feed-stream" aria-live="polite">
        {feed.loading ? (
          <Skeleton lines={6} />
        ) : feed.error ? (
          <div role="alert" className="banner banner--danger">{feed.error}</div>
        ) : feed.items.length === 0 ? (
          scope === "my_classes" ? (
            <div className="feed-empty">
              <p><strong>Nothing from your classes yet.</strong></p>
              <p className="muted">
                When someone shares an experience connected to a class you’ve taken, it will appear
                here.
              </p>
              <Link className="btn btn--primary" to="/experiences/compose">
                Share the first one
              </Link>
            </div>
          ) : (
            <div className="feed-empty">
              <p><strong>Nothing has been shared yet.</strong></p>
              <p className="muted">A short thought is enough to begin.</p>
              <Link className="btn btn--primary" to="/experiences/compose">
                Share an experience
              </Link>
            </div>
          )
        ) : (
          feed.items.map((experience, index) => (
            <div key={experience.id}>
              {index > 0 && index % SHARE_PROMPT_EVERY === 0 && (
                <aside className="feed-invite">
                  <p>Anything from school you want to put into words?</p>
                  <Link className="btn btn--ghost btn--small" to="/experiences/compose">
                    Share an experience
                  </Link>
                </aside>
              )}
              <ExperiencePost exp={experience} />
            </div>
          ))
        )}

        <div ref={sentinel} aria-hidden="true" />
        {feed.loadingMore && <div className="feed-append muted">…</div>}
        {feed.end && feed.items.length > 0 && (
          <div className="feed-end caption">You’re all caught up.</div>
        )}
      </div>
    </div>
  );
}
