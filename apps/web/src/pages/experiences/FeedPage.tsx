// /experiences — the default surface is the STREAM (review v3 §9): real
// voices before any directory or control. Two scopes (Your classes / Around
// school), cursor pagination with an intersection sentinel, a quiet
// new-posts banner that never yanks the reader, an interleaved share
// invitation, and the persistent student-to-student identity line.
// Scroll model: FRAMED_SCROLL (web-lab.md).

import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import { ExperiencePost } from "../../features/experiences/ExperiencePost";
import { useFeedController } from "../../features/experiences/useFeedController";
import { useLoadMoreSentinel } from "../../features/experiences/useLoadMoreSentinel";
import { Skeleton } from "../../lib/motion";
import type { FeedScope } from "../../api/types";

const SCOPE_STORAGE = "honey.exp.scope";
const SHARE_PROMPT_EVERY = 8; // one gentle invitation per ~8 posts (§9.7.4)

export function ExperiencesFeedPage() {
  const [scope, setScope] = useState<FeedScope>(() =>
    localStorage.getItem(SCOPE_STORAGE) === "school" ? "school" : "my_classes",
  );
  const feed = useFeedController(scope);

  function switchScope(next: FeedScope) {
    setScope(next);
    localStorage.setItem(SCOPE_STORAGE, next);
  }

  const sentinel = useLoadMoreSentinel(feed.loadMore);
  const streamRef = useRef<HTMLDivElement>(null);
  // The empty and error states carry their own action — one per screen.
  const showHeaderShare = feed.loading || (feed.error === null && feed.items.length > 0);

  return (
    <div className="feed-screen">
      <header className="feed-head">
        <div className="feed-head__row">
          <h1 className="page-title">Experiences</h1>
          <div className="feed-head__tools">
            {showHeaderShare && (
              <Link className="btn btn--primary btn--small" to="/experiences/compose">
                Share
              </Link>
            )}
            <Link className="btn btn--ghost btn--small" to="/experiences/explore">
              Find someone or something
            </Link>
            <Link className="btn btn--ghost btn--small" to="/experiences/mine">
              Your notes &amp; posts
            </Link>
          </div>
        </div>
        {/* Always-visible community identity (§9.4A) — two lines, never a hero. */}
        <p className="feed-identity">
          For students, between students — not a teacher feedback channel.{" "}
          <Link to="/experiences/why">Why this space exists</Link>
        </p>
        <div
          className="scope-switch"
          role="tablist"
          aria-label="Feed scope"
          onKeyDown={(e) => {
            // ARIA tabs pattern: arrows move AND select (two tabs only).
            if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
              e.preventDefault();
              const next = scope === "my_classes" ? "school" : "my_classes";
              switchScope(next);
              const btn = e.currentTarget.querySelector<HTMLElement>(
                `[data-scope="${next}"]`,
              );
              btn?.focus();
            }
          }}
        >
          <button
            role="tab"
            data-scope="my_classes"
            aria-selected={scope === "my_classes"}
            className={scope === "my_classes" ? "scope-switch__btn scope-switch__btn--on" : "scope-switch__btn"}
            onClick={() => switchScope("my_classes")}
          >
            Your classes
          </button>
          <button
            role="tab"
            data-scope="school"
            aria-selected={scope === "school"}
            className={scope === "school" ? "scope-switch__btn scope-switch__btn--on" : "scope-switch__btn"}
            onClick={() => switchScope("school")}
          >
            Around school
          </button>
        </div>
      </header>

      {feed.newAvailable && (
        <button type="button" className="feed-new" onClick={() => void feed.jumpToNew()}>
          New experiences are available
        </button>
      )}

      <div className="feed-stream" aria-live="polite" ref={streamRef} tabIndex={-1}>
        {feed.loading ? (
          <Skeleton lines={6} />
        ) : feed.error ? (
          <div role="alert" className="banner banner--danger">
            <span>{feed.error}</span>
            <button
              className="btn btn--ghost btn--small"
              onClick={() => void feed.refresh().then(() => streamRef.current?.focus())}
            >
              Try again
            </button>
          </div>
        ) : feed.items.length === 0 ? (
          scope === "my_classes" ? (
            <div className="feed-empty">
              <p>
                <strong>Nothing from your classes yet.</strong>
              </p>
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
              <p>
                <strong>Nothing has been shared yet.</strong>
              </p>
              <p className="muted">A short thought is enough to begin.</p>
              <Link className="btn btn--primary" to="/experiences/compose">
                Share an experience
              </Link>
            </div>
          )
        ) : (
          feed.items.map((exp, i) => (
            <div key={exp.id}>
              {i > 0 && i % SHARE_PROMPT_EVERY === 0 && (
                <aside className="feed-invite">
                  <p>Anything from school you want to put into words?</p>
                  <Link className="btn btn--ghost btn--small" to="/experiences/compose">
                    Share an experience
                  </Link>
                </aside>
              )}
              <ExperiencePost exp={exp} />
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
