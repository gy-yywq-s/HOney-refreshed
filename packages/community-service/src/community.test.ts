import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { portalWeekIndex } from "@honey/shared";
import {
  authorTag,
  blindSign,
  blindToken,
  finalizeToken,
  fromBase64Url,
  importIssuerPrivateKey,
  importIssuerPublicKey,
  postControlKeyPair,
  postingKeyPair,
  randomBytes,
  reactionKeyPair,
  signStatement,
  toBase64Url,
  type EligibilityInfo,
  type EligibilityToken,
  type IssuerDescriptor,
  type MineResponse,
  type PublicExperienceV2,
  type SignedPostEnvelopeV2,
} from "@honey/shared/community-v2";
import { buildCommunityApp } from "./app.js";
import type { LlmFeatures } from "./moderation/llm.js";

// The identity-free Community process end to end (spec §32–§34, §42.2):
// tokens issued by a stand-in issuer with the test key, check → publish,
// feeds scoped by exposure ids, mine/revoke by cryptographic proof,
// registered reactor keys, reports, kill switches, and the boundary that
// refuses any session material.

const KEY_PATH = fileURLToPath(new URL("../../shared/src/community-v2/fixtures/issuer-test.jwk.json", import.meta.url));
const keyFile = JSON.parse(readFileSync(KEY_PATH, "utf8")) as { private: JsonWebKey; public: { kty: "RSA"; n: string; e: string } };
const descriptor: IssuerDescriptor = { suite: "RSAPBSSA-SHA384-PSS-Randomized", keyId: "test-key", publicKey: { ...keyFile.public, alg: "PS384" } };

const CLEAN: LlmFeatures = {
  serious_allegation: false, targets_student: false, slur_or_dehumanizing: false, privacy_invasion: false, high_arousal: false,
  hearsay: false, targeted_profanity: false, low_information: false, injection_attempt: false, uncertain: false,
};

const SCHOOL = "huayaopudong";
const YEAR = "2026-27";
const EPOCH = { schoolId: SCHOOL, academicYear: YEAR };
const M = randomBytes(32); // one student's root
const M2 = randomBytes(32); // another student's root

let app: ReturnType<typeof buildCommunityApp>;
let tmp: string;
let priv: CryptoKey;
let pub: CryptoKey;

/** Stand-in for Core's issuer: blind-signs whatever metadata the test states it verified. */
async function issue(info: EligibilityInfo): Promise<EligibilityToken> {
  const blinded = await blindToken(pub, info);
  const sig = await blindSign(priv, blinded.blindedMessage, info);
  return finalizeToken(pub, "test-key", blinded, info, sig);
}

function lessonInfo(opaqueLessonId: string, courseId = "c_econ4", teacherId = "t_zhu"): EligibilityInfo {
  return { v: 2, schoolId: SCHOOL, academicYear: YEAR, scope: `lesson:${opaqueLessonId}`, contexts: { lessonId: opaqueLessonId, courseId, teacherId, roomId: "r_309" }, provenance: "verified_lesson", week: portalWeekIndex(new Date()) };
}

function envelopeFor(root: Uint8Array, info: EligibilityInfo, body: string, rating: number | null = null): { envelope: SignedPostEnvelopeV2; postSignature: string; postNonce: Uint8Array } {
  const posting = postingKeyPair(root, EPOCH);
  const postNonce = randomBytes(32);
  const control = postControlKeyPair(root, postNonce, EPOCH);
  const sep = info.scope.indexOf(":");
  const envelope: SignedPostEnvelopeV2 = {
    protocolVersion: 2,
    schoolId: SCHOOL,
    academicYear: YEAR,
    primaryEntity: { type: info.scope.slice(0, sep) as SignedPostEnvelopeV2["primaryEntity"]["type"], id: info.scope.slice(sep + 1) },
    contexts: { ...info.contexts },
    body,
    rating,
    postNonce: toBase64Url(postNonce),
    postingPublicKey: toBase64Url(posting.publicKey),
    controlPublicKey: toBase64Url(control.publicKey),
    clientNonce: toBase64Url(randomBytes(12)),
  };
  return { envelope, postSignature: toBase64Url(signStatement(posting.privateKey, envelope as never)), postNonce };
}

async function post(url: string, payload: unknown, headers: Record<string, string> = {}) {
  const res = await app.inject({ method: "POST", url, payload: payload as Record<string, unknown>, headers });
  return { status: res.statusCode, body: res.json() as Record<string, unknown> };
}

