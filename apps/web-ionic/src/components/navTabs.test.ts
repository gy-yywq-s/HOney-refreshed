// Shell contract: the mobile bottom tab bar mirrors the iOS shell with exactly
// four tabs (Home / Experiences / Timetable / Settings), and the desktop top
// nav keeps its three (Settings stays in the user menu on desktop).

import { describe, expect, it } from "vitest";
import { DESKTOP_TABS, MOBILE_TABS } from "./navTabs";

describe("navTabs", () => {
  it("mobile tab bar has the four iOS-shell tabs, in order", () => {
    expect(MOBILE_TABS.map((t) => t.to)).toEqual([
      "/home",
      "/experiences",
      "/timetable",
      "/settings",
    ]);
    expect(MOBILE_TABS.map((t) => t.label)).toEqual([
      "Home",
      "Experiences",
      "Timetable",
      "Settings",
    ]);
  });

  it("every mobile tab carries an icon", () => {
    for (const tab of MOBILE_TABS) {
      expect(tab.icon).toBeTruthy();
    }
  });

  it("desktop nav keeps Settings out (it lives in the user menu)", () => {
    expect(DESKTOP_TABS.map((t) => t.to)).toEqual(["/home", "/experiences", "/timetable"]);
  });
});
