// Theme mechanism contract: the persisted keys and value sets the pre-paint
// boot script in index.html relies on. If these change, index.html must too.

import { describe, expect, it } from "vitest";
import {
  DEFAULT_SURFACE,
  DEFAULT_UI_FONT,
  SURFACE_KEY,
  SURFACE_OPTIONS,
  UI_FONT_KEY,
  UI_FONT_OPTIONS,
  normalizeSurface,
  normalizeUiFont,
} from "./theme";

describe("theme", () => {
  it("persists under the agreed localStorage keys", () => {
    expect(SURFACE_KEY).toBe("honey.theme.surface");
    expect(UI_FONT_KEY).toBe("honey.theme.uiFont");
  });

  it("offers the four surfaces with stone as default", () => {
    expect(SURFACE_OPTIONS.map((o) => o.value)).toEqual(["stone", "white", "mist", "night"]);
    expect(DEFAULT_SURFACE).toBe("stone");
  });

  it("offers the three ui-fonts with grotesk as default", () => {
    expect(UI_FONT_OPTIONS.map((o) => o.value)).toEqual(["grotesk", "neutral", "editorial"]);
    expect(DEFAULT_UI_FONT).toBe("grotesk");
  });

  it("normalizes unknown stored values to the defaults", () => {
    expect(normalizeSurface("paper")).toBe("stone");
    expect(normalizeSurface(null)).toBe("stone");
    expect(normalizeSurface("night")).toBe("night");
    expect(normalizeUiFont("comic-sans")).toBe("grotesk");
    expect(normalizeUiFont("editorial")).toBe("editorial");
  });
});