async function fullPublish(root: Uint8Array, info: EligibilityInfo, body: string, rating: number | null = null) {
  const token = await issue(info);
  const { envelope, postSignature, postNonce } = envelopeFor(root, info, body, rating);
  const chk = await post("/community/v2/check", { token, envelope, postSignature });
  expect(chk.status, JSON.stringify(chk.body)).toBe(200);
  const pub = await post("/community/v2/publish", { token, envelope, postSignature, pass: chk.body.pass });
  return { chk, pub, envelope, postNonce, token };
}

beforeEach(async () => {
  priv = await importIssuerPrivateKey(keyFile.private);
  pub = await importIssuerPublicKey(keyFile.public);
  tmp = mkdtempSync(join(tmpdir(), "honey-community-"));
  app = buildCommunityApp({ dbPath: join(tmp, "community.db"), issuer: descriptor, config: { schoolId: SCHOOL, internalSecret: "internal-test" } });
  app.ctx.publication.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
  app.ctx.reactions.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
});

afterEach(async () => {
  await app.close();
  rmSync(tmp, { recursive: true, force: true });
});

describe("identity-free boundary", () => {
  it("refuses any request carrying a cookie, an ordinary bearer or an account header", async () => {
    for (const headers of [{ cookie: "s=1" }, { authorization: "Bearer x" }, { "x-honey-account": "abc" }, { "x-request-id": "core-1" }]) {
      const res = await app.inject({ method: "POST", url: "/community/v2/mine/challenge", headers });
      expect(res.statusCode).toBe(400);
      expect((res.json() as { error: string }).error).toBe("identity_material_refused");
    }
    expect((await app.inject({ method: "GET", url: "/community/health" })).statusCode).toBe(200);
  });

  it("the community database has no account column anywhere", () => {
    const tables = (app.ctx.db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all() as { name: string }[]).map((t) => t.name);
    for (const t of tables) {
      const cols = (app.ctx.db.prepare(`PRAGMA table_info(${t})`).all() as { name: string }[]).map((c) => c.name);
      expect(cols.some((c) => /honey|user|student|account|owner/i.test(c)), `${t}: ${cols.join(",")}`).toBe(false);
    }
  });
});

