// Screen-composition regression pins (review v3 §16.14.12, static half).
// jsdom cannot measure real layout, so the mechanical scrollHeight/touch
// assertions live in the owner's installed-PWA pass (§16.14.10 matrix);
// what CI CAN pin is the declared model: the app shell owns the viewport,
// exactly one region scrolls, and every core route declares its scroll
// model. If a refactor silently reverts to document scrolling, these fail.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

function read(rel: string): string {
  return readFileSync(fileURLToPath(new URL(rel, import.meta.url)), "utf8");
}

describe("screen composition (§16.14)", () => {
  it("the document is never the business scroll owner", () => {
    const foundations = read("../styles/foundations.css");
    // body is locked; the app frame's regions scroll instead.
    expect(foundations).toMatch(/body\s*{[^}]*overflow:\s*hidden/);
    expect(foundations).toMatch(/#root\s*{[^}]*height:\s*100%/);
  });

  it("the app frame's <main> is THE declared scroll owner", () => {
    const components = read("../styles/components.css");
    expect(components).toMatch(/\.main\s*{[^}]*overflow-y:\s*auto/);
    // Edge drags stay in the region — no shell rubber-banding leak.
    expect(components).toMatch(/\.main\s*{[^}]*overscroll-behavior-y:\s*contain/);
    expect(read("../components/AppLayout.tsx")).toContain("data-scroll-owner");
  });

  it("FIT login owns its own keyboard overflow", () => {
    const features = read("../styles/features.css");
    expect(features).toMatch(/\.login\s*{[^}]*height:\s*100dvh/);
    expect(features).toMatch(/\.login\s*{[^}]*overflow-y:\s*auto/);
  });

  it("every core route declares its scroll model", () => {
    const routes = [
      "../pages/HomePage.tsx",
      "../pages/LoginPage.tsx",
      "../pages/TimetablePage.tsx",
      "../pages/HistoryPage.tsx",
      "../pages/SettingsPage.tsx",
      "../pages/experiences/FeedPage.tsx",
      "../pages/experiences/ExplorePage.tsx",
      "../pages/experiences/EntityPage.tsx",
      "../pages/experiences/ComposePage.tsx",
      "../pages/experiences/MinePage.tsx",
      "../pages/experiences/WhyPage.tsx",
    ];
    for (const route of routes) {
      expect(read(route), `${route} must declare its scroll model`).toMatch(
        /Scroll model: (FIT|COMPACT_OVERFLOW|FRAMED_SCROLL|FRAMED_EDITOR|DOCUMENT)/,
      );
    }
  });

  it("compact-height degradation exists before overflow (§16.14.5)", () => {
    const features = read("../styles/features.css");
    expect(features).toContain("@media (max-height: 700px)");
    // Home previews degrade 2 → 1 rather than growing the page.
    expect(features).toMatch(/max-height: 700px[^@]*home-voices__row:nth-child\(n \+ 2\)\s*{\s*display:\s*none/s);
  });
});
