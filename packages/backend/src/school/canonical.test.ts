import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { Lesson } from "@honey/shared";
import { ensureSchool, openDatabase, SchemaEpochError, type DatabaseSync } from "../db/database.js";
import { lessonsFromFixture, type SchoolFixture } from "./adapter.js";
import { EntityDirectory } from "./directory.js";
import { SchoolImportService } from "./import.js";
import { redactRoster } from "./preprocess.js";
import { huayaopudong } from "./profiles/huayaopudong.js";
import { TimetableService } from "../services/timetable.js";

// Canonical school data acceptance (spec 2026-09-03 §13): REAL fixture records
// (rosters redacted at capture), never hand-made samples. The hard criteria:
// a portal class id is never a course id; a class label is never a public
// course name; one Course across sections/teachers/terms; units stay apart;
// roster text reaches no canonical table; topic never becomes a course; the
// section is stored but is not an Experiences entity; unresolved labels are
// visible and never pollute the browse list.

const fixture: SchoolFixture = JSON.parse(
  readFileSync(fileURLToPath(new URL("../../fixtures/school/oasis-2026-autumn.json", import.meta.url)), "utf8"),
);

let tmp: string;
let db: DatabaseSync;
let importer: SchoolImportService;
let directory: EntityDirectory;
let timetable: TimetableService;

function addUser(id: string) {
  db.prepare(
    "INSERT INTO honey_users (honey_id, school_account_key, display_name, student_type, created_at, is_admin) VALUES (?, ?, '', 1, 0, 0)",
  ).run(id, `key-${id}`);
}

beforeEach(() => {
  tmp = mkdtempSync(join(tmpdir(), "honey-canon-"));
  db = openDatabase(join(tmp, "core.db"));
  ensureSchool(db, huayaopudong.id, huayaopudong.canonicalName);
  importer = new SchoolImportService(db, huayaopudong, () => 1_000);
  directory = new EntityDirectory(db, huayaopudong, () => 1_000);
  timetable = new TimetableService(db, () => 1_900_000_000_000);
  addUser("u1");
});

afterEach(() => {
  db.close();
  rmSync(tmp, { recursive: true, force: true });
});

function rows<T>(sql: string, ...params: (string | number)[]): T[] {
  return db.prepare(sql).all(...params) as unknown as T[];
}