describe("check → publish", () => {
  it("publishes a lesson post with canonical context; the public payload has no tag, key or nonce", async () => {
    const info = lessonInfo("L1");
    const { chk, pub } = await fullPublish(M, info, "Pacing was too fast for the new material.");
    expect(chk.body.lane).toBe("publish");
    expect(pub.status).toBe(200);
    const feed = await post("/community/v2/feed", { scope: "school" });
    const items = (feed.body as { items: PublicExperienceV2[] }).items;
    expect(items).toHaveLength(1);
    expect(items[0]!.primary).toEqual({ type: "lesson", id: "L1", name: null });
    expect(items[0]!.contexts.map((c) => `${c.type}:${c.id}`)).toEqual(["course:c_econ4", "teacher:t_zhu", "room:r_309"]);
    const text = JSON.stringify(feed.body);
    for (const f of ["author", "Tag", "postingPublicKey", "controlPublicKey", "postNonce", "clientNonce", "created_at"]) expect(text).not.toContain(f);
    expect(typeof items[0]!.publishedDay).toBe("number");
  });

  it("rejects a token whose metadata differs from the envelope (scope, context, year) and a spent token", async () => {
    const info = lessonInfo("L2");
    const token = await issue(info);
    const other = envelopeFor(M, lessonInfo("L3"), "x");
    expect((await post("/community/v2/check", { token, envelope: other.envelope, postSignature: other.postSignature })).body.error).toBe("token_scope_mismatch");
    const wrongCtx = envelopeFor(M, { ...info, contexts: { ...info.contexts, teacherId: "t_other" } }, "x");
    expect((await post("/community/v2/check", { token, envelope: wrongCtx.envelope, postSignature: wrongCtx.postSignature })).body.error).toBe("token_scope_mismatch");
    const forged = { ...token, info: { ...token.info, academicYear: "2027-28" } };
    const e = envelopeFor(M, { ...info, academicYear: "2027-28" }, "x");
    const chkForged = await post("/community/v2/check", { token: forged, envelope: { ...e.envelope, academicYear: "2027-28" }, postSignature: e.postSignature });
    expect(["token_invalid", "signature_invalid"]).toContain(chkForged.body.error);
    // Spend it, then try again with a new envelope.
    const first = await fullPublish(M, info, "First words.");
    expect(first.pub.status).toBe(200);
    const again = envelopeFor(M2, info, "Second words.");
    expect((await post("/community/v2/check", { token: first.token, envelope: again.envelope, postSignature: again.postSignature })).body.error).toBe("token_used");
  });

  it("a tampered signature, body or pass fails; the pass binds body, context and keys", async () => {
    const info = lessonInfo("L4");
    const token = await issue(info);
    const { envelope, postSignature } = envelopeFor(M, info, "Honest note.");
    expect((await post("/community/v2/check", { token, envelope: { ...envelope, body: "Edited" }, postSignature })).body.error).toBe("signature_invalid");
    const chk = await post("/community/v2/check", { token, envelope, postSignature });
    const edited = envelopeFor(M, info, "Different words.");
    expect((await post("/community/v2/publish", { token, envelope: edited.envelope, postSignature: edited.postSignature, pass: chk.body.pass })).body.error).toBe("pass_mismatch");
    expect((await post("/community/v2/publish", { token, envelope, postSignature, pass: "nope" })).body.error).toBe("pass_invalid");
    expect((await post("/community/v2/publish", { token, envelope, postSignature, pass: chk.body.pass })).status).toBe(200);
    // Pass nonce burned.
    expect((await post("/community/v2/publish", { token, envelope, postSignature, pass: chk.body.pass })).body.error).toBe("pass_invalid");
  });

  it("one post per primary entity per posting identity; a different student may post on the same lesson", async () => {
    const info = lessonInfo("L5");
    expect((await fullPublish(M, info, "Mine.")).pub.status).toBe(200);
    const token = await issue(info);
    const dup = envelopeFor(M, info, "Again.");
    expect((await post("/community/v2/check", { token, envelope: dup.envelope, postSignature: dup.postSignature })).body.error).toBe("already_posted");
    expect((await fullPublish(M2, info, "Another student.")).pub.status).toBe(200);
  });

  it("moderation lanes: serious lane stores nothing; strikes suspend the posting identity, not any account", async () => {
    app.ctx.publication.llmRunner = async () => ({ ok: true, features: { ...CLEAN, slur_or_dehumanizing: true } });
    for (let i = 0; i < 3; i++) {
      const info = lessonInfo(`S${i}`);
      const token = await issue(info);
      const e = envelopeFor(M, info, `prohibited ${i}`);
      const chk = await post("/community/v2/check", { token, envelope: e.envelope, postSignature: e.postSignature });
      expect(chk.body.lane).toBe("blocked_serious");
    }
    expect((app.ctx.db.prepare("SELECT COUNT(*) AS n FROM experiences").get() as { n: number }).n).toBe(0);
    app.ctx.publication.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    const info = lessonInfo("S9");
    const token = await issue(info);
    const e = envelopeFor(M, info, "fine now");
    expect((await post("/community/v2/check", { token, envelope: e.envelope, postSignature: e.postSignature })).body.error).toBe("temporarily_suspended");
    const tag = authorTag(postingKeyPair(M, EPOCH).publicKey);
    const row = app.ctx.db.prepare("SELECT blocked_attempts FROM community_suspensions WHERE author_tag = ?").get(tag) as { blocked_attempts: number };
    expect(row.blocked_attempts).toBe(3);
    // Another root is unaffected.
    expect((await fullPublish(M2, lessonInfo("S10"), "unrelated")).pub.status).toBe(200);
  });

  it("nudge needs an explicit publish; cooldown ticket gates the re-check", async () => {
    app.ctx.publication.llmRunner = async () => ({ ok: true, features: { ...CLEAN, low_information: true } });
    const info = lessonInfo("N1");
    const token = await issue(info);
    const e = envelopeFor(M, info, "ok");
    const chk = await post("/community/v2/check", { token, envelope: e.envelope, postSignature: e.postSignature });
    expect(chk.body.lane).toBe("nudge");
    expect((app.ctx.db.prepare("SELECT COUNT(*) AS n FROM experiences").get() as { n: number }).n).toBe(0);
    expect((await post("/community/v2/publish", { token, envelope: e.envelope, postSignature: e.postSignature, pass: chk.body.pass })).status).toBe(200);

    app.ctx.publication.llmRunner = async () => ({ ok: true, features: { ...CLEAN, high_arousal: true } });
    const info2 = lessonInfo("N2");
    const token2 = await issue(info2);
    const e2 = envelopeFor(M, info2, "FURIOUS!!!");
    const cool = await post("/community/v2/check", { token: token2, envelope: e2.envelope, postSignature: e2.postSignature });
    expect(cool.body.lane).toBe("cooldown");
    const ticket = (cool.body.cooldown as { ticket: string; retryAt: number }).ticket;
    app.ctx.publication.now = () => Date.now() + 25 * 3600 * 1000;
    const late = await post("/community/v2/check", { token: token2, envelope: e2.envelope, postSignature: e2.postSignature, cooldownTicket: ticket });
    expect(late.body.lane).toBe("publish");
  });
});

