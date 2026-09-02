// Theme mechanism contract: the persisted keys and value sets the pre-paint
// boot script in index.html relies on. If these change, index.html must too.

import { describe, expect, it } from "vitest";
import {
  ACCENT_KEY,
  ACCENT_OPTIONS,
  DEFAULT_ACCENT,
  DEFAULT_SURFACE,
  SURFACE_KEY,
  SURFACE_OPTIONS,
  normalizeAccent,
  normalizeSurface,
} from "./theme";

describe("theme", () => {
  it("keeps the accent axis under its own key, harbour as the attribute-less default", () => {
    expect(ACCENT_KEY).toBe("honey.theme.accent");
    expect(DEFAULT_ACCENT).toBe("harbour");
    // index.html's boot list: every non-default value, and only those.
    expect(ACCENT_OPTIONS.map((o) => o.value).filter((v) => v !== "harbour")).toEqual([
      "cobalt",
      "moss",
      "clay",
      "plum",
      "iris",
      "amber",
    ]);
    expect(normalizeAccent("teal")).toBe("harbour");
    expect(normalizeAccent("plum")).toBe("plum");
  });

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
