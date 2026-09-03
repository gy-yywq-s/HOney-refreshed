import type { DatabaseSync } from "node:sqlite";
import type { Lesson } from "@honey/shared";
import { PortalApi, joinLessons, mergeLessonsById, normalizeTableLessons, retrySafeRead } from "@honey/portal-connector";
import { portalWeekIndex } from "@honey/shared";
import type { AccountService } from "./accounts.js";
import { SchoolImportService } from "../school/import.js";
import type { SchoolProfile } from "../school/types.js";
import type { NoticeService } from "./notices.js";

// Timetable import (Band 4 → Band 3 handoff): pulls upstream weeks with the
// stored portal token and hands the normalized lessons to the canonical
// importer, which writes stable Subject / Course / Section / Teacher / Room /
// Lesson objects and the user's exposure. Raw payloads never leave this
// module (spec §5.2); rosters are cut before the resolver sees a label.

export interface SyncResult {
  lessons: number;
  teachers: number;
  courses: number;
  rooms: number;
  unresolved: number;
  status: "ok" | "portal_reconnect_required" | "no_consent";
}

const EMPTY: Omit<SyncResult, "status"> = { lessons: 0, teachers: 0, courses: 0, rooms: 0, unresolved: 0 };

export class ImportService {
  readonly school: SchoolImportService;

  constructor(
    db: DatabaseSync,
    private readonly accounts: AccountService,
    private readonly api: PortalApi,
    profile: SchoolProfile,
    private readonly notices: NoticeService | null = null,
    private readonly now: () => Date = () => new Date(),
  ) {
    this.school = new SchoolImportService(db, profile, () => this.now().getTime());
  }

  /**
   * Sync the term the Lesson Table covers plus the viewable past weeks. Uses
   * the sealed portal token; on expiry marks the connection for client-driven
   * reconnect (the backend holds no school password — by design it cannot
   * re-login itself).
   */
  async syncTimetable(honeyId: string): Promise<SyncResult> {
    // No consent gate (2026-09-01): the school sign-in is the import decision.
    // `no_consent` stays in the status union only for wire compatibility.
    const conn = this.accounts.loadPortalToken(honeyId);
    if (!conn) return { ...EMPTY, status: "portal_reconnect_required" };

    const nowDate = this.now();

    let lessons: Lesson[];
    try {
      const studentId = Number(conn.studentId);
      // The Lesson Table carries the whole current+future term with real times in
      // ONE request — it is the primary source. The weekly schedule is only used
      // for the PAST weeks the table can't see (and the current week, to pick up
      // the few lessons the table omits + per-section class data).
      const table = await retrySafeRead(() => this.api.lessonTable(conn.token));
      const tableLessons = normalizeTableLessons(table);

      const nowWeek = portalWeekIndex(nowDate);
      const recentWeeks = [nowWeek - 2, nowWeek - 1, nowWeek];
      const weekly = await Promise.all(
        recentWeeks.map((w) => retrySafeRead(() => this.api.weeklySchedule(conn.token, studentId, w))),
      );
      const weeklyJoined = joinLessons(weekly.flatMap((w) => w.lessons), table);

      // Weekly wins on overlap (history + class data + any current lesson the
      // table omitted); the table supplies everything from this week onward.
      lessons = mergeLessonsById(tableLessons, weeklyJoined);
    } catch (e) {
      if (e instanceof Error && "info" in e) {
        const kind = (e as { info: { kind: string } }).info.kind;
        if (kind === "sessionExpired") {
          this.accounts.markPortalExpired(honeyId);
          return { ...EMPTY, status: "portal_reconnect_required" };
        }
      }
      throw e;
    }

    const counts = this.upsertLessons(honeyId, lessons);
    // The school's notices ride along on the same sync (Gary 2026-09-03).
    // They are campus-wide, not this student's data, and a notice failure
    // must never cost the student their timetable: it is swallowed here and
    // the previously stored list keeps being served.
    if (this.notices) {
      try {
        this.notices.upsert(await retrySafeRead(() => this.api.noticeList(conn.token)));
      } catch {
        /* keep the stored notices */
      }
    }
    this.accounts.markSynced(honeyId);
    return { ...counts, status: "ok" };
  }

  /** Persistence of already-normalized lessons through the canonical resolver (also used by seeds/tests). */
  upsertLessons(honeyId: string, lessons: Lesson[]): Omit<SyncResult, "status"> {
    const { lessons: n, teachers, courses, rooms, unresolved } = this.school.importLessons(honeyId, lessons);
    return { lessons: n, teachers, courses, rooms, unresolved };
  }
}
