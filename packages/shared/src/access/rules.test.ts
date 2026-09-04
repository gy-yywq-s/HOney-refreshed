import { describe, expect, it } from "vitest";
import { displayStatus, formatPortalTime, isConsumed, isOpenable, openablePermits, parsePortalTime, permitFromWire, permitTone } from "./rules.js";

// Access domain rules (spec §25 "stale permits read-only", Gary's consumed
// rule): a permit is openable only when approved, unused and inside its
// window; consumption wins over a stale approved status.

const base = { record_id: 501, staff_id: 9, staff_name: "Mr Approver", status: 1 as const, status_name: "通过", note: "出门", flag: 0, start_time: "2026-08-31 08:00:00", end_time: "2026-08-31 22:00:00", create_time: "2026-08-30 12:00:00", update_time: "2026-08-30 13:00:00" };
const inWindow = parsePortalTime("2026-08-31 12:00:00")!;

describe("portal time", () => {
  it("parses and formats in the school zone (UTC+8)", () => {
    expect(parsePortalTime("2026-08-31 08:00:00")).toBe(Date.UTC(2026, 7, 31, 0, 0, 0));
    expect(formatPortalTime(Date.UTC(2026, 7, 31, 0, 0, 0))).toBe("2026-08-31 08:00:00");
    expect(parsePortalTime("nonsense")).toBeNull();
  });
});

describe("permit rules", () => {
  it("approved + unused + in window → openable; consumed or out of window → not", () => {
    const p = permitFromWire(base);
    expect(isOpenable(p, inWindow)).toBe(true);
    expect(isOpenable(p, parsePortalTime("2026-08-31 23:00:00")!)).toBe(false);
    expect(isOpenable(permitFromWire({ ...base, flag: 1 }), inWindow)).toBe(false);
    expect(isOpenable(permitFromWire({ ...base, status: 3 }), inWindow)).toBe(false);
    expect(isOpenable(permitFromWire({ ...base, status: 0 }), inWindow)).toBe(false);
    expect(isConsumed(permitFromWire({ ...base, flag: 2 }))).toBe(true);
  });

  it("status text and tone reflect consumption before approval", () => {
    expect(displayStatus(permitFromWire(base))).toBe("通过");
    expect(displayStatus(permitFromWire({ ...base, flag: 1 }))).toBe("Used");
    expect(permitTone(permitFromWire(base), inWindow)).toBe("ok");
    expect(permitTone(permitFromWire({ ...base, flag: 1 }), inWindow)).toBe("muted");
    expect(permitTone(permitFromWire({ ...base, status: 0, status_name: "" }), inWindow)).toBe("warning");
    expect(openablePermits([permitFromWire(base), permitFromWire({ ...base, record_id: 502, flag: 1 })], inWindow).map((p) => p.recordId)).toEqual([501]);
  });
});
