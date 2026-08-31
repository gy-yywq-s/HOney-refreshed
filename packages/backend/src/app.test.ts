import { describe, it, expect } from "vitest";
import { buildApp } from "./app.js";

describe("backend health", () => {
  it("responds ok", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/api/health" });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ status: "ok" });
    await app.close();
  });
});
