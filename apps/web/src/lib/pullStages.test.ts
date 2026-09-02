import { describe, expect, it } from "vitest";
import { commitFor, stageFor, syncAtFor } from "./pullStages";

const th = { refreshAt: 64, syncAt: 150, holdMs: 450 };

describe("pull stages", () => {
  it("stays idle for a nudge and reads as a pull before the threshold", () => {
    expect(stageFor(4, true, 0, th)).toBe("idle");
    expect(stageFor(30, true, 0, th)).toBe("pull");
  });

  it("commits a refresh from the first threshold", () => {
    expect(stageFor(64, false, 0, th)).toBe("refresh");
    expect(commitFor(stageFor(64, false, 0, th))).toBe("refresh");
  });

  it("never offers the sync stage without a sync handler", () => {
    expect(stageFor(200, false, 5000, th)).toBe("refresh");
    expect(commitFor(stageFor(200, false, 5000, th))).toBe("refresh");
  });

  it("hints, then requires a hold, before the sync stage arms", () => {
    expect(stageFor(100, true, 0, th)).toBe("further");
    expect(stageFor(150, true, 0, th)).toBe("hold");
    expect(stageFor(150, true, 449, th)).toBe("hold");
    expect(stageFor(150, true, 450, th)).toBe("sync");
  });

  it("releasing before the hold completes only refreshes", () => {
    expect(commitFor(stageFor(150, true, 200, th))).toBe("refresh");
    expect(commitFor(stageFor(150, true, 450, th))).toBe("sync");
  });

  it("scales the sync distance with the screen inside sane bounds", () => {
    expect(syncAtFor(844)).toBe(152);
    expect(syncAtFor(568)).toBe(110);
    expect(syncAtFor(1200)).toBe(160);
  });
});
