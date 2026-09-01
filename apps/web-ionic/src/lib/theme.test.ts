// Theme mechanism contract: the persisted keys and value sets the pre-paint
// boot script in index.html relies on. If these change, index.html must too.

import { describe, expect, it } from "vitest";
import { DEFAULT_SURFACE, SURFACE_KEY, SURFACE_OPTIONS, normalizeSurface } from "./theme";

describe("theme", () => {
  it("persists under the agreed localStorage key", () => {
    expect(SURFACE_KEY).toBe("honey.theme.surface");
  });

  it("offers the four surfaces with stone as default", () => {
    expect(SURFACE_OPTIONS.map((o) => o.value)).toEqual(["stone", "white", "mist", "night"]);
    expect(DEFAULT_SURFACE).toBe("stone");
  });

  it("normalizes unknown stored values to the defaults", () => {
    expect(normalizeSurface("paper")).toBe("stone");
    expect(normalizeSurface(null)).toBe("stone");
    expect(normalizeSurface("night")).toBe("night");
  });
});
