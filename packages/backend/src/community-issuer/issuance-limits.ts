// Account-side issuance bounds (spec §29.1): how many eligibility tokens an
// account may draw per scope per day. Counted on an unlinkable HMAC mark of
// (account, scope, day) — no post is referenced, no token value is stored.

import { createHmac } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

export const ISSUANCE_PER_SCOPE_PER_DAY = 6;
export const ISSUANCE_MEMBER_PER_DAY = 30;

export class IssuanceLimits {
  constructor(
    private readonly db: DatabaseSync,
    private readonly markKey: Buffer,
    private readonly now: () => number = Date.now,
  ) {}

  private mark(honeyId: string, scope: string, day: number): string {
    return createHmac("sha256", this.markKey).update(`${honeyId}\0${scope}\0${day}`).digest("hex");
  }

  /** Reserve one issuance; false when the bound for today is reached. */
  take(honeyId: string, scope: string, limit: number): boolean {
    const day = Math.floor(this.now() / 86_400_000);
    const mark = this.mark(honeyId, scope, day);
    const row = this.db.prepare("SELECT count FROM issuance_marks WHERE mark_hash = ?").get(mark) as { count: number } | undefined;
    if ((row?.count ?? 0) >= limit) return false;
    this.db
      .prepare(
        `INSERT INTO issuance_marks (mark_hash, day, count) VALUES (?, ?, 1)
         ON CONFLICT(mark_hash) DO UPDATE SET count = issuance_marks.count + 1`,
      )
      .run(mark, day);
    return true;
  }

  /** Marks older than two days carry no information worth keeping. */
  sweep(): void {
    const day = Math.floor(this.now() / 86_400_000);
    this.db.prepare("DELETE FROM issuance_marks WHERE day < ?").run(day - 2);
  }
}
