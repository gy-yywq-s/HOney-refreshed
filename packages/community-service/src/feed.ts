// Identity-free reads (spec §29.2). The viewer's canonical exposure (teacher,
// course and opaque lesson ids it got from Core) arrives in the request and
// scopes "Your classes"; Community never knows who asks. Cursors are sealed
// (the exact publish instant must not exist publicly); names are null on the
// wire — clients join them from Core's public directory.

import { createCipheriv, createDecipheriv, createHmac, randomBytes } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import type { EntityRefV2, EntityStatsV2, ExposureScope, FeedPageV2, PublicExperienceV2 } from "@honey/shared/community-v2";
import type { CommunitySettings } from "./settings.js";

interface Row {
  id: string;
  primary_entity_type: string;
  primary_entity_id: string;
  body: string | null;
  rating: number | null;
  provenance: string;
  published_day: number | null;
  created_at: number;
}

const SELECT = "SELECT id, primary_entity_type, primary_entity_id, body, rating, provenance, published_day, created_at FROM experiences";
const MAX_SCOPE_IDS = 400;

export class FeedService {
  private readonly cursorKey: Buffer;

  constructor(
    private readonly db: DatabaseSync,
    private readonly settings: CommunitySettings,
    private readonly schoolId: string,
    sealKey: Buffer,
  ) {
    this.cursorKey = createHmac("sha256", sealKey).update("community/cursor").digest();
  }

