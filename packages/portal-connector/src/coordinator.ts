import type { AuthSession, StoredCredentials } from "@honey/shared";
import { isPortalError, sessionExpired, userActionRequired } from "./errors.js";
import type { PortalApi } from "./api.js";

// Session coordination per school account (mirrors the Swift actor blueprint):
// - at most one login/reauth in flight (single-flight);
// - safe reads may replay once after a successful reauth;
// - mutations NEVER auto-replay (door opens are physical actions);
// - normal expiry silently recovers when authorized credentials are available;
// - offline/5xx/timeout preserves the session (never signs the user out).

export type ReplayPolicy = "safeRead" | "nonIdempotent";

export type PortalSessionState =
  | { state: "restoring" }
  | { state: "authenticated"; session: AuthSession }
  | { state: "temporarilyUnavailable"; session?: AuthSession }
  | { state: "noCredentials" }
  | { state: "userActionRequired"; reason: "captcha" | "mfa" | "passwordChanged" | "unknown" }
  | { state: "incompatible" };

/**
 * Credential/session persistence boundary. Server-side HOney stores only
 * token+exp (never the school password); a credential-holding vault exists on
 * iOS (Keychain) and in tests. loadAuthorizedCredentialsSilently must never
 * trigger an interactive prompt (no biometric binding on this path).
 */
export interface CredentialVault {
  loadSession(): Promise<AuthSession | null>;
  saveSession(session: AuthSession): Promise<void>;
  deleteSession(): Promise<void>;
  loadAuthorizedCredentialsSilently(): Promise<StoredCredentials | null>;
  deleteCredentials(): Promise<void>;
}

const DEFAULT_SAFETY_WINDOW_MS = 5 * 60 * 1000;

export class PortalSessionCoordinator {
  private session: AuthSession | null = null;
  private stateValue: PortalSessionState = { state: "restoring" };
  private reauthInFlight: Promise<AuthSession> | null = null;
  private loginCallCount = 0;
  /** Bumped by signOut/forget: in-flight reauths from an older epoch discard their result. */
  private epoch = 0;

  constructor(
    private readonly api: PortalApi,
    private readonly vault: CredentialVault,
    private readonly safetyWindowMs = DEFAULT_SAFETY_WINDOW_MS,
    private readonly now: () => Date = () => new Date(),
  ) {}

  get state(): PortalSessionState {
    return this.stateValue;
  }

  /** Total POST /api/login calls issued (observability + tests). */
  get loginCalls(): number {
    return this.loginCallCount;
  }

  /** Restore on startup: saved token → authenticated; else silent login; else noCredentials. */
  async restore(): Promise<PortalSessionState> {
    this.stateValue = { state: "restoring" };
    const saved = await this.vault.loadSession();
    if (saved && this.isFresh(saved)) {
      this.session = saved;
      this.stateValue = { state: "authenticated", session: saved };
      return this.stateValue;
    }
    // Token missing/expired → attempt silent recovery from authorized credentials.
    try {
      const session = await this.reauthenticateSingleFlight();
      return this.stateValue = { state: "authenticated", session };
    } catch (e) {
      if (isPortalError(e)) {
        if (e.kind === "credentialsRejected") {
          this.stateValue = { state: "userActionRequired", reason: "passwordChanged" };
        } else if (e.kind === "userActionRequired" && e.info.kind === "userActionRequired") {
          this.stateValue = { state: "userActionRequired", reason: e.info.reason };
        } else if (e.kind === "schemaIncompatible") {
          this.stateValue = { state: "incompatible" };
        } else if (e.kind === "sessionExpired") {
          this.stateValue = { state: "noCredentials" };
        } else {
          // Offline/5xx/timeout: keep cache, do not sign out.
          this.stateValue = saved
            ? { state: "temporarilyUnavailable", session: saved }
            : { state: "temporarilyUnavailable" };
        }
        return this.stateValue;
      }
      throw e;
    }
  }

  /**
   * Run an authenticated operation. On sessionExpired: drop the token, do one
   * single-flight reauth, then replay ONLY if the operation is a safe read.
   * Non-idempotent operations surface the expiry to the caller instead.
   */
  async withAuthentication<T>(
    replay: ReplayPolicy,
    operation: (token: string) => Promise<T>,
  ): Promise<T> {
    const session = await this.currentOrRecoveredSession();
    try {
      return await operation(session.token);
    } catch (e) {
      if (!isPortalError(e) || e.kind !== "sessionExpired") throw e;
      // A LATE 401 may arrive after another caller already repaired the
      // session; never wipe a token newer than the one that failed.
      let fresh: AuthSession;
      if (this.session && this.session.token !== session.token) {
        fresh = this.session;
      } else {
        await this.invalidateSession();
        fresh = await this.reauthenticateSingleFlight();
      }
      if (replay === "safeRead") return await operation(fresh.token);
      // Fresh session obtained, but the caller must explicitly re-issue the
      // mutation (e.g. re-present the door-open confirmation).
      throw sessionExpired();
    }
  }