describe("real fixture import", () => {
  it("resolves every portal subject label to one canonical Course; sections and lessons hang off it", () => {
    const counts = importer.importLessons("u1", lessonsFromFixture(fixture));
    expect(counts.unresolved).toBe(0);
    expect(counts.lessons).toBeGreaterThan(100);

    const courses = rows<{ canonical_code: string; display_name: string; level: string | null; unit_code: string | null; qualification: string | null }>(
      "SELECT canonical_code, display_name, level, unit_code, qualification FROM courses ORDER BY canonical_code",
    );
    expect(courses.map((c) => c.canonical_code)).toEqual([
      "AL CHIN", "AL ECON U3", "AL ECON U4", "AL PHYS A2", "Activity", "IELTS Speaking", "Public Speaking", "TMUA",
    ]);
    const econ4 = courses.find((c) => c.canonical_code === "AL ECON U4")!;
    expect(econ4).toMatchObject({ display_name: "AL ECON U4", level: "AL", unit_code: "U4", qualification: "Edexcel IAL" });

    // Hard criteria 1–2: no portal class id or class label anywhere near a course.
    const classIds = new Set(Object.values(fixture.weekly).flatMap((w) => w.lessons.map((l) => String(l.class_id))));
    for (const c of rows<{ id: string; display_name: string }>("SELECT id, display_name FROM courses")) {
      expect(classIds.has(c.id.replace(/^c_/, ""))).toBe(false);
      expect(c.display_name).not.toMatch(/备考|强化|进阶|班|20\d\d|秋/);
    }
  });

  it("the class label becomes a section of the course — term + group type, no roster, no teacher", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    const sections = rows<{ source_class_id: string; section_name: string | null; academic_year: string | null; term: string | null; course: string; teacher: string | null }>(
      `SELECT s.source_class_id, s.section_name, s.academic_year, s.term, c.canonical_code AS course, t.display_name AS teacher
       FROM class_sections s JOIN courses c ON c.id = s.course_id LEFT JOIN teachers t ON t.id = s.teacher_id ORDER BY s.source_class_id`,
    );
    const econ4 = sections.find((s) => s.source_class_id === "55566")!;
    expect(econ4).toMatchObject({ course: "AL ECON U4", section_name: "2026 Autumn · Prep Class", academic_year: "2026-27", term: "2026 Autumn", teacher: "朱昂明" });
    expect(sections.find((s) => s.source_class_id === "55965")!.section_name).toBe("2026 Autumn · Prep Class 5");
    expect(sections.find((s) => s.source_class_id === "56081")!.section_name).toBe("2026 Autumn · Intensive Class");
    expect(sections.find((s) => s.source_class_id === "55819")!.section_name).toBe("2026 Autumn · Advanced Class");
    expect(sections.find((s) => s.source_class_id === "55738")!.section_name).toBe("2026 Autumn · Prep Class");
    // A bare class label (TMUA) carries no section fact: nothing invented.
    expect(sections.find((s) => s.source_class_id === "56284")!.section_name).toBeNull();
    for (const s of sections) {
      expect(s.section_name ?? "").not.toMatch(/朱昂明|陈拯侃|赵流畅|ChenJenny|活动课老师|方老师/);
    }
  });

  it("U3 and U4 stay separate courses; teachers, rooms and topics normalize; 'Not selected' is no room", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    const codes = rows<{ canonical_code: string }>("SELECT canonical_code FROM courses WHERE canonical_code LIKE 'AL ECON%'").map((r) => r.canonical_code);
    expect(codes.sort()).toEqual(["AL ECON U3", "AL ECON U4"]);

    const teachers = rows<{ display_name: string }>("SELECT display_name FROM teachers ORDER BY display_name").map((r) => r.display_name);
    expect(teachers).toEqual(["ChenJenny", "方老师", "朱昂明", "活动课老师", "赵流畅", "陈拯侃"]);

    const roomNames = rows<{ display_name: string }>("SELECT display_name FROM rooms ORDER BY display_name").map((r) => r.display_name);
    expect(roomNames).toEqual(["213", "308", "309", "416", "A4"]);
    // The lesson-table room id (345) and the weekly room label ("309") map to ONE room.
    const aliases = rows<{ alias_kind: string; alias_value: string; room_id: string }>("SELECT alias_kind, alias_value, room_id FROM room_aliases");
    const byId = aliases.find((a) => a.alias_kind === "source_id" && a.alias_value === "345")!;
    const byName = aliases.find((a) => a.alias_kind === "name" && a.alias_value === "309")!;
    expect(byId.room_id).toBe(byName.room_id);
    expect(rows<{ n: number }>("SELECT COUNT(*) AS n FROM lesson_instances WHERE room_id IS NULL")[0]!.n).toBeGreaterThan(0);

    // The portal repeats the subject as the topic: that is no topic.
    expect(rows<{ n: number }>("SELECT COUNT(*) AS n FROM lesson_instances WHERE topic_name IS NOT NULL")[0]!.n).toBe(0);
  });

  it("read paths carry canonical names only; the section is context, never a browse entity", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    const history = timetable.history("u1", { limit: 500, order: "asc" });
    expect(history.length).toBeGreaterThan(0);
    const econ = history.find((l) => l.courseName === "AL ECON U4")!;
    // The Subject layer is the broad area; the Course carries the unit.
    expect(econ.subjectName).toBe("Economics");
    expect(econ.classSectionName).toBe("2026 Autumn · Prep Class");
    expect(econ.teacherName).toBe("朱昂明");
    expect(econ.roomName).toBe("309");
    expect(history.every((l) => !/备考|班/.test(l.courseName ?? ""))).toBe(true);

    const dir = timetable.directory("u1");
    expect(dir.courses.map((c) => c.name)).toContain("AL ECON U4");
    expect(dir.rooms.map((r) => r.name)).not.toContain("Not selected");

    const entities = directory.list();
    expect(entities.filter((e) => e.type === "course").map((e) => e.name).sort()).toEqual(
      ["AL CHIN", "AL ECON U3", "AL ECON U4", "AL PHYS A2", "Activity", "IELTS Speaking", "Public Speaking", "TMUA"],
    );
    expect(entities.some((e) => /section|班/.test(e.name))).toBe(false);
    expect(entities.filter((e) => e.type === "room").map((e) => e.name).sort()).toEqual(["213", "308", "309", "416", "A4"]);
  });

  it("is idempotent across re-imports and stable across accounts and spellings", () => {
    const lessons = lessonsFromFixture(fixture);
    importer.importLessons("u1", lessons);
    const before = rows<{ n: number }>("SELECT COUNT(*) AS n FROM courses")[0]!.n;
    importer.importLessons("u1", lessons);
    addUser("u2");
    importer.importLessons("u2", lessons);
    expect(rows<{ n: number }>("SELECT COUNT(*) AS n FROM courses")[0]!.n).toBe(before);
    expect(rows<{ n: number }>("SELECT COUNT(*) AS n FROM teachers")[0]!.n).toBe(6);

    // A respelled label (case, spacing) with no source subject id resolves to
    // the SAME course and teacher through the normalized-label alias.
    const respelled: Lesson[] = lessons.slice(0, 1).map((l) => {
      const { subjectId: _sid, ...rest } = l;
      return { ...rest, id: "999001", subjectName: "EDEXCEL  Economics-U4", teacherDisplayName: "朱昂明 " };
    });
    importer.importLessons("u1", respelled);
    const row = rows<{ course: string; teacher: string }>(
      "SELECT c.canonical_code AS course, t.display_name AS teacher FROM lesson_instances li JOIN courses c ON c.id = li.course_id JOIN teachers t ON t.id = li.teacher_id WHERE li.id = '999001'",
    )[0]!;
    expect(row).toEqual({ course: "AL ECON U4", teacher: "朱昂明" });
    expect(rows<{ n: number }>("SELECT COUNT(*) AS n FROM courses")[0]!.n).toBe(before);
  });
});

