import { describe, expect, it } from "vitest";
import { parseCourseName, roomLabel } from "./displayNames";

describe("parseCourseName", () => {
  it("splits a portal course string into title and metadata", () => {
    expect(parseCourseName("CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅")).toEqual({
      title: "CIE Chinese Language & Literature",
      meta: "2026 Autumn · 中文备考班 · 赵流畅",
    });
    expect(parseCourseName("Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明")).toEqual({
      title: "Edexcel Economics-U4",
      meta: "2026 Autumn · 备考班 · 朱昂明",
    });
    expect(parseCourseName("IELTS-Speaking 2026秋IELTS Speaking强化班 ChenJenny", "ChenJenny")).toEqual({
      title: "IELTS-Speaking",
      meta: "2026 Autumn · 强化班 · ChenJenny",
    });
    expect(parseCourseName("Activity 2026年秋活动课 活动课老师")).toEqual({
      title: "Activity",
      meta: "2026 Autumn · 活动课 · 活动课老师",
    });
    expect(parseCourseName("CIE Physics-A2 2026秋A2PHY备考5班 陈拯侃").meta).toBe("2026 Autumn · 备考5班 · 陈拯侃");
  });
  it("passes a plain name through untouched", () => {
    expect(parseCourseName("Public Speaking")).toEqual({ title: "Public Speaking", meta: "" });
  });
});

describe("roomLabel", () => {
  it("names a bare number and keeps a named place", () => {
    expect(roomLabel("309")).toBe("Room 309");
    expect(roomLabel("Library")).toBe("Library");
    expect(roomLabel(null)).toBe("");
  });
});
