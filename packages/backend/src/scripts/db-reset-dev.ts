// `pnpm --filter @honey/backend db:reset:dev -- --yes` (spec §12): the
// development reset. No v1→v2 data migration exists by decision; this deletes
// the development database files, recreates the canonical schema, and runs
// the canonicalization assertions over the checked-in real fixture so a fresh
// database is known-good before the service starts again.
//
//   1. stop the service           (operator: systemctl stop honey)
//   2. delete the DB files        (this script, with --yes)
//   3. recreate the clean schema  (this script)
//   4. import + assert the real fixture into a throwaway account (this script)
//   5. start the service          (operator: systemctl start honey)
//   6. sign in on the Web/iOS     (the first sign-in re-imports the real timetable)

import { existsSync, readFileSync, unlinkSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { loadConfig } from "../config.js";
import { ensureSchool, openDatabase } from "../db/database.js";
import { lessonsFromFixture, type SchoolFixture } from "../school/adapter.js";
import { SchoolImportService } from "../school/import.js";
import { profileFor } from "../school/profiles/huayaopudong.js";
import { TimetableService } from "../services/timetable.js";

const args = new Set(process.argv.slice(2));
const config = loadConfig();
const dbPath = config.dbPath;

if (!args.has("--yes")) {
  console.log(`This deletes the development database at ${dbPath} (plus -wal/-shm) and recreates the canonical schema.`);
  console.log("Stop the service first, then re-run with --yes.");
  process.exit(2);
}

for (const suffix of ["", "-wal", "-shm"]) {
  const p = `${dbPath}${suffix}`;
  if (existsSync(p)) {
    unlinkSync(p);
    console.log(`deleted ${p}`);
  }
}

const db = openDatabase(dbPath);
const profile = profileFor(config.schoolId);
ensureSchool(db, profile.id, config.schoolName);
console.log(`created canonical schema at ${dbPath} for school ${profile.id}`);

// Canonicalization assertions over the real fixture (roster-free records).
const fixturePath = fileURLToPath(new URL("../../fixtures/school/oasis-2026-autumn.json", import.meta.url));
const fixture = JSON.parse(readFileSync(fixturePath, "utf8")) as SchoolFixture;
db.prepare(
  "INSERT INTO honey_users (honey_id, school_account_key, display_name, student_type, created_at, is_admin) VALUES ('reset0', 'reset-check', '', 1, ?, 0)",
).run(Date.now());
const counts = new SchoolImportService(db, profile).importLessons("reset0", lessonsFromFixture(fixture));
const directory = new TimetableService(db).directory("reset0");
const courseNames = directory.courses.map((c) => c.name);
const problems: string[] = [];
if (!courseNames.includes("AL ECON U4")) problems.push("AL ECON U4 missing");
if (!courseNames.includes("AL ECON U3")) problems.push("AL ECON U3 missing");
if (courseNames.some((n) => /备考|班|20\d\d/.test(n))) problems.push("a class label leaked into a course name");
if (counts.unresolved > 0) problems.push(`${counts.unresolved} unresolved labels`);
// The throwaway account and everything it exposed go away; canonical rows stay.
db.prepare("DELETE FROM honey_users WHERE honey_id = 'reset0'").run();
db.prepare("DELETE FROM import_runs WHERE honey_id = 'reset0'").run();
db.close();

console.log(`fixture import: ${counts.lessons} lessons, ${counts.courses} courses, ${counts.teachers} teachers, ${counts.rooms} rooms`);
console.log(`courses: ${courseNames.join(" · ")}`);
if (problems.length > 0) {
  console.error(`canonicalization assertions FAILED: ${problems.join("; ")}`);
  process.exit(1);
}
console.log("canonicalization assertions passed — start the service and sign in to import the live timetable.");