describe("reads scoped by exposure", () => {
  it("'Your classes' takes canonical ids from the request; the school feed takes nothing", async () => {
    await fullPublish(M, lessonInfo("A1", "c_econ4", "t_zhu"), "Econ lesson.");
    await fullPublish(M, lessonInfo("A2", "c_phys", "t_chen"), "Physics lesson.");
    await fullPublish(M2, { ...lessonInfo("A3"), scope: "teacher:t_zhu", contexts: {}, provenance: "verified_retrospective" }, "About Ms Zhu.");
    const mine = await post("/community/v2/feed", { scope: "my_classes", exposure: { teachers: ["t_zhu"], courses: [], lessons: [] } });
    const bodies = (mine.body as { items: PublicExperienceV2[] }).items.map((i) => i.body);
    expect(bodies.sort()).toEqual(["About Ms Zhu.", "Econ lesson."]);
    const none = await post("/community/v2/feed", { scope: "my_classes" });
    expect((none.body as { items: unknown[] }).items).toHaveLength(0);
    const school = await post("/community/v2/feed", { scope: "school", limit: 5 });
    expect((school.body as { items: unknown[] }).items).toHaveLength(3);
    const byCourse = await post("/community/v2/feed", { scope: "school", courseId: "c_phys" });
    expect((byCourse.body as { items: PublicExperienceV2[] }).items.map((i) => i.body)).toEqual(["Physics lesson."]);
    const stats = await app.inject({ method: "GET", url: "/community/v2/stats?entityKey=teacher:t_zhu" });
    expect(stats.json()).toEqual({ experiences: 2, courses: 1, teachers: 1 });
    const found = await app.inject({ method: "GET", url: "/community/v2/search?q=Physics" });
    expect((found.json() as { experiences: PublicExperienceV2[] }).experiences).toHaveLength(1);
  });

  it("cursors page without gaps and are scope-bound", async () => {
    for (let i = 0; i < 7; i++) await fullPublish(i % 2 ? M : M2, lessonInfo(`P${i}`), `Post ${i}`);
    const seen: string[] = [];
    let cursor: string | undefined;
    for (let page = 0; page < 4; page++) {
      const res = await post("/community/v2/feed", { scope: "school", limit: 5, ...(cursor ? { cursor } : {}) });
      const body = res.body as { items: PublicExperienceV2[]; nextCursor: string | null; headCursor: string | null };
      seen.push(...body.items.map((i) => i.id));
      if (page === 0) {
        const upd = await post("/community/v2/feed/updates", { scope: "school", head: body.headCursor });
        expect(upd.body.newItemsAvailable).toBe(false);
        expect((await post("/community/v2/feed", { scope: "my_classes", cursor: body.nextCursor, exposure: { teachers: ["t_zhu"], courses: [], lessons: [] } })).status).toBe(400);
      }
      if (!body.nextCursor) break;
      cursor = body.nextCursor;
    }
    expect(new Set(seen).size).toBe(7);
  });
});

