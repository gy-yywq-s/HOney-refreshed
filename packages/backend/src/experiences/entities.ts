import { createHash } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

// Entity registry: reviewable standalone objects are teacher / course / room /
// dish (course became first-class in the product-v2 reset — review v3 §9.10:
// pace/workload/assessment experience is course-level, not teacher-persona).
// Teachers, courses & rooms accrue ORGANICALLY from timetable imports; the
// admin can ALSO import independently; the visible set is the union, merged
// by name so admin duplicates of organic entities collapse.

export type EntityType = "teacher" | "course" | "room" | "dish";

/**
 * Portal course names arrive as "Subject 班名 teacher 学生名册串" — the
 * trailing roster is a run of student surnames (design-is r1: student
 * surnames must not surface in a product that says students aren't public
 * subjects). Rule: with ≥3 tokens, drop a trailing token that is ≥4 chars
 * of pure CJK UNLESS it is the lesson's own teacher name (r2: "活动课老师"
 * is a 5-char teacher, and the ≤3-char assumption over-stripped it).
 * Applied ONCE, at import — the registry mirrors the stored name verbatim,
 * so the directory and the registry can never disagree.
 */
export function sanitizeCourseName(raw: string, teacherName?: string | null): string {
  const name = raw.trim().replace(/\s+/g, " ");
  const tokens = name.split(" ");
  if (tokens.length >= 3) {
    const last = tokens[tokens.length - 1]!;
    const isTeacher = teacherName !== undefined && teacherName !== null && last === teacherName.trim();
    if (!isTeacher && last.length >= 4 && /^[\u3400-\u9fff]+$/.test(last)) {
      return tokens.slice(0, -1).join(" ");
    }
  }
  return name;
}

export interface EntityRow {
  entity_key: string;
  type: EntityType;
  name: string;
  source: "organic" | "admin";
  active: number;
  created_at: number;
}

export class EntityRegistry {
  constructor(private readonly db: DatabaseSync, private readonly now: () => number = Date.now) {}

  /** Mirror organic teachers/rooms from the normalized timetable tables. */
  syncOrganic(): void {
    const upsert = this.db.prepare(
      `INSERT INTO entity_registry (entity_key, type, name, source, active, created_at)
       VALUES (?, ?, ?, 'organic', 1, ?)
       ON CONFLICT(entity_key) DO UPDATE SET name = excluded.name`,
    );
    const teachers = this.db.prepare("SELECT id, display_name FROM teachers").all() as unknown as {
      id: string;
      display_name: string;
    }[];
    for (const t of teachers) upsert.run(`teacher:${t.id}`, "teacher", t.display_name, this.now());
    const courses = this.db.prepare("SELECT id, name FROM courses").all() as unknown as {
      id: string;
      name: string;
    }[];
    for (const c of courses) upsert.run(`course:${c.id}`, "course", c.name, this.now());

    // Rooms: hygiene before mirroring (design-is r1). Placeholder names
    // ("Not selected") never surface, and duplicate names across import
    // eras collapse — the id the most recent lesson actually uses wins;
    // the losers' registry rows deactivate so Explore lists each real
    // room exactly once. (Old per-id feeds stay reachable by URL.)
    const rooms = this.db.prepare("SELECT id, name FROM rooms").all() as unknown as {
      id: string;
      name: string;
    }[];
    const lastUse = this.db.prepare(
      "SELECT MAX(starts_at) AS t FROM lesson_instances WHERE room_id = ?",
    );
    const deactivate = this.db.prepare(
      "UPDATE entity_registry SET active = 0 WHERE entity_key = ? AND source = 'organic'",
    );
    const byName = new Map<string, { id: string; name: string; t: number }>();
    for (const r of rooms) {
      const name = r.name.trim();
      if (!name || name.toLowerCase() === "not selected") {
        deactivate.run(`room:${r.id}`);
        continue;
      }
      const t = Number((lastUse.get(r.id) as { t: number | null } | undefined)?.t ?? 0);
      const fold = name.toLowerCase();
      const cur = byName.get(fold);
      if (!cur || t > cur.t) {
        if (cur) deactivate.run(`room:${cur.id}`);
        byName.set(fold, { id: r.id, name, t });
      } else {
        deactivate.run(`room:${r.id}`);
      }
    }
    for (const w of byName.values()) upsert.run(`room:${w.id}`, "room", w.name, this.now());
  }

  /**
   * Admin bulk import. Dedup rule: if an entity of the same type with the same
   * (case-folded) name already exists — organic or admin — the row is skipped,
   * so the result is a clean union.
   */
  adminImport(items: { type: EntityType; name: string }[]): { added: number; merged: number } {
    let added = 0;
    let merged = 0;
    const existing = this.db
      .prepare("SELECT type, name FROM entity_registry WHERE active = 1")
      .all() as unknown as { type: string; name: string }[];
    const seen = new Set(existing.map((e) => `${e.type}\u0000${e.name.trim().toLowerCase()}`));
    const insert = this.db.prepare(
      `INSERT INTO entity_registry (entity_key, type, name, source, active, created_at)
       VALUES (?, ?, ?, 'admin', 1, ?) ON CONFLICT(entity_key) DO NOTHING`,
    );
    for (const item of items) {
      const name = item.name.trim();
      if (!name) continue;
      const fold = `${item.type}\u0000${name.toLowerCase()}`;
      if (seen.has(fold)) {
        merged++;
        continue;
      }
      const key = `${item.type}:a_${createHash("sha256").update(fold).digest("hex").slice(0, 12)}`;
      insert.run(key, item.type, name, this.now());
      seen.add(fold);
      added++;
    }
    return { added, merged };
  }

  get(entityKey: string): EntityRow | null {
    const row = this.db
      .prepare("SELECT * FROM entity_registry WHERE entity_key = ? AND active = 1")
      .get(entityKey) as unknown as EntityRow | undefined;
    return row ?? null;
  }

  list(type?: EntityType, q?: string): EntityRow[] {
    if (type && q) {
      return this.db
        .prepare(
          "SELECT * FROM entity_registry WHERE active = 1 AND type = ? AND name LIKE ? ORDER BY name LIMIT 200",
        )
        .all(type, `%${q}%`) as unknown as EntityRow[];
    }
    if (type) {
      return this.db
        .prepare("SELECT * FROM entity_registry WHERE active = 1 AND type = ? ORDER BY name LIMIT 200")
        .all(type) as unknown as EntityRow[];
    }
    if (q) {
      return this.db
        .prepare("SELECT * FROM entity_registry WHERE active = 1 AND name LIKE ? ORDER BY name LIMIT 200")
        .all(`%${q}%`) as unknown as EntityRow[];
    }
    return this.db
      .prepare("SELECT * FROM entity_registry WHERE active = 1 ORDER BY type, name LIMIT 500")
      .all() as unknown as EntityRow[];
  }

  setActive(entityKey: string, active: boolean): void {
    this.db
      .prepare("UPDATE entity_registry SET active = ? WHERE entity_key = ?")
      .run(active ? 1 : 0, entityKey);
  }
}
