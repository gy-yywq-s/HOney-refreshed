// Eligibility token redemption (spec §31–§32): offline verification with the
// issuer PUBLIC key (no call to Core, ever), a two-week window on the
// issuance week, a short reservation at check time and one consumption at
// publish. The reservation keys on the token hash and the scope hash so a
// token checked for one envelope cannot be spent on another scope.

import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import type { DatabaseSync } from "node:sqlite";
import { canonicalize, importIssuerPublicKey, tokenHash, verifyToken, type EligibilityToken, type IssuerDescriptor } from "@honey/shared/community-v2";

const RESERVATION_MS = 60 * 60_000;
const TOKEN_WEEKS = 2;

export type RedemptionError = "token_invalid" | "token_expired" | "token_used" | "token_scope_mismatch" | "issuer_unavailable";

export class IssuerKeys {
  private keys = new Map<string, CryptoKey>();
  private loadedAt = 0;

  constructor(
    private readonly publicPath: string,
    private readonly fixed?: IssuerDescriptor,
  ) {}

  /** Refreshes from the descriptor file every few minutes (Core may rotate). */
  async keyFor(keyId: string): Promise<CryptoKey | null> {
    if (this.fixed) {
      if (!this.keys.has(this.fixed.keyId)) this.keys.set(this.fixed.keyId, await importIssuerPublicKey(this.fixed.publicKey));
      return this.keys.get(keyId) ?? null;
    }
    if (!this.keys.has(keyId) || Date.now() - this.loadedAt > 5 * 60_000) {
      if (existsSync(this.publicPath)) {
        try {
          const d = JSON.parse(readFileSync(this.publicPath, "utf8")) as IssuerDescriptor;
          this.keys.set(d.keyId, await importIssuerPublicKey(d.publicKey));
        } catch {
          /* unreadable descriptor: keep the keys we have */
        }
      }
      this.loadedAt = Date.now();
    }
    return this.keys.get(keyId) ?? null;
  }
}

export function scopeHashOf(token: EligibilityToken): string {
  return createHash("sha256").update(canonicalize({ scope: token.info.scope, contexts: token.info.contexts, schoolId: token.info.schoolId, academicYear: token.info.academicYear } as never)).digest("hex");
}

export class TokenRedemption {
  constructor(
    private readonly db: DatabaseSync,
    private readonly issuers: IssuerKeys,
    private readonly currentWeek: () => number,
    private readonly now: () => number = Date.now,
  ) {}

  /** Structural + cryptographic verification; nothing stored. */
  async verify(token: EligibilityToken): Promise<RedemptionError | null> {
    if (!token || typeof token !== "object" || !token.info || typeof token.keyId !== "string") return "token_invalid";
    const info = token.info;
    if (info.v !== 2 || typeof info.scope !== "string" || typeof info.schoolId !== "string" || typeof info.academicYear !== "string" || typeof info.week !== "number") {
      return "token_invalid";
    }
    const week = this.currentWeek();
    if (info.week > week + 1 || info.week < week - TOKEN_WEEKS) return "token_expired";
    const key = await this.issuers.keyFor(token.keyId);
    if (!key) return "issuer_unavailable";
    if (!(await verifyToken(key, token))) return "token_invalid";
    return null;
  }

  /** Reserve for this scope (idempotent for the same token+scope); refuse a spent or re-scoped token. */
  reserve(token: EligibilityToken): RedemptionError | null {
    const hash = tokenHash(token);
    const scope = scopeHashOf(token);
    const row = this.db.prepare("SELECT scope_hash, reserved_until, consumed_at FROM anonymous_token_reservations WHERE token_hash = ?").get(hash) as
      | { scope_hash: string; reserved_until: number; consumed_at: number | null }
      | undefined;
    if (row?.consumed_at) return "token_used";
    if (row && row.scope_hash !== scope) return "token_scope_mismatch";
    this.db
      .prepare(
        `INSERT INTO anonymous_token_reservations (token_hash, scope_hash, reserved_until) VALUES (?, ?, ?)
         ON CONFLICT(token_hash) DO UPDATE SET reserved_until = excluded.reserved_until`,
      )
      .run(hash, scope, this.now() + RESERVATION_MS);
    return null;
  }

  /** Consume exactly once, inside the caller's transaction. */
  consume(token: EligibilityToken): RedemptionError | null {
    const hash = tokenHash(token);
    const scope = scopeHashOf(token);
    const row = this.db.prepare("SELECT scope_hash, consumed_at FROM anonymous_token_reservations WHERE token_hash = ?").get(hash) as
      | { scope_hash: string; consumed_at: number | null }
      | undefined;
    if (row?.consumed_at) return "token_used";
    if (row && row.scope_hash !== scope) return "token_scope_mismatch";
    this.db
      .prepare(
        `INSERT INTO anonymous_token_reservations (token_hash, scope_hash, reserved_until, consumed_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(token_hash) DO UPDATE SET consumed_at = excluded.consumed_at`,
      )
      .run(hash, scope, this.now(), this.now());
    return null;
  }

  /** Expired unconsumed reservations carry nothing worth keeping. */
  sweep(): void {
    this.db.prepare("DELETE FROM anonymous_token_reservations WHERE consumed_at IS NULL AND reserved_until < ?").run(this.now() - 7 * 86_400_000);
  }
}
