import { describe, expect, it } from "vitest";
import { lessonIdFromTarget, targetFromSearch, targetInput } from "./experienceTarget";

describe("Experience target contract mapping", () => {
  it("maps a lesson route to the shared lessonId contract", () => {
    const target = targetFromSearch("?lesson=lesson-42");
    expect(target).toBe("lesson:lesson-42");
    expect(targetInput(target)).toEqual({ lessonId: "lesson-42" });
    expect(lessonIdFromTarget(target)).toBe("lesson-42");
  });

  it("maps an entity route to the shared entityKey contract", () => {
    const target = targetFromSearch("?entity=course%3Aeconomics");
    expect(targetInput(target)).toEqual({ entityKey: "course:economics" });
    expect(lessonIdFromTarget(target)).toBeNull();
  });

  it("gives lesson scope precedence when both parameters exist", () => {
    expect(targetFromSearch("?entity=teacher%3Alin&lesson=lesson-7")).toBe("lesson:lesson-7");
  });
});
