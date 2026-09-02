// The pull-down's stages, as a pure function so the gesture engines (iOS
// rubber band / finger drag) share one contract and the thresholds are
// testable without a browser (2026-09-02, after the Ionic reference).
//
// Distance is the real displacement of the content (px), not finger
// travel: on iOS the rubber band damps it, elsewhere the drag engine does.
//
// Stage 1, refresh: a modest pull; release re-reads HOney.
// Stage 2, sync with school: must be impossible to hit by accident (Gary).
// Three guards stack: the distance is far (≈ a fifth of the screen of
// real displacement, roughly 330px of finger on an iPhone), the pill has
// to be HELD there while a fill runs across it, and the pill changes
// colour only once armed. Letting go early still just refreshes.

export type PullStage = "idle" | "pull" | "refresh" | "further" | "hold" | "sync";

export interface PullThresholds {
  refreshAt: number;
  syncAt: number;
  holdMs: number;
}

export const REFRESH_AT = 64;
export const HOLD_MS = 450;
/** Shows the "keep pulling" hint once clearly past the refresh point. */
const FURTHER_GAP = 28;
const NOTICE_AT = 10;

/** Stage-2 distance scales with the screen so it stays a deliberate reach. */
export function syncAtFor(viewportHeight: number): number {
  return Math.round(Math.min(160, Math.max(110, viewportHeight * 0.18)));
}

export function stageFor(
  px: number,
  syncable: boolean,
  heldMs: number,
  th: PullThresholds = { refreshAt: REFRESH_AT, syncAt: syncAtFor(844), holdMs: HOLD_MS },
): PullStage {
  if (px < NOTICE_AT) return "idle";
  if (px < th.refreshAt) return "pull";
  if (!syncable) return "refresh";
  if (px < th.refreshAt + FURTHER_GAP) return "refresh";
  if (px < th.syncAt) return "further";
  return heldMs >= th.holdMs ? "sync" : "hold";
}

/** What a release at this stage does. */
export function commitFor(stage: PullStage): "" | "refresh" | "sync" {
  if (stage === "sync") return "sync";
  if (stage === "refresh" || stage === "further" || stage === "hold") return "refresh";
  return "";
}
