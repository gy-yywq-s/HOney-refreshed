import type { DatabaseSync } from "node:sqlite";
import type { AuthSession, PortalIdentity } from "@honey/shared";
import type { HoneyConfig } from "../config.js";
import { generateHoneyId, generateToken, hashToken, open, seal } from "../crypto.js";

// Account lifecycle (spec §3): there is no signup. A validated school login
// provisions (or reconnects) the Honey account and issues Honey's own session,
// whose lifetime is fully independent of the portal session.

export interface HoneyUserRow {
  honey_id: string;
  school_account_key: string;
  display_name: string;
  student_type: number;
  created_at: number;
}

export interface IssuedSession {
  accessToken: string;
  accessExpiresAt: Date;
  refreshToken: string;
  refreshExpiresAt: Date;
}

export interface ProvisionResult {
  user: HoneyUserRow;
  created: boolean;
  session: IssuedSession;
}

export class AccountService {
  constructor(
    private readonly db: DatabaseSync,
    private readonly config: HoneyConfig,
    private readonly now: () => number = Date.now,
  ) {}

  /**
   * Called after the portal validated a school login. Provisions on first
   * sight (random honeyId), reconnects otherwise; always stores the fresh
   * portal token (sealed) and issues a Honey session.
   */
  provisionFromPortal(identity: PortalIdentity, portalSession: AuthSession): ProvisionResult {
    const key = identity.schoolAccountIdentifier;
    let user = this.db
      .prepare("SELECT * FROM honey_users WHERE school_account_key = ?")
      .get(key) as unknown as HoneyUserRow | undefined;
    let created = false;

    if (!user) {
      const honeyId = this.uniqueHoneyId();
      this.db
        .prepare(
          "INSERT INTO honey_users (honey_id, school_account_key, display_name, student_type, created_at) VALUES (?, ?, ?, ?, ?)",
        )
        .run(honeyId, key, identity.name, identity.type, this.now());
      this.db
        .prepare("INSERT INTO import_consents (honey_id, timetable) VALUES (?, 0)")
        .run(honeyId);
      user = this.db
        .prepare("SELECT * FROM honey_users WHERE honey_id = ?")
        .get(honeyId) as unknown as HoneyUserRow;
      created = true;
    } else if (user.display_name !== identity.name && identity.name) {
      this.db
        .prepare("UPDATE honey_users SET display_name = ? WHERE honey_id = ?")
        .run(identity.name, user.honey_id);
      user.display_name = identity.name;
    }

    this.storePortalToken(user.honey_id, identity.studentId, portalSession);
    return { user, created, session: this.issueSession(user.honey_id) };
  }

  storePortalToken(honeyId: string, studentId: string, portalSession: AuthSession): void {
    const sealed = seal(portalSession.token, this.config.sealKey);
    this.db
      .prepare(
        `INSERT INTO school_connections (honey_id, student_id, portal_token_sealed, token_expires_at, connected)
         VALUES (?, ?, ?, ?, 1)
         ON CONFLICT(honey_id) DO UPDATE SET
           student_id = excluded.student_id,
           portal_token_sealed = excluded.portal_token_sealed,
           token_expires_at = excluded.token_expires_at,
           connected = 1`,
      )
      .run(honeyId, studentId, sealed, portalSession.expiresAt.getTime());
  }

  /** null when absent/expired — caller decides whether that means reconnect. */
  loadPortalToken(honeyId: string): { token: string; studentId: string; expiresAt: Date } | null {
    const row = this.db
      .prepare("SELECT * FROM school_connections WHERE honey_id = ?")
      .get(honeyId) as
      | {
          student_id: string;
          portal_token_sealed: Uint8Array | null;
          token_expires_at: number | null;
        }
      | undefined;
    if (!row?.portal_token_sealed || !row.token_expires_at) return null;
    if (row.token_expires_at <= this.now()) return null;
    return {
      token: open(Buffer.from(row.portal_token_sealed), this.config.sealKey),
      studentId: row.student_id,
      expiresAt: new Date(row.token_expires_at),
    };
  }

  markPortalExpired(honeyId: string): void {
    this.db
      .prepare(
        "UPDATE school_connections SET portal_token_sealed = NULL, token_expires_at = NULL WHERE honey_id = ?",
      )
      .run(honeyId);
  }

