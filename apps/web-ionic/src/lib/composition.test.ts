import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

function read(relative: string): string {
  return readFileSync(fileURLToPath(new URL(relative, import.meta.url)), "utf8");
}

describe("Ionic screen composition invariants", () => {
  it("locks document scrolling and gives Ionic the viewport", () => {
    const css = read("../theme/app.css");
    expect(css).toMatch(/html, body, #root, ion-app\s*{[^}]*height:\s*100%[^}]*overflow:\s*hidden/s);
  });

  it("declares every core mobile route's composition model", () => {
    const routes = [
      "../pages/HomePage.tsx",
      "../pages/ExperiencesPage.tsx",
      "../pages/ExplorePage.tsx",
      "../pages/ComposePage.tsx",
      "../pages/TimetablePage.tsx",
      "../pages/HistoryPage.tsx",
      "../pages/LoginPage.tsx",
      "../pages/ConsentPage.tsx",
    ];
    for (const route of routes) {
      expect(read(route), route).toMatch(/data-scroll-model="(FIT|COMPACT_OVERFLOW|FRAMED_SCROLL|FRAMED_EDITOR|DOCUMENT)"/);
    }
  });

  it("keeps fixture disclosure and compact-height degradation explicit", () => {
    expect(read("../App.tsx")).toContain("Fixture data · not live");
    expect(read("../theme/app.css")).toContain("@media (max-height: 700px)");
  });

  it("configures an installable PWA without caching API responses", () => {
    const config = read("../../vite.config.ts");
    expect(config).toContain('registerType: "autoUpdate"');
    expect(config).toContain('display: "standalone"');
    expect(config).toContain("navigateFallbackDenylist: [/^\\/api\\//]");
    expect(config).toContain("runtimeCaching: []");
  });
});
