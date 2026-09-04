import { describe, expect, it } from "vitest";
import { compactSubjectName, roomLabel, shortSubjectName } from "./displayNames";

describe("roomLabel", () => {
  it("names a bare number and keeps a named place", () => {
    expect(roomLabel("309")).toBe("Room 309");
    expect(roomLabel("Library")).toBe("Library");
    expect(roomLabel(null)).toBe("");
  });
});

describe("compactSubjectName", () => {
  it("shortens to a stable subject identity", () => {
    expect(compactSubjectName("Edexcel Economics-U4")).toBe("Economics");
    expect(compactSubjectName("CIE Chinese Language & Literature")).toBe("Chinese");
    expect(compactSubjectName("IELTS-Speaking")).toBe("IELTS");
    expect(compactSubjectName("CIE Physics-A2")).toBe("Physics");
    expect(compactSubjectName("Activity")).toBe("Activity");
    expect(compactSubjectName("Public Speaking")).toBe("Public Speaking");
    expect(compactSubjectName("TMUA")).toBe("TMUA");
  });
});

describe("shortSubjectName", () => {
  it("maps only when the compact name would not fit a phone column", () => {
    expect(shortSubjectName("Edexcel Economics-U4")).toBe("Econ");
    expect(shortSubjectName("CIE Physics-A2")).toBe("Physics");
    expect(shortSubjectName("Activity")).toBe("Activity");
    expect(shortSubjectName("Public Speaking")).toBe("Public Speaking");
  });
});