describe("unknown labels", () => {
  it("leave the lesson subject-only and record an unresolved label instead of a public course", () => {
    const lesson: Lesson = {
      id: "777",
      subjectName: "Cake Decorating Elective",
      teacherDisplayName: "Ms New",
      startsAt: new Date(1_788_000_000_000),
      endsAt: new Date(1_788_003_600_000),
      conflict: false,
      conflictWith: [],
    };
    const counts = importer.importLessons("u1", [lesson]);
    expect(counts.unresolved).toBe(1);
    expect(counts.courses).toBe(0);
    const li = rows<{ course_id: string | null; subject_name: string }>("SELECT course_id, subject_name FROM lesson_instances WHERE id = '777'")[0]!;
    expect(li.course_id).toBeNull();
    expect(li.subject_name).toBe("Cake Decorating Elective");
    expect(directory.list("course")).toHaveLength(0);
    expect(importer.unresolvedLabels()).toEqual([
      expect.objectContaining({ fieldKind: "course", rawValue: "Cake Decorating Elective" }),
    ]);
  });

  it("parses a common Board Subject-Unit variant without an alias entry", () => {
    const lesson: Lesson = {
      id: "778",
      subjectName: "CIE Chemistry-AS",
      startsAt: new Date(1_788_000_000_000),
      endsAt: new Date(1_788_003_600_000),
      conflict: false,
      conflictWith: [],
    };
    importer.importLessons("u1", [lesson]);
    expect(rows<{ canonical_code: string; level: string; qualification: string }>("SELECT canonical_code, level, qualification FROM courses")[0]).toMatchObject({
      canonical_code: "AS CHEM AS",
      level: "AS",
      qualification: "CIE",
    });
  });
});

