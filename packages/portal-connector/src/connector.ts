import {
  portalWeekIndex,
  type AuthSession,
  type DoorOptionWire,
  type ExitPermitWire,
  type Lesson,
  type OpenDoorRequest,
  type PortalConnector,
  type PortalIdentity,
  type StoredCredentials,
} from "@honey/shared";
import { PortalApi } from "./api.js";
import { PortalHttp, retrySafeRead, type HttpOptions } from "./http.js";
import { joinLessons, sortLessons } from "./normalize.js";
import { PortalSessionCoordinator, type CredentialVault } from "./coordinator.js";

/**
 * Band-4 connector implementation. Raw upstream payloads live only inside
 * these calls (spec §5.2) — everything returned is normalized or a typed wire
 * record consumed immediately by the integration layer.
 */
export class HoneyPortalConnector implements PortalConnector {
  readonly api: PortalApi;
  readonly coordinator: PortalSessionCoordinator;

  constructor(opts: HttpOptions & { vault: CredentialVault; safetyWindowMs?: number; now?: () => Date }) {
    this.api = new PortalApi(new PortalHttp(opts));
    this.coordinator = new PortalSessionCoordinator(
      this.api,
      opts.vault,
      opts.safetyWindowMs,
      opts.now,
    );
  }

  async login(credentials: StoredCredentials): Promise<AuthSession> {
    const token = await this.api.login(credentials.username, credentials.password);
    const info = await this.api.userInfo(token);
    return { token, expiresAt: new Date(info.exp * 1000), studentId: String(info.id) };
  }

  async validate(session: AuthSession): Promise<PortalIdentity> {
    const d = await this.api.userInfo(session.token);
    const name =
      (typeof d.name === "string" && d.name) ||
      [d.first_name, d.last_name].filter(Boolean).join(" ");
    const identity: PortalIdentity = {
      studentId: String(d.id),
      name: name || String(d.id),
      schoolAccountIdentifier: (typeof d.email === "string" && d.email) || String(d.id),
      type: d.type,
      tokenExpiresAt: new Date(d.exp * 1000),
    };
    if (typeof d.campus_id === "number") identity.campusId = d.campus_id;
    if (d.day_student !== undefined) identity.dayStudent = d.day_student === 1 || d.day_student === true;
    return identity;
  }

  async reauthenticate(credentials: StoredCredentials): Promise<AuthSession> {
    return this.login(credentials);
  }

  /** Fetch + join + normalize lessons covering [from, to]. Safe read: bounded retries + replay-once. */
  async getLessons(from: Date, to: Date): Promise<Lesson[]> {
    if (to.getTime() < from.getTime()) return [];
    return this.coordinator.withAuthentication("safeRead", async (token) => {
      const me = await retrySafeRead(() => this.api.userInfo(token));
      const studentId = me.id;
      const table = await retrySafeRead(() => this.api.lessonTable(token));

      const firstWeek = portalWeekIndex(from);
      const lastWeek = portalWeekIndex(to);
      // Caller error, not a portal-taxonomy error (cap at 60 weekly fetches).
      if (lastWeek - firstWeek + 1 > 60) throw new RangeError("lesson range exceeds 60 weeks");
      const weeks: number[] = [];
      for (let w = firstWeek; w <= lastWeek; w++) weeks.push(w);

      const weekly = await Promise.all(
        weeks.map((w) => retrySafeRead(() => this.api.weeklySchedule(token, studentId, w))),
      );
      const joined = joinLessons(weekly.flatMap((w) => w.lessons), table);
      return sortLessons(
        joined.filter((l) => l.endsAt.getTime() >= from.getTime() && l.startsAt.getTime() <= to.getTime()),
      );
    });
  }

  async getPermits(): Promise<ExitPermitWire[]> {
    return this.coordinator.withAuthentication("safeRead", (token) =>
      retrySafeRead(() => this.api.permitList(token)),
    );
  }

  async getDoors(): Promise<DoorOptionWire[]> {
    return this.coordinator.withAuthentication("safeRead", (token) =>
      retrySafeRead(() => this.api.doorList(token)),
    );
  }

  /** Physical gate open. Never retried, never replayed; expiry surfaces to the caller. */
  async openDoor(request: OpenDoorRequest): Promise<void> {
    await this.coordinator.withAuthentication("nonIdempotent", (token) =>
      this.api.openDoor(token, request.permitRecordId, request.doorKey),
    );
  }

  async logout(): Promise<void> {
    await this.coordinator.signOut();
  }
}
