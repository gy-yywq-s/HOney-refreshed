// Ionic screen-composition regression pins (review v3 §16.14.12).
// jsdom cannot measure shadow-DOM layout, so browser tests own scrollHeight;
// CI pins the architecture and the absence of document/touch workarounds.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

function read(rel: string): string {
  return readFileSync(fileURLToPath(new URL(rel, import.meta.url)), "utf8");
}

describe("Ionic screen composition (§16.14)", () => {
  it("the document is never the business scroll owner", () => {
    const foundations = read("../styles/foundations.css");
    expect(foundations).toMatch(/body\s*{[^}]*overflow:\s*hidden/);
    expect(foundations).toMatch(/#root\s*{[^}]*height:\s*100%/);
  });

  it("each Ionic route owns exactly one IonContent scroll surface", () => {
    const page = read("../components/IonicRoutePage.tsx");
    const ionic = read("../styles/ionic.css");
    expect(page).toContain("<IonPage");
    expect(page).toContain("<IonContent");
    expect(page).toContain("data-scroll-owner");
    expect(page).toContain("<IonRefresher");
    expect(ionic).toMatch(/\.route-content::part\(scroll\)\s*{[^}]*overscroll-behavior-y:\s*contain/s);
    expect(page).not.toContain("touchmove");
    expect(page).not.toContain("preventDefault");
  });

  it("uses Ionic navigation primitives for one responsive architecture", () => {
    const shell = read("../components/AppLayout.tsx");
    for (const primitive of [
      "IonSplitPane",
      "IonMenu",
      "IonRouterOutlet",
      "IonTabs",
      "IonTabBar",
      "IonTabButton",
    ]) {
      expect(shell).toContain(primitive);
    }
  });

  it("declares every core route scroll model at the route boundary", () => {
    const shell = read("../components/AppLayout.tsx");
    const expected: Array<[string, string]> = [
      ["/home", "COMPACT_OVERFLOW"],
      ["/experiences", "FRAMED_SCROLL"],
      ["/experiences/explore", "FRAMED_EDITOR"],
      ["/experiences/why", "DOCUMENT"],
      ["/experiences/mine", "FRAMED_SCROLL"],
      ["/experiences/compose", "FRAMED_EDITOR"],
      ["/timetable", "FRAMED_SCROLL"],
      ["/history", "FRAMED_SCROLL"],
      ["/settings", "FRAMED_SCROLL"],
    ];
    for (const [path, model] of expected) {
      const route = new RegExp(`path="${path.replaceAll("/", "\\/")}"[^\\n]*model="${model}"`);
      expect(shell, `${path} must declare ${model}`).toMatch(route);
    }
    expect(read("../App.tsx")).toMatch(/path="\/login"[\s\S]*model="FIT"/);
  });

  it("login delegates keyboard overflow to IonContent", () => {
    const ionic = read("../styles/ionic.css");
    expect(ionic).toMatch(/\.route-page--public \.login\s*{[^}]*overflow-y:\s*visible/s);
    expect(read("../App.tsx")).toContain("publicScreen");
    expect(read("../pages/LoginPage.tsx")).not.toContain("<main");
  });

  it("compact-height degradation exists before overflow", () => {
    const features = read("../styles/features.css");
    expect(features).toContain("@media (max-height: 700px)");
    expect(features).toMatch(/max-height: 700px[^@]*home-voices__row:nth-child\(n \+ 2\)\s*{\s*display:\s*none/s);
  });

  it("PWA cache never intercepts API requests", () => {
    const manifest = read("../../public/manifest.webmanifest");
    const sw = read("../../public/sw.js");
    const server = read("../../server.mjs");
    expect(JSON.parse(manifest).display).toBe("standalone");
    expect(sw).toContain('url.pathname.startsWith("/api/")');
    expect(server).toContain('"https://ionic.gaelisus.com"');
    expect(server).toContain("return proxyApi(incoming, outgoing)");
  });

  it("delegates overlay lifecycle to Ionic modal and popover primitives", () => {
    const modal = read("../components/Modal.tsx");
    const post = read("../features/experiences/ExperiencePost.tsx");
    expect(modal).toContain("<IonModal");
    expect(post).toContain("<IonPopover");
    expect(post).toContain("<Modal");
  });

  it("uses semantic Ionic controls at the feed and composer boundaries", () => {
    const compose = read("../pages/experiences/ComposePage.tsx");
    const feed = read("../pages/experiences/FeedPage.tsx");
    expect(compose).toContain("<IonTextarea");
    expect(feed).toContain("<IonSegment");
    expect(feed).toContain("<IonSegmentButton");
    expect(read("../features/experiences/useFeedController.ts")).toContain("useScrollOwner");
  });

  it("route-splits page code behind stable Ionic route boundaries", () => {
    const shell = read("../components/AppLayout.tsx");
    expect(shell).toContain("const HomePage = lazy(");
    expect(shell).toContain("<RouteView>");
  });
});