describe("mine and revoke by proof", () => {
  it("lists the posting identity's posts with their nonces; revoke needs the per-post control key", async () => {
    const info = lessonInfo("R1");
    const { pub, postNonce } = await fullPublish(M, info, "To be removed.");
    const id = pub.body.experienceId as string;
    const posting = postingKeyPair(M, EPOCH);
    const ch = (await post("/community/v2/mine/challenge", {})).body as { challenge: string; expiresAt: number };
    const statement = { purpose: "honey/v2/mine", schoolId: SCHOOL, academicYear: YEAR, challenge: ch.challenge, expiresAt: ch.expiresAt };
    const mine = await post("/community/v2/mine", { statement, postingPublicKey: toBase64Url(posting.publicKey), signature: toBase64Url(signStatement(posting.privateKey, statement)) });
    expect(mine.status).toBe(200);
    const list = (mine.body as unknown as MineResponse).experiences;
    expect(list).toHaveLength(1);
    expect(list[0]!.postNonce).toBe(toBase64Url(postNonce));
    // A replayed challenge is refused.
    expect((await post("/community/v2/mine", { statement, postingPublicKey: toBase64Url(posting.publicKey), signature: toBase64Url(signStatement(posting.privateKey, statement)) })).body.error).toBe("challenge_invalid");
    // Another root cannot list them.
    const ch2 = (await post("/community/v2/mine/challenge", {})).body as { challenge: string; expiresAt: number };
    const s2 = { ...statement, challenge: ch2.challenge, expiresAt: ch2.expiresAt };
    const other = postingKeyPair(M2, EPOCH);
    expect(((await post("/community/v2/mine", { statement: s2, postingPublicKey: toBase64Url(other.publicKey), signature: toBase64Url(signStatement(other.privateKey, s2)) })).body as unknown as MineResponse).experiences).toHaveLength(0);

    // Revoke: the posting key is NOT enough; the control key derived from root + nonce is.
    const rch = (await post(`/community/v2/posts/${id}/revoke/challenge`, {})).body as { challenge: string; expiresAt: number };
    const rs = { purpose: "honey/v2/revoke", experienceId: id, challenge: rch.challenge, expiresAt: rch.expiresAt };
    expect((await post(`/community/v2/posts/${id}/revoke`, { statement: rs, signature: toBase64Url(signStatement(posting.privateKey, rs)) })).body.error).toBe("signature_invalid");
    const rch2 = (await post(`/community/v2/posts/${id}/revoke/challenge`, {})).body as { challenge: string; expiresAt: number };
    const rs2 = { ...rs, challenge: rch2.challenge, expiresAt: rch2.expiresAt };
    const control = postControlKeyPair(M, fromBase64Url(list[0]!.postNonce), EPOCH);
    expect((await post(`/community/v2/posts/${id}/revoke`, { statement: rs2, signature: toBase64Url(signStatement(control.privateKey, rs2)) })).status).toBe(200);
    expect((app.ctx.db.prepare("SELECT COUNT(*) AS n FROM experiences").get() as { n: number }).n).toBe(0);
    // The slot is free again.
    expect((await fullPublish(M, info, "Reconsidered.")).pub.status).toBe(200);
  });
});

