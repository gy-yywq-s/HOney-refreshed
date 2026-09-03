import type { DatabaseSync } from "node:sqlite";
import type { SchoolNoticeWire } from "@honey/shared";
import type { SchoolNotice } from "@honey/shared/api";
import { parsePortalTime } from "@honey/shared/access";

// School notices (spec §5.2 boundary, Gary 2026-09-03). The portal publishes
// them campus-wide; HOney stores the school's own words verbatim — plain text,
// newlines kept, never translated, never summarised — and keeps no per-student
// state here: the portal has no per-student read flag (its dashboard endpoint
// returns a bare count), so "read" is a per-device fact the web app owns.

export class NoticeService {
  constructor(
    private readonly db: DatabaseSync,
    private readonly schoolId: string,
    private readonly sourceSystem: string,
    private readonly now: () => number = Date.now,
  ) {}

  /** Persist a fetched notice list; returns how many rows were written. */
  upsert(rows: SchoolNoticeWire[]): number {
    const fetchedAt = this.now();
    const stmt = this.db.prepare(
      `INSERT INTO school_notices (id, school_id, source_system, source_notice_id, title, body, posted_at, updated_at, fetched_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         title = excluded.title, body = excluded.body, posted_at = excluded.posted_at,
         updated_at = excluded.updated_at, fetched_at = excluded.fetched_at`,
    );
    let written = 0;
    this.db.exec("BEGIN");
    try {
      for (const row of rows) {
        const sourceId = String(row.id);
        const postedAt = parsePortalTime(row.create_time);
        if (postedAt === null) continue; // A row without a usable date is not shown as news.
        const updatedAt = parsePortalTime(row.update_time) ?? postedAt;
        stmt.run(
          `${this.schoolId}:${this.sourceSystem}:${sourceId}`,
          this.schoolId,
          this.sourceSystem,
          sourceId,
          row.title.trim(),
          row.content.replace(/\r\n/g, "\n").trim(),
          postedAt,
          updatedAt,
          fetchedAt,
        );
        written++;
      }
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
    return written;
  }

  /** Newest first. */
  list(limit = 50): SchoolNotice[] {
    const rows = this.db
      .prepare(
        `SELECT source_notice_id, title, body, posted_at, updated_at
           FROM school_notices WHERE school_id = ? AND source_system = ?
          ORDER BY posted_at DESC LIMIT ?`,
      )
      .all(this.schoolId, this.sourceSystem, Math.min(Math.max(limit, 1), 200)) as unknown as {
      source_notice_id: string;
      title: string;
      body: string;
      posted_at: number;
      updated_at: number;
    }[];
    return rows.map((r) => ({
      id: r.source_notice_id,
      title: r.title,
      body: r.body,
      postedAt: r.posted_at,
      updatedAt: r.updated_at,
    }));
  }

  /** When HOney last read the portal's list (null before the first sync). */
  fetchedAt(): number | null {
    const row = this.db
      .prepare("SELECT MAX(fetched_at) AS at FROM school_notices WHERE school_id = ? AND source_system = ?")
      .get(this.schoolId, this.sourceSystem) as unknown as { at: number | null } | undefined;
    return row?.at ?? null;
  }
}