  private sealCursor(t: number, id: string, scope: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.cursorKey, iv);
    const enc = Buffer.concat([cipher.update(JSON.stringify({ v: 2, t, id, s: scope }), "utf8"), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), enc]).toString("base64url");
  }

  private openCursor(cursor: string, scope: string): { t: number; id: string } | null {
    try {
      const buf = Buffer.from(cursor, "base64url");
      const decipher = createDecipheriv("aes-256-gcm", this.cursorKey, buf.subarray(0, 12));
      decipher.setAuthTag(buf.subarray(12, 28));
      const parsed = JSON.parse(Buffer.concat([decipher.update(buf.subarray(28)), decipher.final()]).toString("utf8")) as { v: number; t: number; id: string; s: string };
      if (parsed.v !== 2 || parsed.s !== scope || typeof parsed.t !== "number" || typeof parsed.id !== "string") return null;
      return { t: parsed.t, id: parsed.id };
    } catch {
      return null;
    }
  }

  private static cleanIds(ids: unknown): string[] {
    return Array.isArray(ids) ? ids.filter((x): x is string => typeof x === "string" && x.length > 0 && x.length < 128).slice(0, MAX_SCOPE_IDS) : [];
  }

  /** WHERE fragment for the viewer's exposure; null = no exposure at all. */
  private scopeWhere(exposure: ExposureScope | undefined): { clause: string; params: string[] } | null {
    if (!exposure) return null;
    const pairs: [string, string][] = [
      ...FeedService.cleanIds(exposure.teachers).map((id): [string, string] => ["teacher", id]),
      ...FeedService.cleanIds(exposure.courses).map((id): [string, string] => ["course", id]),
      ...FeedService.cleanIds(exposure.lessons).map((id): [string, string] => ["lesson", id]),
    ];
    if (pairs.length === 0) return null;
    return {
      clause: `id IN (SELECT experience_id FROM experience_associations WHERE (${pairs.map(() => "(entity_type = ? AND entity_id = ?)").join(" OR ")}))`,
      params: pairs.flat(),
    };
  }

  private filterClauses(f: { entityKey?: string; teacherId?: string; courseId?: string; roomId?: string }): { clauses: string[]; params: string[] } {
    const clauses: string[] = [];
    const params: string[] = [];
    if (f.entityKey) {
      const sep = f.entityKey.indexOf(":");
      if (sep > 0) {
        clauses.push("primary_entity_type = ? AND primary_entity_id = ?");
        params.push(f.entityKey.slice(0, sep), f.entityKey.slice(sep + 1));
      }
    }
    for (const [type, id] of [["teacher", f.teacherId], ["course", f.courseId], ["room", f.roomId]] as const) {
      if (id) {
        clauses.push("id IN (SELECT experience_id FROM experience_associations WHERE entity_type = ? AND entity_id = ?)");
        params.push(type, id);
      }
    }
    return { clauses, params };
  }

  private frozen(row: Row): boolean {
    const keys = this.db
      .prepare("SELECT entity_type, entity_id FROM experience_associations WHERE experience_id = ?")
      .all(row.id) as { entity_type: string; entity_id: string }[];
    return keys.some((k) => this.settings.frozenEntity(`${k.entity_type}:${k.entity_id}`));
  }

  private toPublic(row: Row): PublicExperienceV2 {
    const assoc = this.db
      .prepare("SELECT entity_type, entity_id FROM experience_associations WHERE experience_id = ? AND relationship = 'context'")
      .all(row.id) as { entity_type: string; entity_id: string }[];
    const counts = this.db
      .prepare("SELECT SUM(value = 1) AS likes, SUM(value = -1) AS dislikes FROM reactions WHERE experience_id = ?")
      .get(row.id) as { likes: number | null; dislikes: number | null };
    const likes = counts.likes ?? 0;
    const dislikes = counts.dislikes ?? 0;
    const order: EntityRefV2["type"][] = ["course", "teacher", "room", "lesson"];
    const contexts: EntityRefV2[] = assoc
      .map((a) => ({ type: a.entity_type as EntityRefV2["type"], id: a.entity_id, name: null }))
      .sort((a, b) => order.indexOf(a.type) - order.indexOf(b.type));
    return {
      id: row.id,
      primary: { type: row.primary_entity_type as EntityRefV2["type"], id: row.primary_entity_id, name: null },
      contexts,
      body: row.body,
      rating: row.rating,
      provenance: row.provenance as PublicExperienceV2["provenance"],
      publishedDay: row.published_day,
      reactions: likes + dislikes >= this.settings.reactionMinCount() ? { likes, dislikes } : null,
    };
  }

  /** ≤2 consecutive posts per primary entity, minimal stable displacement. */
  private diversify(rows: Row[]): Row[] {
    const key = (r: Row) => `${r.primary_entity_type}:${r.primary_entity_id}`;
    const out: Row[] = [];
    const deferred: Row[] = [];
    for (const row of rows) {
      const n = out.length;
      if (n >= 2 && key(out[n - 1]!) === key(row) && key(out[n - 2]!) === key(row)) {
        deferred.push(row);
      } else {
        out.push(row);
        while (deferred.length > 0) {
          const m = out.length;
          const d = deferred[0]!;
          if (m >= 2 && key(out[m - 1]!) === key(d) && key(out[m - 2]!) === key(d)) break;
          out.push(d);
          deferred.shift();
        }
      }
    }
    return [...out, ...deferred];
  }

  feedPage(req: { scope: "school" | "my_classes"; exposure?: ExposureScope; cursor?: string; limit?: number; entityKey?: string; teacherId?: string; courseId?: string; roomId?: string }): { ok: true; page: FeedPageV2 } | { ok: false; error: string } {
    const empty: FeedPageV2 = { items: [], nextCursor: null, headCursor: null };
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return { ok: true, page: empty };
    const clauses = ["school_id = ?", "status = 'published'"];
    const params: (string | number)[] = [this.schoolId];
    if (req.scope === "my_classes") {
      const scoped = this.scopeWhere(req.exposure);
      if (!scoped) return { ok: true, page: empty };
      clauses.push(scoped.clause);
      params.push(...scoped.params);
    }
    const f = this.filterClauses(req);
    clauses.push(...f.clauses);
    params.push(...f.params);
    if (req.cursor) {
      const c = this.openCursor(req.cursor, req.scope);
      if (!c) return { ok: false, error: "bad_cursor" };
      clauses.push("(created_at < ? OR (created_at = ? AND id < ?))");
      params.push(c.t, c.t, c.id);
    }
    const rawLimit = Number.isFinite(req.limit) ? (req.limit as number) : 20;
    const limit = Math.min(Math.max(Math.trunc(rawLimit), 5), 25);
    const raw = this.db.prepare(`${SELECT} WHERE ${clauses.join(" AND ")} ORDER BY created_at DESC, id DESC LIMIT ${limit + 1}`).all(...params) as unknown as Row[];
    const hasMore = raw.length > limit;
    const pageRows = raw.slice(0, limit).filter((r) => !this.frozen(r));
    const last = raw.length > 0 ? raw[Math.min(limit, raw.length) - 1]! : null;
    const first = raw[0] ?? null;
    return {
      ok: true,
      page: {
        items: this.diversify(pageRows).map((r) => this.toPublic(r)),
        nextCursor: hasMore && last ? this.sealCursor(last.created_at, last.id, req.scope) : null,
        headCursor: req.cursor ? null : this.sealCursor(first?.created_at ?? 0, first?.id ?? "", req.scope),
      },
    };
  }

  feedUpdates(req: { scope: "school" | "my_classes"; exposure?: ExposureScope; head: string }): { ok: true; newItemsAvailable: boolean } | { ok: false; error: string } {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return { ok: true, newItemsAvailable: false };
    const c = this.openCursor(req.head, req.scope);
    if (!c) return { ok: false, error: "bad_cursor" };
    const clauses = ["school_id = ?", "status = 'published'"];
    const params: (string | number)[] = [this.schoolId];
    if (req.scope === "my_classes") {
      const scoped = this.scopeWhere(req.exposure);
      if (!scoped) return { ok: true, newItemsAvailable: false };
      clauses.push(scoped.clause);
      params.push(...scoped.params);
    }
    const hit = this.db.prepare(`SELECT 1 FROM experiences WHERE ${clauses.join(" AND ")} AND (created_at > ? OR (created_at = ? AND id > ?)) LIMIT 1`).get(...params, c.t, c.t, c.id);
    return { ok: true, newItemsAvailable: !!hit };
  }

  fromMyClasses(exposure: ExposureScope, opts: { before?: number; limit?: number }): PublicExperienceV2[] {
    if (this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return [];
    const scoped = this.scopeWhere(exposure);
    if (!scoped) return [];
    const clauses = ["school_id = ?", "status = 'published'", scoped.clause];
    const params: (string | number)[] = [this.schoolId, ...scoped.params];
    if (Number.isFinite(opts.before)) {
      clauses.push("created_at < ?");
      params.push(opts.before as number);
    }
    const limit = Math.min(Math.max(Math.trunc(Number.isFinite(opts.limit) ? (opts.limit as number) : 50), 1), 200);
    const rows = this.db.prepare(`${SELECT} WHERE ${clauses.join(" AND ")} ORDER BY created_at DESC LIMIT ${limit}`).all(...params) as unknown as Row[];
    return rows.filter((r) => !this.frozen(r)).map((r) => this.toPublic(r));
  }

  search(q: string): PublicExperienceV2[] {
    const query = q.trim().slice(0, 60);
    if (!query || this.settings.killSwitch("HIDE_PUBLIC_EXPERIENCES")) return [];
    const rows = this.db
      .prepare(`${SELECT} WHERE school_id = ? AND status = 'published' AND body LIKE ? ESCAPE '\\' ORDER BY created_at DESC, id DESC LIMIT 20`)
      .all(this.schoolId, `%${query.replace(/[\\%_]/g, (m) => "\\" + m)}%`) as unknown as Row[];
    return rows.filter((r) => !this.frozen(r)).map((r) => this.toPublic(r));
  }

  stats(entityKey: string): EntityStatsV2 {
    const sep = entityKey.indexOf(":");
    if (sep <= 0) return { experiences: 0, courses: 0, teachers: 0 };
    const type = entityKey.slice(0, sep);
    const id = entityKey.slice(sep + 1);
    const ids = this.db
      .prepare(
        `SELECT DISTINCT e.id FROM experiences e JOIN experience_associations a ON a.experience_id = e.id
         WHERE e.school_id = ? AND e.status = 'published' AND a.entity_type = ? AND a.entity_id = ?`,
      )
      .all(this.schoolId, type, id) as { id: string }[];
    if (ids.length === 0) return { experiences: 0, courses: 0, teachers: 0 };
    const marks = ids.map(() => "?").join(",");
    const count = (kind: string) =>
      (this.db.prepare(`SELECT COUNT(DISTINCT entity_id) AS n FROM experience_associations WHERE entity_type = ? AND experience_id IN (${marks})`).get(kind, ...ids.map((r) => r.id)) as { n: number }).n;
    return { experiences: ids.length, courses: count("course"), teachers: count("teacher") };
  }
}
