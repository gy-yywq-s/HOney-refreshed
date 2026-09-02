// Control Vault records + the pairing relay (spec §35, §38, §40.2). Writes are
// compare-and-swap on the revision; the relay keeps HPKE ciphertext for five
// minutes and hands it out once.

import { createHmac, randomInt } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import type { PairingDelivery, PairingOffer, VaultPutRequest, VaultPutResponse, VaultRecord, VaultWrapper } from "@honey/shared/community-v2";

const PAIRING_TTL_MS = 5 * 60_000;
const PAIRING_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";

export class ControlVaultStore {
  constructor(
    private readonly db: DatabaseSync,
    private readonly locatorKey: Buffer,
    private readonly now: () => number = Date.now,
  ) {}

  locator(honeyId: string): string {
    return createHmac("sha256", this.locatorKey).update(honeyId).digest("hex");
  }

  get(honeyId: string): VaultRecord | null {
    const row = this.db
      .prepare("SELECT vault_id, revision, iv, ciphertext, wrappers, updated_at FROM vaults WHERE owner_locator = ?")
      .get(this.locator(honeyId)) as
      | { vault_id: string; revision: number; iv: string; ciphertext: string; wrappers: string; updated_at: number }
      | undefined;
    if (!row) return null;
    return {
      vaultId: row.vault_id,
      revision: row.revision,
      iv: row.iv,
      ciphertext: row.ciphertext,
      wrappers: JSON.parse(row.wrappers) as VaultWrapper[],
      updatedAt: row.updated_at,
    };
  }

  /** CAS write: baseRevision must equal the stored revision (0 for a first write). */
  put(honeyId: string, input: VaultPutRequest): VaultPutResponse {
    const locator = this.locator(honeyId);
    const current = this.get(honeyId);
    if (current && (current.revision !== input.baseRevision || current.vaultId !== input.vaultId)) {
      return { ok: false, error: "conflict", current };
    }
    if (!current && input.baseRevision !== 0) {
      return { ok: false, error: "conflict", current: { vaultId: input.vaultId, revision: 0, iv: "", ciphertext: "", wrappers: [], updatedAt: 0 } };
    }
    const revision = input.baseRevision + 1;
    const t = this.now();
    this.db
      .prepare(
        `INSERT INTO vaults (vault_id, owner_locator, revision, iv, ciphertext, wrappers, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(owner_locator) DO UPDATE SET
           revision = excluded.revision, iv = excluded.iv, ciphertext = excluded.ciphertext,
           wrappers = excluded.wrappers, updated_at = excluded.updated_at`,
      )
      .run(input.vaultId, locator, revision, input.iv, input.ciphertext, JSON.stringify(input.wrappers), t, t);
    return { ok: true, revision, updatedAt: t };
  }

  delete(honeyId: string): void {
    const locator = this.locator(honeyId);
    this.db.prepare("DELETE FROM vaults WHERE owner_locator = ?").run(locator);
    this.db.prepare("DELETE FROM pairings WHERE owner_locator = ?").run(locator);
  }

  // ---- pairing relay ----

  private sweepPairings(): void {
    this.db.prepare("DELETE FROM pairings WHERE expires_at <= ?").run(this.now());
  }

  private newPairingId(): string {
    let id = "";
    for (let i = 0; i < 8; i++) id += PAIRING_ALPHABET[randomInt(PAIRING_ALPHABET.length)];
    return id;
  }

  /** The new device announces its ephemeral public key; gets a short code. */
  offer(honeyId: string, recipientPublicKey: string): PairingOffer {
    this.sweepPairings();
    const pairingId = this.newPairingId();
    const expiresAt = this.now() + PAIRING_TTL_MS;
    this.db
      .prepare("INSERT INTO pairings (pairing_id, owner_locator, recipient_public_key, created_at, expires_at) VALUES (?, ?, ?, ?, ?)")
      .run(pairingId, this.locator(honeyId), recipientPublicKey, this.now(), expiresAt);
    return { pairingId, recipientPublicKey, expiresAt };
  }

  /** The signed-in device reads the offer by code (same account only). */
  readOffer(honeyId: string, pairingId: string): PairingOffer | null {
    this.sweepPairings();
    const row = this.db
      .prepare("SELECT recipient_public_key, expires_at FROM pairings WHERE pairing_id = ? AND owner_locator = ? AND ciphertext IS NULL")
      .get(pairingId.toUpperCase(), this.locator(honeyId)) as { recipient_public_key: string; expires_at: number } | undefined;
    return row ? { pairingId: pairingId.toUpperCase(), recipientPublicKey: row.recipient_public_key, expiresAt: row.expires_at } : null;
  }

  deliver(honeyId: string, delivery: PairingDelivery): boolean {
    this.sweepPairings();
    const res = this.db
      .prepare("UPDATE pairings SET enc = ?, ciphertext = ? WHERE pairing_id = ? AND owner_locator = ? AND ciphertext IS NULL")
      .run(delivery.enc, delivery.ciphertext, delivery.pairingId.toUpperCase(), this.locator(honeyId));
    return res.changes === 1;
  }

  /** Same-device hand-off: offer and delivery in one step (the private half rides in the URL fragment). */
  handoff(honeyId: string, recipientPublicKey: string, delivery: Omit<PairingDelivery, "pairingId">): PairingOffer {
    const offer = this.offer(honeyId, recipientPublicKey);
    this.deliver(honeyId, { pairingId: offer.pairingId, ...delivery });
    return offer;
  }

  /** The new device collects the ciphertext exactly once; the row is gone afterwards. */
  claim(honeyId: string, pairingId: string): PairingDelivery | null {
    this.sweepPairings();
    const id = pairingId.toUpperCase();
    const row = this.db
      .prepare("SELECT enc, ciphertext FROM pairings WHERE pairing_id = ? AND owner_locator = ? AND ciphertext IS NOT NULL")
      .get(id, this.locator(honeyId)) as { enc: string; ciphertext: string } | undefined;
    if (!row) return null;
    this.db.prepare("DELETE FROM pairings WHERE pairing_id = ?").run(id);
    return { pairingId: id, enc: row.enc, ciphertext: row.ciphertext };
  }
}
