import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { IssuerDescriptor } from "@honey/shared/community-v2";
import { buildCommunityApp } from "./app.js";
import { parseVerdict } from "./moderation/image.js";

// The credential-image classifier route: a JPEG body in, one boolean out,
// nothing stored, the same identity-free boundary as every other route.

const KEY_PATH = fileURLToPath(new URL("../../shared/src/community-v2/fixtures/issuer-test.jwk.json", import.meta.url));
const keyFile = JSON.parse(readFileSync(KEY_PATH, "utf8")) as { public: { kty: "RSA"; n: string; e: string } };
const descriptor: IssuerDescriptor = { suite: "RSAPBSSA-SHA384-PSS-Randomized", keyId: "test-key", publicKey: { ...keyFile.public, alg: "PS384" } };

// Smallest valid-looking JPEG prefix padded past the route's 64-byte floor.
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 0x11), Buffer.from([0xff, 0xd9])]);

let tmp: string;
const seen: Buffer[] = [];

function build(opts: { key?: string; verdict?: { ok: boolean; credentialLike?: boolean; uncertain?: boolean } } = {}) {
  return buildCommunityApp({
    dbPath: join(tmp, "community.db"),
    issuer: descriptor,
    config: { schoolId: "huayaopudong", internalSecret: "internal-test", openRouterApiKey: opts.key ?? "test-key" },
    classifyImage: async (jpeg) => {
      seen.push(jpeg);
      const v = opts.verdict ?? { ok: true, credentialLike: true, uncertain: false };
      return { ...v, latencyMs: 12, model: "stub/model" };
    },
  });
}

beforeEach(() => {
  tmp = mkdtempSync(join(tmpdir(), "honey-image-"));
  seen.length = 0;
});
afterEach(() => rmSync(tmp, { recursive: true, force: true }));

describe("POST /community/v2/image/classify", () => {
  it("answers with the verdict for a JPEG body and hands the model the bytes unchanged", async () => {
    const app = build();
    const res = await app.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg" }, payload: JPEG });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ credentialLike: true, uncertain: false, latencyMs: 12, model: "stub/model" });
    expect(seen).toHaveLength(1);
    expect(Buffer.compare(seen[0]!, JPEG)).toBe(0);
    await app.close();
  });

  it("refuses anything that is not a JPEG body", async () => {
    const app = build();
    const json = await app.inject({ method: "POST", url: "/community/v2/image/classify", payload: { image: "..." } });
    expect(json.statusCode).toBe(415);
    const tiny = await app.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg" }, payload: Buffer.from([0xff, 0xd8]) });
    expect(tiny.statusCode).toBe(415);
    expect(seen).toHaveLength(0);
    await app.close();
  });

  it("caps the body at the analysis-derivative size", async () => {
    const app = build();
    const res = await app.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg" }, payload: Buffer.alloc(300 * 1024, 0x11) });
    expect(res.statusCode).toBe(413);
    expect(seen).toHaveLength(0);
    await app.close();
  });

  it("reports the classifier as unavailable when there is no key or no answer — never a made-up verdict", async () => {
    const noKey = build({ key: "" });
    const a = await noKey.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg" }, payload: JPEG });
    expect(a.statusCode).toBe(503);
    expect(a.json()).toEqual({ error: "classifier_unavailable" });
    await noKey.close();

    const down = build({ verdict: { ok: false } });
    const b = await down.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg" }, payload: JPEG });
    expect(b.statusCode).toBe(503);
    expect(b.json().error).toBe("classifier_unavailable");
    await down.close();
  });

  it("keeps the identity-free boundary: a cookie or bearer is refused before the model sees anything", async () => {
    const app = build();
    for (const headers of [{ cookie: "honey=abc" }, { authorization: "Bearer x" }]) {
      const res = await app.inject({ method: "POST", url: "/community/v2/image/classify", headers: { "content-type": "image/jpeg", ...headers }, payload: JPEG });
      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBe("identity_material_refused");
    }
    expect(seen).toHaveLength(0);
    await app.close();
  });
});

describe("parseVerdict", () => {
  it("accepts the bare object, a fenced object, and prose around it", () => {
    expect(parseVerdict('{"credential_like":true,"uncertain":false}')).toEqual({ credentialLike: true, uncertain: false });
    expect(parseVerdict('```json\n{"credential_like": false, "uncertain": true}\n```')).toEqual({ credentialLike: false, uncertain: true });
    expect(parseVerdict('Sure: {"credential_like": true} done')).toEqual({ credentialLike: true, uncertain: false });
  });
  it("rejects anything without a boolean credential_like", () => {
    expect(parseVerdict("")).toBeNull();
    expect(parseVerdict('{"credential_like":"yes"}')).toBeNull();
    expect(parseVerdict("{not json}")).toBeNull();
  });
});
