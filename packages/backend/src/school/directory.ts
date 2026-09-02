// The public entity directory (spec §11, "preferred" option): /api/entities is
// a UNION over the canonical tables — teachers · courses · rooms · dishes —
// so a public Course entity IS a canonical course row, never a copy that can
// drift and never a raw class label. Admin imports land in the same tables
// (source 'admin'), deduplicated through the alias tables.

import type { DatabaseSync } from "node:sqlite";
import type { SchoolProfile } from "./types.js";
import { collapseWhitespace, normalizeForMatch, shortHash } from "./preprocess.js";
import { CanonicalResolver } from "./resolver.js";

export type EntityType = "teacher" | "course" | "room" | "dish";

export interface EntityRow {
  entity_key: string;
  type: EntityType;
  name: string;
  source: "organic" | "admin";
  active: number;
}

const UNION = `
  SELECT 'teacher:' || id AS entity_key, 'teacher' AS type, display_name AS name,
         CASE WHEN source = 'admin' THEN 'admin' ELSE 'organic' END AS source, active
    FROM teachers WHERE school_id = ?
  UNION ALL
  SELECT 'course:' || id, 'course', display_name, CASE WHEN source = 'admin' THEN 'admin' ELSE 'organic' END, active
    FROM courses WHERE school_id = ?
  UNION ALL
  SELECT 'room:' || id, 'room', display_name, CASE WHEN source = 'admin' THEN 'admin' ELSE 'organic' END, active
    FROM rooms WHERE school_id = ?
  UNION ALL
  SELECT 'dish:' || id, 'dish', display_name, 'admin', active FROM dishes WHERE school_id = ?`;

export class EntityDirectory {
  constructor(
    private readonly db: DatabaseSync,
    private readonly profile: SchoolProfile,
    private readonly now: () => number = Date.now,
  ) {}

  private get school(): string {
    return this.profile.id;
  }

  get(entityKey: string): EntityRow | null {
    const row = this.db
      .prepare(`SELECT * FROM (${UNION}) WHERE entity_key = ? AND active = 1`)
      .get(this.school, this.school, this.school, this.school, entityKey) as unknown as EntityRow | undefined;
    return row ?? null;
  }

  /** Display name for a canonical id of a type, active or not (posts keep their context). */
  name(type: EntityType, id: string): string | null {
    const sql: Record<EntityType, string> = {
      teacher: "SELECT display_name AS name FROM teachers WHERE id = ?",
      course: "SELECT display_name AS name FROM courses WHERE id = ?",
      room: "SELECT display_name AS name FROM rooms WHERE id = ?",
      dish: "SELECT display_name AS name FROM dishes WHERE id = ?",
    };
    const row = this.db.prepare(sql[type]).get(id) as { name: string } | undefined;
    return row?.name ?? null;
  }

  list(type?: EntityType, q?: string): EntityRow[] {
    const clauses = ["active = 1"];
    const params: (string | number)[] = [this.school, this.school, this.school, this.school];
    if (type) {
      clauses.push("type = ?");
      params.push(type);
    }
    if (q) {
      clauses.push("name LIKE ? ESCAPE '\\'");
      params.push(`%${q.replace(/[\\%_]/g, (c) => "\\" + c)}%`);
    }
    const limit = type || q ? 200 : 500;
    return this.db
      .prepare(`SELECT * FROM (${UNION}) WHERE ${clauses.join(" AND ")} ORDER BY type, name LIMIT ${limit}`)
      .all(...params) as unknown as EntityRow[];
  }

  count(): number {
    const row = this.db
      .prepare(`SELECT COUNT(*) AS n FROM (${UNION}) WHERE active = 1`)
      .get(this.school, this.school, this.school, this.school) as { n: number };
    return row.n;
  }

  /**
   * Admin bulk import. Teachers and rooms resolve through the same alias
   * tables the importer uses (a spelling the timetable already produced
   * merges); dishes dedupe on their normalized name.
   */
  adminImport(items: { type: EntityType; name: string }[]): { added: number; merged: number } {
    let added = 0;
    let merged = 0;
    const resolver = new CanonicalResolver(this.db, this.profile, this.now);
    this.db.exec("BEGIN");
    try {
      for (const item of items) {
        const name = collapseWhitespace(item.name);
        if (!name) continue;
        if (item.type === "teacher") {
          const before = this.countRows("teachers");
          const id = resolver.resolveTeacher(name);
          if (this.countRows("teachers") > before) {
            this.db.prepare("UPDATE teachers SET source = 'admin' WHERE id = ?").run(id);
            added++;
          } else merged++;
        } else if (item.type === "room") {
          const before = this.countRows("rooms");
          const id = resolver.resolveRoom(null, name);
          if (id && this.countRows("rooms") > before) {
            this.db.prepare("UPDATE rooms SET source = 'admin' WHERE id = ?").run(id);
            added++;
          } else merged++;
        } else if (item.type === "dish") {
          const normalized = normalizeForMatch(name);
          const exists = this.db
            .prepare("SELECT 1 FROM dishes WHERE school_id = ? AND normalized_name = ?")
            .get(this.school, normalized);
          if (exists) {
            merged++;
            continue;
          }
          const id = `d_${shortHash(`${this.school}\0dish\0${normalized}`)}`;
          this.db
            .prepare("INSERT INTO dishes (id, school_id, display_name, normalized_name, active, created_at) VALUES (?, ?, ?, ?, 1, ?)")
            .run(id, this.school, name, normalized, this.now());
          added++;
        } else {
          // Courses are canonical objects produced by the resolver, never typed in by hand.
          merged++;
        }
      }
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return { added, merged };
  }

  setActive(entityKey: string, active: boolean): void {
    const sep = entityKey.indexOf(":");
    if (sep <= 0) return;
    const type = entityKey.slice(0, sep);
    const id = entityKey.slice(sep + 1);
    const table: Record<string, string> = { teacher: "teachers", course: "courses", room: "rooms", dish: "dishes" };
    const t = table[type];
    if (!t) return;
    this.db.prepare(`UPDATE ${t} SET active = ? WHERE id = ?`).run(active ? 1 : 0, id);
  }

  private countRows(table: "teachers" | "rooms"): number {
    return (this.db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get() as { n: number }).n;
  }
}
