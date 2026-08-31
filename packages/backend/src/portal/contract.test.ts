import { describe, it, expect } from "vitest";
import { portalWeekIndex, isUnauthorized, COMMUTER_RECORD_ID } from "@honey/shared";

// Validates that the shared Band-4 contract is consumable across the package
// boundary (typecheck via tsconfig paths, runtime via vitest alias, both → source).
describe("shared portal contract is consumable from @honey/backend", () => {
  it("re-exports resolve and behave across the workspace boundary", () => {
    expect(COMMUTER_RECORD_ID).toBe(-2);
    expect(isUnauthorized(401, { status: 400001 })).toBe(true);
    expect(typeof portalWeekIndex(new Date(2026, 7, 31))).toBe("number");
  });
});
