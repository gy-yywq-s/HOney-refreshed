import { describe, it, expect } from "vitest";
import { portalWeekIndex, isUnauthorized, COMMUTER_RECORD_ID } from "./contract.js";

describe("portalWeekIndex", () => {
  it("is stable within a Mon–Sun week and increments across weeks", () => {
    const mon = new Date(2026, 7, 31); // Mon 2026-08-31 (local)
    const sun = new Date(2026, 8, 6, 23, 0, 0); // Sun 2026-09-06
    const nextMon = new Date(2026, 8, 7);
    expect(portalWeekIndex(mon)).toBe(portalWeekIndex(sun));
    expect(portalWeekIndex(nextMon)).toBe(portalWeekIndex(mon) + 1);
  });
});

describe("isUnauthorized", () => {
  it("detects the portal's 401 + 400001 / Unauthorized envelope", () => {
    expect(isUnauthorized(401, { status: 400001 })).toBe(true);
    expect(isUnauthorized(401, { message: "Unauthorized" })).toBe(true);
    expect(isUnauthorized(401, { message: "nope" })).toBe(false);
    expect(isUnauthorized(200, { status: 400001 })).toBe(false);
  });
});

describe("constants", () => {
  it("commuter sentinel is -2", () => {
    expect(COMMUTER_RECORD_ID).toBe(-2);
  });
});