describe("period slots → teaching time", () => {
  const SHANGHAI = (ms: number) => new Date(ms + 8 * 3600 * 1000).toISOString().slice(11, 16);

  it("stores when teaching ends (slot end − 10 min) and keeps the slot end as the source fact", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    // A single period: 16:30–18:00 on the portal → teaching 16:30–17:50.
    const single = rows<{ starts_at: number; ends_at: number; slot_ends_at: number }>(
      "SELECT starts_at, ends_at, slot_ends_at FROM lesson_instances WHERE id = '1322902'",
    )[0]!;
    expect([SHANGHAI(single.starts_at), SHANGHAI(single.ends_at), SHANGHAI(single.slot_ends_at)]).toEqual(["16:30", "17:50", "18:00"]);
    // The TMUA double period: 13:30–16:30 → 16:20.
    const dbl = rows<{ starts_at: number; ends_at: number; slot_ends_at: number }>(
      "SELECT starts_at, ends_at, slot_ends_at FROM lesson_instances WHERE id = '1344211'",
    )[0]!;
    expect([SHANGHAI(dbl.starts_at), SHANGHAI(dbl.ends_at), SHANGHAI(dbl.slot_ends_at)]).toEqual(["13:30", "16:20", "16:30"]);
    // No real lesson is 90 min long any more; every one is 80 or 170.
    const spans = rows<{ mins: number; n: number }>(
      "SELECT (ends_at - starts_at) / 60000 AS mins, COUNT(*) AS n FROM lesson_instances GROUP BY mins ORDER BY mins",
    );
    expect(spans.map((s) => s.mins)).toEqual([80, 170]);
  });

  it("leaves a duration that is not on the period grid as written", () => {
    importer.importLessons("u1", [
      { id: "779", subjectName: "Activity", startsAt: new Date(1_788_000_000_000), endsAt: new Date(1_788_003_600_000), conflict: false, conflictWith: [] },
    ]);
    const li = rows<{ ends_at: number; slot_ends_at: number }>("SELECT ends_at, slot_ends_at FROM lesson_instances WHERE id = '779'")[0]!;
    expect(li).toEqual({ ends_at: 1_788_003_600_000, slot_ends_at: 1_788_003_600_000 });
  });

  it("migration 006 moves rows imported before the rule and the next import agrees with it", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    // Put one row back the way the earlier epoch stored it and re-run the migration's statement.
    db.exec("UPDATE lesson_instances SET ends_at = slot_ends_at, slot_ends_at = NULL WHERE id = '1322902'");
    db.exec(
      "UPDATE lesson_instances SET slot_ends_at = ends_at, ends_at = ends_at - 600000 WHERE slot_ends_at IS NULL AND (ends_at - starts_at) > 0 AND (ends_at - starts_at) % 5400000 = 0",
    );
    const moved = rows<{ ends_at: number; slot_ends_at: number }>("SELECT ends_at, slot_ends_at FROM lesson_instances WHERE id = '1322902'")[0]!;
    expect(SHANGHAI(moved.ends_at)).toBe("17:50");
    importer.importLessons("u1", lessonsFromFixture(fixture));
    const again = rows<{ ends_at: number; slot_ends_at: number }>("SELECT ends_at, slot_ends_at FROM lesson_instances WHERE id = '1322902'")[0]!;
    expect(again).toEqual(moved);
  });
});

describe("roster redaction (§6.2)", () => {
  it("cuts everything after the teacher token, and long CJK runs when no teacher token exists", () => {
    expect(redactRoster(" Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明 张王李赵", "朱昂明")).toBe(
      "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明",
    );
    expect(redactRoster("Activity 2026年秋活动课 活动课老师 张王李赵钱孙周吴", null)).toBe("Activity 2026年秋活动课 活动课老师");
    expect(redactRoster("TMUA", "方老师")).toBe("TMUA");
  });
});

describe("entity directory", () => {
  it("admin imports merge with canonical rows through the same aliases; dishes are their own table", () => {
    importer.importLessons("u1", lessonsFromFixture(fixture));
    const result = directory.adminImport([
      { type: "teacher", name: "朱昂明" },
      { type: "teacher", name: "Mr Brand-New" },
      { type: "room", name: "309" },
      { type: "room", name: "Library" },
      { type: "dish", name: "麻婆豆腐" },
      { type: "dish", name: "麻婆豆腐 " },
    ]);
    expect(result).toEqual({ added: 3, merged: 3 });
    expect(directory.list("dish").map((e) => e.name)).toEqual(["麻婆豆腐"]);
    expect(directory.get(directory.list("dish")[0]!.entity_key)?.type).toBe("dish");
    expect(directory.list("room").map((e) => e.name)).toContain("Library");
    directory.setActive(directory.list("room").find((e) => e.name === "Library")!.entity_key, false);
    expect(directory.list("room").map((e) => e.name)).not.toContain("Library");
  });
});

describe("schema epoch guard", () => {
  it("refuses a database from another epoch instead of reshaping it", () => {
    const path = join(tmp, "old.db");
    const old = openDatabase(path);
    old.prepare("UPDATE schema_epoch SET epoch = 'pre-canonical'").run();
    old.close();
    expect(() => openDatabase(path)).toThrow(SchemaEpochError);
  });
});