  /** Freshen the session before a sensitive mutation; never replays the mutation itself. */
  async prepareForSensitiveAction(): Promise<AuthSession> {
    return this.currentOrRecoveredSession();
  }

  async signOut(): Promise<void> {
    this.epoch += 1; // any in-flight reauth result is now stale
    const token = this.session?.token;
    this.session = null;
    this.stateValue = { state: "noCredentials" };
    await this.vault.deleteSession();
    if (token !== undefined) await this.api.logout(token);
  }

  /** Full local wipe ("Forget school login"): session + credentials. */
  async forgetEverything(): Promise<void> {
    this.epoch += 1; // any in-flight reauth must not resurrect the session
    this.session = null;
    this.stateValue = { state: "noCredentials" };
    await this.vault.deleteSession();
    await this.vault.deleteCredentials();
  }

  // ---- internals ----

  private isFresh(session: AuthSession): boolean {
    return session.expiresAt.getTime() - this.now().getTime() > this.safetyWindowMs;
  }

  private async currentOrRecoveredSession(): Promise<AuthSession> {
    if (this.session && this.isFresh(this.session)) return this.session;
    if (!this.session) {
      const saved = await this.vault.loadSession();
      if (saved) {
        this.session = saved;
        if (this.isFresh(saved)) {
          this.stateValue = { state: "authenticated", session: saved };
          return saved;
        }
      }
    }
    // Inside the safety window (or beyond): try to renew proactively, but if
    // silent recovery is impossible (no creds) or the portal is unreachable
    // while the current token is STILL clock-valid, keep using it until a real
    // 401 (doc 03: "continue until 401 rather than blocking the feature").
    const stillValid =
      this.session !== null && this.session.expiresAt.getTime() > this.now().getTime();
    try {
      return await this.reauthenticateSingleFlight();
    } catch (e) {
      if (
        stillValid &&
        isPortalError(e) &&
        (e.kind === "sessionExpired" ||
          e.kind === "networkUnavailable" ||
          e.kind === "serverUnavailable" ||
          e.kind === "timeout")
      ) {
        return this.session as AuthSession;
      }
      throw e;
    }
  }

  private async invalidateSession(): Promise<void> {
    this.session = null;
    await this.vault.deleteSession();
  }

  private reauthenticateSingleFlight(): Promise<AuthSession> {
    if (this.reauthInFlight) return this.reauthInFlight;
    const flight = this.doReauthenticate().finally(() => {
      this.reauthInFlight = null;
    });
    this.reauthInFlight = flight;
    return flight;
  }

  private async doReauthenticate(): Promise<AuthSession> {
    const startEpoch = this.epoch;
    const creds = await this.vault.loadAuthorizedCredentialsSilently();
    if (!creds) {
      // No authorized credential material → cannot recover silently.
      throw sessionExpired();
    }
    try {
      this.loginCallCount += 1;
      const token = await this.api.login(creds.username, creds.password);
      const info = await this.api.userInfo(token);
      const session: AuthSession = {
        token,
        expiresAt: new Date(info.exp * 1000),
        studentId: String(info.id),
      };
      if (this.epoch !== startEpoch) {
        // User signed out / forgot login while we were re-authenticating:
        // do not resurrect anything; discard the fresh token upstream too.
        await this.api.logout(session.token);
        throw sessionExpired();
      }
      await this.vault.saveSession(session);
      this.session = session;
      this.stateValue = { state: "authenticated", session };
      return session;
    } catch (e) {
      if (isPortalError(e)) {
        if (e.kind === "credentialsRejected") {
          // Stored password is stale: purge it so we do not hammer the portal.
          await this.vault.deleteSession();
          await this.vault.deleteCredentials();
          this.stateValue = { state: "userActionRequired", reason: "passwordChanged" };
          throw e;
        }
        if (e.kind === "userActionRequired" && e.info.kind === "userActionRequired") {
          this.stateValue = { state: "userActionRequired", reason: e.info.reason };
          throw userActionRequired(e.info.reason);
        }
        if (e.kind === "schemaIncompatible") {
          this.stateValue = { state: "incompatible" };
          throw e;
        }
        // Network/5xx/timeout: PRESERVE credentials, mark temporarily unavailable.
        this.stateValue = this.session
          ? { state: "temporarilyUnavailable", session: this.session }
          : { state: "temporarilyUnavailable" };
        throw e;
      }
      throw e;
    }
  }
}
