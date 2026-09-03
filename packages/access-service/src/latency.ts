// A truthful ETA (spec §22.3): median and p90 of the recent successful
// operations of a kind, rounded to a natural range; "Usually a few seconds"
// when there is not enough to say. No fabricated numbers.

import type { DatabaseSync } from "node:sqlite";

export interface EtaRange {
  lowMs: number;
  highMs: number;
  label: string;
  samples: number;
}

const MIN_SAMPLES = 5;
const WINDOW = 100;

function quantile(sorted: number[], q: number): number {
  if (sorted.length === 0) return 0;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.round(q * (sorted.length - 1))));
  return sorted[i]!;
}

/** "Usually 1–2 seconds": whole seconds, low from the median, high from p90, at least 1 s wide. */
export function labelFor(medianMs: number, p90Ms: number): string {
  const low = Math.max(1, Math.round(medianMs / 1000));
  const high = Math.max(low + 1, Math.ceil(p90Ms / 1000));
  return `Usually ${low}–${high} seconds`;
}

export class LatencyModel {
  constructor(
    private readonly db: DatabaseSync,
    private readonly serviceVersion: string,
  ) {}

  record(kind: string, warm: boolean, durationMs: number): void {
    this.db
      .prepare("INSERT INTO access_latency_samples (kind, warm, duration_ms, service_version, created_at) VALUES (?, ?, ?, ?, ?)")
      .run(kind, warm ? 1 : 0, Math.max(0, Math.round(durationMs)), this.serviceVersion, Date.now());
    // Keep the table small: only the recent window matters.
    this.db.prepare(`DELETE FROM access_latency_samples WHERE kind = ? AND id NOT IN (SELECT id FROM access_latency_samples WHERE kind = ? ORDER BY created_at DESC LIMIT ${WINDOW * 2})`).run(kind, kind);
  }

  eta(kind: string): EtaRange {
    const rows = this.db
      .prepare(`SELECT duration_ms FROM access_latency_samples WHERE kind = ? ORDER BY created_at DESC LIMIT ${WINDOW}`)
      .all(kind) as { duration_ms: number }[];
    if (rows.length < MIN_SAMPLES) return { lowMs: 1000, highMs: 4000, label: "Usually a few seconds", samples: rows.length };
    const sorted = rows.map((r) => r.duration_ms).sort((a, b) => a - b);
    const median = quantile(sorted, 0.5);
    const p90 = quantile(sorted, 0.9);
    return { lowMs: median, highMs: p90, label: labelFor(median, p90), samples: rows.length };
  }
}
