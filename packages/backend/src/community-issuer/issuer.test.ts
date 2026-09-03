import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { makeMockPortal } from "@honey/portal-connector/testing";
import {
  blindToken, finalizeToken, fromBase64Url, importIssuerPublicKey, verifyToken,
  type EligibilityInfo, type EligibilityIssued, type IssuerDescriptor,
} from "@honey/shared/community-v2";
import { buildApp } from "../app.js";
import type { IssuerKeyFile } from "./issuer.js";

// Core-side Anonymous Control v2 (spec §31, §42.2 no.10–12): standing is
// verified on the account, the token is blind to the issuer, the public
// metadata (scope + canonical context) is bound into the signature, and the
// issuance bound counts on an unlinkable mark.

const TEST_KEY_PATH = fileURLToPath(new URL("../../../shared/src/community-v2/fixtures/issuer-test.jwk.json", import.meta.url));

describe.skipIf(!existsSync(TEST_KEY_PATH))("blind eligibility issuer", () => {
  const keyFile = existsSync(TEST_KEY_PATH) ? (JSON.parse(readFileSync(TEST_KEY_PATH, "utf8")) as IssuerKeyFile) : null;
  let portal: ReturnType<typeof makeMockPortal>;
  let app: ReturnType<typeof buildApp>;
  let tmp: string;
  let auth: { authorization: string };

  beforeEach(async () => {
    portal = makeMockPortal();
    await portal.app.listen({ port: 0, host: "127.0.0.1" });
    const addr = portal.app.server.address() as AddressInfo;
    tmp = mkdtempSync(join(tmpdir(), "honey-issuer-"));
    app = buildApp({
      portalBaseUrl: `http://127.0.0.1:${addr.port}`,
      dbPath: join(tmp, "core.db"),
      vaultDbPath: join(tmp, "vault.db"),
      config: { adminStudentId: "88" },
      ...(keyFile ? { issuerKey: keyFile } : {}),
    });
    const res = await app.inject({ method: "POST", url: "/api/auth/login", payload: { username: "s0088", password: "pw-good" } });
    auth = { authorization: `Bearer ${(res.json() as { session: { accessToken: string } }).session.accessToken}` };
    await app.inject({ method: "POST", url: "/api/sync", headers: auth });
  });

  afterEach(async () => {
    await app.close();
    await portal.app.close();
    rmSync(tmp, { recursive: true, force: true });
  });

  async function myLessonId(): Promise<string> {
    const history = await app.inject({ method: "GET", url: "/api/history?limit=1", headers: auth });
    return (history.json() as { lessons: { id: string }[] }).lessons[0]!.id;
  }

  it("publishes the issuer descriptor; issues a token bound to the lesson's canonical context; the token verifies offline", async () => {
    const desc = (await app.inject({ method: "GET", url: "/api/community/issuer" })).json() as IssuerDescriptor;
    expect(desc.suite).toBe("RSAPBSSA-SHA384-PSS-Randomized");
    const pub = await importIssuerPublicKey(desc.publicKey);

    const lessonId = await myLessonId();
    const scope = (await app.inject({ method: "GET", url: "/api/community/scope", headers: auth })).json() as { lessons: string[]; courses: string[]; academicYear: string };
    expect(scope.lessons.length).toBeGreaterThan(0);
    // Step 1: the metadata the issuer would bind (nothing signed or counted).
    const first = await app.inject({ method: "POST", url: "/api/community/eligibility/info", headers: auth, payload: { lessonId } });
    expect(first.statusCode).toBe(200);
    const stated = (first.json() as { info: EligibilityInfo }).info;
    expect(stated.scope.startsWith("lesson:")).toBe(true);
    expect(stated.contexts.courseId).toBeTruthy();
    expect(stated.academicYear).toBe(scope.academicYear);
    // Step 2: blind under exactly that, one counted signing round.
    const blinded = await blindToken(pub, stated);
    const second = await app.inject({
      method: "POST", url: "/api/community/eligibility", headers: auth,
      payload: { lessonId, blindedMessage: Buffer.from(blinded.blindedMessage).toString("base64url") },
    });
    expect(second.statusCode).toBe(200);
    const issued2 = second.json() as EligibilityIssued;
    expect(issued2.info).toEqual(stated);
    const token = await finalizeToken(pub, issued2.keyId, blinded, issued2.info, fromBase64Url(issued2.blindSignature));
    expect(await verifyToken(pub, token)).toBe(true);
    expect(await verifyToken(pub, { ...token, info: { ...token.info, scope: "teacher:t_x" } })).toBe(false);
    // Nothing the issuer stored names the token or the account: only a mark and a day.
    const cols = (app.ctx.db.prepare("PRAGMA table_info(issuance_marks)").all() as { name: string }[]).map((c) => c.name).sort();
    expect(cols).toEqual(["count", "day", "mark_hash"]);
  }, 60_000);

  it("refuses a lesson that is not the account's, and bounds issuance per scope per day", async () => {
    const desc = (await app.inject({ method: "GET", url: "/api/community/issuer" })).json() as IssuerDescriptor;
    const pub = await importIssuerPublicKey(desc.publicKey);
    const info: EligibilityInfo = { v: 2, schoolId: "s", academicYear: "y", scope: "x", contexts: {}, provenance: "verified_lesson", week: 0 };
    const blinded = await blindToken(pub, info);
    const payload = (lessonId: string) => ({ lessonId, blindedMessage: Buffer.from(blinded.blindedMessage).toString("base64url") });
    const foreign = await app.inject({ method: "POST", url: "/api/community/eligibility", headers: auth, payload: payload("999999") });
    expect(foreign.statusCode).toBe(422);
    expect((foreign.json() as { error: string }).error).toBe("lesson_not_yours");

    const lessonId = await myLessonId();
    for (let i = 0; i < 6; i++) {
      expect((await app.inject({ method: "POST", url: "/api/community/eligibility", headers: auth, payload: payload(lessonId) })).statusCode).toBe(200);
    }
    const seventh = await app.inject({ method: "POST", url: "/api/community/eligibility", headers: auth, payload: payload(lessonId) });
    expect(seventh.statusCode).toBe(429);
  }, 60_000);
});