describe("reactions and reports with a registered reactor key", () => {
  async function registerReactor(root: Uint8Array) {
    const rk = reactionKeyPair(root, EPOCH);
    const info: EligibilityInfo = { v: 2, schoolId: SCHOOL, academicYear: YEAR, scope: `school-member:${SCHOOL}`, contexts: {}, provenance: "verified_member", week: portalWeekIndex(new Date()) };
    const token = await issue(info);
    const statement = { purpose: "honey/v2/register-reactor", schoolId: SCHOOL, academicYear: YEAR, reactionPublicKey: toBase64Url(rk.publicKey) };
    const res = await post("/community/v2/reactors/register", { token, statement, signature: toBase64Url(signStatement(rk.privateKey, statement)) });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return rk;
  }

  it("react needs a registered key and a fresh nonce; counts hide below the threshold; report re-evaluates tri-state", async () => {
    const { pub } = await fullPublish(M, lessonInfo("X1"), "Useful lesson.");
    const id = pub.body.experienceId as string;
    const rk = await registerReactor(M2);
    const unregistered = reactionKeyPair(randomBytes(32), EPOCH);
    const st = (value: 1 | -1 | 0, nonce = toBase64Url(randomBytes(12))) => ({ purpose: "honey/v2/react", schoolId: SCHOOL, academicYear: YEAR, experienceId: id, value, nonce });
    const s0 = st(1);
    expect((await post(`/community/v2/posts/${id}/react`, { statement: s0, reactionPublicKey: toBase64Url(unregistered.publicKey), signature: toBase64Url(signStatement(unregistered.privateKey, s0)) })).body.error).toBe("reactor_unregistered");
    const s1 = st(1);
    const r1 = await post(`/community/v2/posts/${id}/react`, { statement: s1, reactionPublicKey: toBase64Url(rk.publicKey), signature: toBase64Url(signStatement(rk.privateKey, s1)) });
    expect(r1.body).toEqual({ ok: true, value: 1, reactions: { likes: 1, dislikes: 0 } });
    expect((await post(`/community/v2/posts/${id}/react`, { statement: s1, reactionPublicKey: toBase64Url(rk.publicKey), signature: toBase64Url(signStatement(rk.privateKey, s1)) })).body.error).toBe("nonce_used");
    const s2 = st(-1);
    expect((await post(`/community/v2/posts/${id}/react`, { statement: s2, reactionPublicKey: toBase64Url(rk.publicKey), signature: toBase64Url(signStatement(rk.privateKey, s2)) })).body.reactions).toEqual({ likes: 0, dislikes: 1 });
    app.ctx.settings.set("reactions.minCount", "5");
    const s3 = st(1);
    expect((await post(`/community/v2/posts/${id}/react`, { statement: s3, reactionPublicKey: toBase64Url(rk.publicKey), signature: toBase64Url(signStatement(rk.privateKey, s3)) })).body.reactions).toBeNull();

    // Report: classifier now sees a violation → hidden.
    app.ctx.reactions.llmRunner = async () => ({ ok: true, features: { ...CLEAN, targets_student: true } });
    const rep = { purpose: "honey/v2/report", schoolId: SCHOOL, academicYear: YEAR, experienceId: id, category: "targets_student", nonce: toBase64Url(randomBytes(12)) };
    expect((await post(`/community/v2/posts/${id}/report`, { statement: rep, reactionPublicKey: toBase64Url(rk.publicKey), signature: toBase64Url(signStatement(rk.privateKey, rep)) })).status).toBe(200);
    const row = app.ctx.db.prepare("SELECT status, body FROM experiences WHERE id = ?").get(id) as { status: string; body: string | null };
    expect(row.status).toBe("blocked");
    expect(row.body).toBeNull();
  });
});

describe("internal admin + kill switches", () => {
  it("needs the internal secret from loopback; status carries no tag; switches bite", async () => {
    expect((await app.inject({ method: "GET", url: "/internal/admin/status" })).statusCode).toBe(403);
    const status = await app.inject({ method: "GET", url: "/internal/admin/status", headers: { "x-honey-internal": "internal-test" } });
    expect(status.statusCode).toBe(200);
    expect(JSON.stringify(status.json())).not.toMatch(/author_tag|authorTag/);
    await app.inject({ method: "POST", url: "/internal/admin/kill-switch", headers: { "x-honey-internal": "internal-test" }, payload: { name: "DISABLE_NEW_PUBLICATIONS", on: true } });
    const info = lessonInfo("K1");
    const token = await issue(info);
    const e = envelopeFor(M, info, "blocked by switch");
    expect((await post("/community/v2/check", { token, envelope: e.envelope, postSignature: e.postSignature })).body.error).toBe("publications_disabled");
    await app.inject({ method: "POST", url: "/internal/admin/kill-switch", headers: { "x-honey-internal": "internal-test" }, payload: { name: "DISABLE_NEW_PUBLICATIONS", on: false } });
    expect((await fullPublish(M, info, "open again")).pub.status).toBe(200);
    await app.inject({ method: "POST", url: "/internal/admin/kill-switch", headers: { "x-honey-internal": "internal-test" }, payload: { name: "HIDE_PUBLIC_EXPERIENCES", on: true } });
    expect(((await post("/community/v2/feed", { scope: "school" })).body as { items: unknown[] }).items).toHaveLength(0);
  });
});

describe("dependency boundary", () => {
  it("the Community package imports nothing from the Core package", () => {
    const { readdirSync, statSync } = require("node:fs") as typeof import("node:fs");
    const root = fileURLToPath(new URL("./", import.meta.url));
    const files: string[] = [];
    const walk = (d: string) => {
      for (const n of readdirSync(d)) {
        const p = join(d, n);
        if (statSync(p).isDirectory()) walk(p);
        else if (n.endsWith(".ts") && !n.endsWith(".test.ts")) files.push(p);
      }
    };
    walk(root);
    for (const f of files) {
      const src = readFileSync(f, "utf8");
      expect(src, f).not.toMatch(/from "\.\.\/\.\.\/backend|@honey\/backend|services\/accounts|portal-connector/);
    }
  });
});
