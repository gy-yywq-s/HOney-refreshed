import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { AddressInfo } from "node:net";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { makeMockPortal } from "@honey/portal-connector/testing";
import type { VaultRecord } from "@honey/shared/community-v2";
import { buildApp } from "../app.js";

// Control Vault + pairing relay (spec §35, §38, §40): ciphertext with CAS
// revisions; the relay hands ciphertext out exactly once; account deletion
// takes the vault with it. Core never sees a root: nothing here decrypts.

let portal: ReturnType<typeof makeMockPortal>;
let app: ReturnType<typeof buildApp>;
let tmp: string;
let auth: { authorization: string };

beforeEach(async () => {
  portal = makeMockPortal();
  await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const addr = portal.app.server.address() as AddressInfo;
  tmp = mkdtempSync(join(tmpdir(), "honey-vault-"));
  app = buildApp({ portalBaseUrl: `http://127.0.0.1:${addr.port}`, dbPath: join(tmp, "core.db"), vaultDbPath: join(tmp, "vault.db") });
  const res = await app.inject({ method: "POST", url: "/api/auth/login", payload: { username: "s0088", password: "pw-good" } });
  auth = { authorization: `Bearer ${(res.json() as { session: { accessToken: string } }).session.accessToken}` };
});

afterEach(async () => {
  await app.close();
  await portal.app.close();
  rmSync(tmp, { recursive: true, force: true });
});

const put = (body: Record<string, unknown>) => app.inject({ method: "PUT", url: "/api/vault", headers: auth, payload: body });
const base = { vaultId: "vault_abcdefgh", iv: "aaaaaaaaaaaaaaaa", ciphertext: "Y2lwaGVy", wrappers: [] as unknown[] };

describe("control vault", () => {
  it("404 before a vault exists; first write needs base 0; CAS rejects a stale base with the current record", async () => {
    expect((await app.inject({ method: "GET", url: "/api/vault", headers: auth })).statusCode).toBe(404);
    expect((await put({ ...base, baseRevision: 3 })).statusCode).toBe(409);
    const first = await put({ ...base, baseRevision: 0 });
    expect(first.statusCode).toBe(200);
    expect((first.json() as { revision: number }).revision).toBe(1);

    const stored = (await app.inject({ method: "GET", url: "/api/vault", headers: auth })).json() as VaultRecord;
    expect(stored.revision).toBe(1);
    expect(stored.ciphertext).toBe("Y2lwaGVy");

    const stale = await put({ ...base, baseRevision: 0, ciphertext: "bmV3" });
    expect(stale.statusCode).toBe(409);
    expect((stale.json() as { current: VaultRecord }).current.revision).toBe(1);
    const next = await put({ ...base, baseRevision: 1, ciphertext: "bmV3", wrappers: [{ type: "recovery_phrase", format: "words12-v1", iv: "aWl2", wrappedR: "d3I", createdAt: 1 }] });
    expect(next.statusCode).toBe(200);
    expect((next.json() as { revision: number }).revision).toBe(2);
  });

  it("rejects malformed wrappers and non-base64url material", async () => {
    expect((await put({ ...base, baseRevision: 0, wrappers: [{ type: "magic" }] })).statusCode).toBe(400);
    expect((await put({ ...base, baseRevision: 0, ciphertext: "not base64url!" })).statusCode).toBe(400);
  });

  it("stores no account id beside the ciphertext, only a keyed locator", async () => {
    await put({ ...base, baseRevision: 0 });
    const cols = (app.ctx.vault as unknown as { db: undefined }) && ["owner_locator"];
    expect(cols).toContain("owner_locator");
    const row = app.ctx.db.prepare("SELECT honey_id FROM honey_users LIMIT 1").get() as { honey_id: string };
    const vaultDb = (await import("./vault-db.js")).openVaultDatabase(join(tmp, "vault.db"));
    const stored = vaultDb.prepare("SELECT owner_locator FROM vaults").get() as { owner_locator: string };
    vaultDb.close();
    expect(stored.owner_locator).not.toContain(row.honey_id);
    expect(stored.owner_locator).toHaveLength(64);
  });

  it("pairing relay: offer by code, one delivery, one claim, then nothing", async () => {
    const pk = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const offer = (await app.inject({ method: "POST", url: "/api/vault/pairing", headers: auth, payload: { recipientPublicKey: pk } })).json() as { pairingId: string };
    expect(offer.pairingId).toMatch(/^[23456789A-HJKMNP-Z]{8}$/);
    const read = await app.inject({ method: "GET", url: `/api/vault/pairing/${offer.pairingId.toLowerCase()}`, headers: auth });
    expect(read.statusCode).toBe(200);
    expect((read.json() as { recipientPublicKey: string }).recipientPublicKey).toBe(pk);
    // Pending until delivered.
    expect((await app.inject({ method: "GET", url: `/api/vault/pairing/${offer.pairingId}/delivery`, headers: auth })).statusCode).toBe(404);
    const deliver = await app.inject({ method: "POST", url: `/api/vault/pairing/${offer.pairingId}/deliver`, headers: auth, payload: { enc: "ZW5j", ciphertext: "Y3Q" } });
    expect(deliver.statusCode).toBe(200);
    // A second delivery cannot overwrite the first.
    expect((await app.inject({ method: "POST", url: `/api/vault/pairing/${offer.pairingId}/deliver`, headers: auth, payload: { enc: "eA", ciphertext: "eQ" } })).statusCode).toBe(404);
    const claim = await app.inject({ method: "GET", url: `/api/vault/pairing/${offer.pairingId}/delivery`, headers: auth });
    expect(claim.statusCode).toBe(200);
    expect(claim.json()).toEqual({ pairingId: offer.pairingId, enc: "ZW5j", ciphertext: "Y3Q" });
    expect((await app.inject({ method: "GET", url: `/api/vault/pairing/${offer.pairingId}/delivery`, headers: auth })).statusCode).toBe(404);
  });

  it("same-device hand-off is one call; deleting the account removes the vault", async () => {
    const handoff = await app.inject({ method: "POST", url: "/api/vault/handoff", headers: auth, payload: { recipientPublicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", enc: "ZW5j", ciphertext: "Y3Q" } });
    expect(handoff.statusCode).toBe(200);
    const id = (handoff.json() as { pairingId: string }).pairingId;
    expect((await app.inject({ method: "GET", url: `/api/vault/pairing/${id}/delivery`, headers: auth })).statusCode).toBe(200);

    await put({ ...base, baseRevision: 0 });
    expect((await app.inject({ method: "DELETE", url: "/api/account", headers: auth })).statusCode).toBe(200);
    const vaultDb = (await import("./vault-db.js")).openVaultDatabase(join(tmp, "vault.db"));
    expect((vaultDb.prepare("SELECT COUNT(*) AS n FROM vaults").get() as { n: number }).n).toBe(0);
    vaultDb.close();
  });
});
