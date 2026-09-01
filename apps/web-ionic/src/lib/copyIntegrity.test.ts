import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

function read(rel: string): string {
  return readFileSync(fileURLToPath(new URL(rel, import.meta.url)), "utf8");
}

describe("user-facing copy maps to real behavior", () => {
  it("maps every Feed header label to its stated destination", () => {
    const feed = read("../pages/experiences/FeedPage.tsx");
    expect(feed).toMatch(/to="\/experiences\/compose"[\s\S]*?<span>Share<\/span>/);
    expect(feed).toMatch(/to="\/experiences\/explore"[\s\S]*?aria-label="Find someone or something"/);
    expect(feed).toMatch(/to="\/experiences\/mine"[\s\S]*?aria-label="Your notes and posts"/);
  });

  it("keeps both finite Feed scopes visible and behaviorally distinct", () => {
    const feed = read("../pages/experiences/FeedPage.tsx");
    expect(feed).toMatch(/value="my_classes"[\s\S]*?<IonLabel>Your classes<\/IonLabel>/);
    expect(feed).toMatch(/value="school"[\s\S]*?<IonLabel>Around school<\/IonLabel>/);
    expect(feed).toContain('next === "my_classes" || next === "school"');
  });

  it("keeps primary navigation labels aligned with their routes", () => {
    const tabs = read("../components/navTabs.tsx");
    for (const [path, label] of [
      ["/home", "Home"],
      ["/experiences", "Experiences"],
      ["/timetable", "Timetable"],
      ["/settings", "Settings"],
    ]) {
      expect(tabs).toContain('to: "' + path + '", label: "' + label + '"');
    }
  });

  it("puts Skip to content before the desktop rail controls", () => {
    const shell = read("../components/AppLayout.tsx");
    expect(shell.indexOf('className="skip-link"')).toBeGreaterThan(-1);
    expect(shell.indexOf('className="skip-link"')).toBeLessThan(shell.indexOf("<IonMenu"));
    expect(shell).toContain('href="#ionic-main"');
    expect(shell).toContain('id="ionic-main"');
  });

  it("describes private-note storage and prior safety checks without absolutes", () => {
    const compose = read("../pages/experiences/ComposePage.tsx");
    const composer = read("../pages/experiences/useComposer.ts");
    const settings = read("../pages/SettingsPage.tsx");
    const combined = [compose, composer, settings].join("\n");

    for (const overclaim of [
      "never sent anywhere",
      "Private notes never leave this device",
      "Nothing was stored",
      "Nothing was kept",
    ]) {
      expect(combined).not.toContain(overclaim);
    }
    expect(compose).toContain("If you started a safety check first");
    expect(compose).toContain("cannot undo a safety check already run");
    expect(composer).toContain("not published or stored on the HOney server");
    expect(settings).toContain("If you choose Keep private after starting a safety check");
  });

  it("states that post control needs both the signed-in session and device key", () => {
    const compose = read("../pages/experiences/ComposePage.tsx");
    const mine = read("../pages/experiences/MinePage.tsx");
    const settings = read("../pages/SettingsPage.tsx");
    const combined = [compose, mine, settings].join("\n");

    expect(combined).not.toContain("key is the only way");
    expect(combined).not.toContain("only control over the post");
    expect(combined).not.toContain("controlled only by the keys on your devices");
    expect(compose).toContain("both a signed-in HOney session and this browser&apos;s post-control key");
    expect(mine).toContain("While you are signed in to HOney");
    expect(settings).toContain("neither\n            the signed-in session nor the stored hash is enough by itself");
    expect(settings).toContain(
      "A signed-in HOney session and a post-control key held\n              on one of your devices are both required to find or revoke them",
    );
  });

  it("replaces abstract exposure language with the checked context", () => {
    const why = read("../pages/experiences/WhyPage.tsx");
    const post = read("../features/experiences/ExperiencePost.tsx");
    expect(`${why}\n${post}`).not.toContain("relevant exposure");
    expect(why).toContain("the class appears\n          in the writer's history");
    expect(post).toContain("same class, teacher, course or place");
  });

  it("ships a deterministic full-source copy inventory command", () => {
    const script = read("../../scripts/audit-copy.mjs");
    expect(script).toContain('[".ts", ".tsx"]');
    expect(script).toContain("surfaceStrings");
    expect(script).toContain("allStringLiterals");
    expect(read("../../package.json")).toContain('"audit:copy": "node scripts/audit-copy.mjs"');
  });
});