  issueSession(honeyId: string): IssuedSession {
    const accessToken = generateToken();
    const refreshToken = generateToken();
    const now = this.now();
    const accessExpiresAt = new Date(now + this.config.accessTtlMs);
    const refreshExpiresAt = new Date(now + this.config.refreshTtlMs);
    this.db
      .prepare(
        "INSERT INTO honey_sessions (access_hash, honey_id, refresh_hash, access_expires_at, refresh_expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      )
      .run(
        hashToken(accessToken),
        honeyId,
        hashToken(refreshToken),
        accessExpiresAt.getTime(),
        refreshExpiresAt.getTime(),
        now,
      );
    return { accessToken, accessExpiresAt, refreshToken, refreshExpiresAt };
  }

  authenticate(accessToken: string): HoneyUserRow | null {
    const row = this.db
      .prepare(
        `SELECT u.* FROM honey_sessions s JOIN honey_users u ON u.honey_id = s.honey_id
         WHERE s.access_hash = ? AND s.access_expires_at > ?`,
      )
      .get(hashToken(accessToken), this.now()) as unknown as HoneyUserRow | undefined;
    return row ?? null;
  }

  /** Rotating refresh: old refresh token is consumed, a fresh session row is issued. */
  refresh(refreshToken: string): IssuedSession | null {
    const row = this.db
      .prepare(
        "SELECT honey_id FROM honey_sessions WHERE refresh_hash = ? AND refresh_expires_at > ?",
      )
      .get(hashToken(refreshToken), this.now()) as unknown as { honey_id: string } | undefined;
    if (!row) return null;
    this.db.prepare("DELETE FROM honey_sessions WHERE refresh_hash = ?").run(hashToken(refreshToken));
    return this.issueSession(row.honey_id);
  }

  signOut(accessToken: string): void {
    this.db.prepare("DELETE FROM honey_sessions WHERE access_hash = ?").run(hashToken(accessToken));
  }

  /** Disconnect school account: drop portal material; Honey account stays (spec §3.7). */
  disconnectSchool(honeyId: string): void {
    this.db
      .prepare(
        "UPDATE school_connections SET portal_token_sealed = NULL, token_expires_at = NULL, connected = 0 WHERE honey_id = ?",
      )
      .run(honeyId);
  }

  /** Delete the Honey account (cascades sessions/connections/consents/exposures). */
  deleteAccount(honeyId: string): void {
    this.db.prepare("DELETE FROM honey_users WHERE honey_id = ?").run(honeyId);
  }

  getConsent(honeyId: string): { timetable: boolean; grantedAt: Date | null } {
    const row = this.db
      .prepare("SELECT timetable, granted_at FROM import_consents WHERE honey_id = ?")
      .get(honeyId) as unknown as { timetable: number; granted_at: number | null } | undefined;
    return {
      timetable: row?.timetable === 1,
      grantedAt: row?.granted_at ? new Date(row.granted_at) : null,
    };
  }

  setConsent(honeyId: string, timetable: boolean): void {
    this.db
      .prepare(
        `INSERT INTO import_consents (honey_id, timetable, granted_at, revoked_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(honey_id) DO UPDATE SET
           timetable = excluded.timetable,
           granted_at = CASE WHEN excluded.timetable = 1 THEN excluded.granted_at ELSE import_consents.granted_at END,
           revoked_at = CASE WHEN excluded.timetable = 0 THEN excluded.revoked_at ELSE NULL END`,
      )
      .run(honeyId, timetable ? 1 : 0, timetable ? this.now() : null, timetable ? null : this.now());
  }

  getConnection(honeyId: string): { connected: boolean; lastSyncedAt: Date | null; portalTokenValid: boolean } {
    const row = this.db
      .prepare("SELECT connected, last_synced_at, token_expires_at FROM school_connections WHERE honey_id = ?")
      .get(honeyId) as
      | { connected: number; last_synced_at: number | null; token_expires_at: number | null }
      | undefined;
    return {
      connected: row?.connected === 1,
      lastSyncedAt: row?.last_synced_at ? new Date(row.last_synced_at) : null,
      portalTokenValid: !!row?.token_expires_at && row.token_expires_at > this.now(),
    };
  }

  markSynced(honeyId: string): void {
    this.db
      .prepare("UPDATE school_connections SET last_synced_at = ? WHERE honey_id = ?")
      .run(this.now(), honeyId);
  }

  /** Wipe imported timetable data for this user (settings: delete imported data). */
  deleteImportedData(honeyId: string): void {
    this.db.prepare("DELETE FROM user_lesson_exposures WHERE honey_id = ?").run(honeyId);
  }

  isAdmin(honeyId: string): boolean {
    const row = this.db
      .prepare("SELECT student_id FROM school_connections WHERE honey_id = ?")
      .get(honeyId) as unknown as { student_id: string } | undefined;
    return row?.student_id === this.config.adminStudentId;
  }

  private uniqueHoneyId(): string {
    for (let attempt = 0; attempt < 20; attempt++) {
      const id = generateHoneyId();
      const exists = this.db
        .prepare("SELECT 1 FROM honey_users WHERE honey_id = ?")
        .get(id);
      if (!exists) return id;
    }
    // 31^6 ≈ 888M ids — 20 collisions in a school-sized table is effectively impossible.
    throw new Error("could not allocate honeyId");
  }
}
