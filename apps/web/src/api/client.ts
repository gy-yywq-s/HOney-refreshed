// Typed HTTP client for the HOney backend (same-origin /api/*).
// Sessions persist in localStorage; a 401 on an authed call triggers one
// single-flight refresh + retry, after which the session is dropped and
// `onSessionLost` fires (the app shell redirects to /login).

import { portalCredentials } from "../lib/portalCredentials";
import type {
  AdminImportResult,
  AdminLlmTestResponse,
  AdminOverview,
  AdminReportsResponse,
  CheckExperienceInput,
  CheckExperienceResponse,
  DirectoryResponse,
  EntitiesResponse,
  EntityType,
  ExperienceEligibilityInput,
  ExperienceEligibilityResponse,
  ExperiencesFeedParams,
  ExperiencesFeedResponse,
  FromMyClassesParams,
  HistoryParams,
  HistoryResponse,
  KillSwitchName,
  LoginInput,
  LoginResponse,
  Me,
  MyExperiencesResponse,
  NextLessonResponse,
  PublishExperienceInput,
  PublishExperienceResponse,
  ReactResponse,
  ReportCategory,
  SessionTokens,
  StandaloneMode,
  SyncResponse,
  TimetableResponse,
} from "./types";

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface SessionStorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface ApiClientOptions {
  fetchFn?: FetchLike;
  storage?: SessionStorageLike;
}

const SESSION_KEY = "HOney.session";

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message?: string) {
    super(message ?? code);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

function memoryStorage(): SessionStorageLike {
  const map = new Map<string, string>();
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
  };
}

export class ApiClient {
  /** Set by the app shell; called when the session is unrecoverable. */
  onSessionLost: (() => void) | null = null;

  private readonly fetchFn: FetchLike;
  private readonly storage: SessionStorageLike;
  private refreshing: Promise<boolean> | null = null;

  constructor(options: ApiClientOptions = {}) {
    this.fetchFn = options.fetchFn ?? ((input, init) => fetch(input, init));
    this.storage =
      options.storage ?? (typeof localStorage === "undefined" ? memoryStorage() : localStorage);
  }

  hasSession(): boolean {
    return this.session !== null;
  }

  async login(input: LoginInput): Promise<LoginResponse> {
    const result = await this.request<LoginResponse>("POST", "/api/auth/login", input, {
      auth: false,
    });
    this.storeSession(result.session);
    return result;
  }

  async logout(): Promise<void> {
    if (this.hasSession()) {
      try {
        await this.request<void>("POST", "/api/auth/logout", undefined, { retryOn401: false });
      } catch {
        // Best effort — the local session is dropped regardless.
      }
    }
    this.clearSession();
  }

  me(): Promise<Me> {
    return this.request("GET", "/api/me");
  }

  setConsent(timetable: boolean): Promise<void> {
    return this.request("POST", "/api/consent", { timetable });
  }

  sync(): Promise<SyncResponse> {
    return this.request("POST", "/api/sync");
  }

  /**
   * Sync, but keep the connection seamless: if the portal token has expired and
   * this device holds authorized school credentials, silently re-login (the same
   * /api/auth/login the manual sign-in uses) and retry the sync ONCE. Mirrors the
   * iOS silent-recovery invariant — a manual prompt is only needed when the
   * credentials are actually rejected or the portal raises an interactive
   * challenge. Returns the sync result plus whether a silent reconnect happened.
   */
  async syncSeamless(): Promise<{ result: SyncResponse; reconnected: boolean }> {
    let result = await this.sync();
    if (result.status !== "portal_reconnect_required") return { result, reconnected: false };
    const creds = await portalCredentials.load();
    if (!creds) return { result, reconnected: false };
    // Silent re-login: replays the stored credentials transiently; the backend
    // re-seals a fresh portal token and never persists the password.
    await this.login({ username: creds.username, password: creds.password });
    result = await this.sync();
    return { result, reconnected: true };
  }

  timetable(date: string): Promise<TimetableResponse> {
    return this.request("GET", `/api/timetable?date=${encodeURIComponent(date)}`);
  }

  nextLesson(): Promise<NextLessonResponse> {
    return this.request("GET", "/api/next-lesson");
  }

  history(params: HistoryParams = {}): Promise<HistoryResponse> {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") query.set(key, String(value));
    }
    const qs = query.toString();
    return this.request("GET", qs ? `/api/history?${qs}` : "/api/history");
  }

  directory(): Promise<DirectoryResponse> {
    return this.request("GET", "/api/directory");
  }

  // ---- Experiences (community) ----

  entities(type?: EntityType, q?: string): Promise<EntitiesResponse> {
    const query = new URLSearchParams();
    if (type) query.set("type", type);
    if (q) query.set("q", q);
    const qs = query.toString();
    return this.request("GET", qs ? `/api/entities?${qs}` : "/api/entities");
  }

  experiencesFeed(params: ExperiencesFeedParams = {}): Promise<ExperiencesFeedResponse> {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") query.set(key, String(value));
    }
    const qs = query.toString();
    return this.request("GET", qs ? `/api/experiences?${qs}` : "/api/experiences");
  }

  /** Domain query (audit §4.2): posts relevant to my verified exposure. */
  fromMyClasses(params: FromMyClassesParams = {}): Promise<ExperiencesFeedResponse> {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") query.set(key, String(value));
    }
    const qs = query.toString();
    return this.request(
      "GET",
      qs ? `/api/experiences/from-my-classes?${qs}` : "/api/experiences/from-my-classes",
    );
  }

  // ---- Publication flow: eligibility → check → publish (contract §Experiences) ----

  /** Step 1: authenticated, single-use, scope-bound eligibility token. */
  experienceEligibility(
    input: ExperienceEligibilityInput,
  ): Promise<ExperienceEligibilityResponse> {
    return this.request("POST", "/api/experiences/eligibility", input);
  }

  /** Step 2: synchronous moderation preflight. The draft is NEVER persisted. */
  checkExperience(input: CheckExperienceInput): Promise<CheckExperienceResponse> {
    return this.request("POST", "/api/experiences/check", input);
  }

  /** Step 3: publish. No session auth — the eligibility token + pass are the only proof. */
  publishExperience(input: PublishExperienceInput): Promise<PublishExperienceResponse> {
    return this.request("POST", "/api/experiences/publish", input, { auth: false });
  }

  /** Own submissions, proved by client-held keys (any status). */
  myExperiences(keys: string[]): Promise<MyExperiencesResponse> {
    return this.request("POST", "/api/experiences/mine", { keys });
  }

  revokeExperience(ownershipKey: string): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/experiences/revoke", { ownershipKey });
  }

  reactToExperience(id: string, value: 1 | -1 | 0): Promise<ReactResponse> {
    return this.request("POST", `/api/experiences/${encodeURIComponent(id)}/react`, { value });
  }

  /** Reports are category-only (audit §3.9): the backend rejects any free text. */
  reportExperience(id: string, category: ReportCategory): Promise<{ ok: boolean }> {
    return this.request("POST", `/api/experiences/${encodeURIComponent(id)}/report`, { category });
  }

  // ---- Admin dash (isAdmin only) ----

  adminOverview(): Promise<AdminOverview> {
    return this.request("GET", "/api/admin/overview");
  }

  adminSetKillSwitch(name: KillSwitchName, on: boolean): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/kill-switch", { name, on });
  }

  adminSetStandaloneMode(scope: string, mode: StandaloneMode): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/standalone-mode", { scope, mode });
  }

  adminImportEntities(items: { type: EntityType; name: string }[]): Promise<AdminImportResult> {
    return this.request("POST", "/api/admin/entities/import", { items });
  }

  adminSetEntityActive(entityKey: string, active: boolean): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/entities/active", { entityKey, active });
  }

  adminFreezeEntity(entityKey: string, frozen: boolean): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/freeze-entity", { entityKey, frozen });
  }

  adminInvite(entityKey: string, studentId: string): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/invite", { entityKey, studentId });
  }

  adminSetLlm(input: { apiKey?: string; model?: string }): Promise<{ ok: boolean; configured: boolean }> {
    return this.request("POST", "/api/admin/llm", input);
  }

  adminTestLlm(): Promise<AdminLlmTestResponse> {
    return this.request("POST", "/api/admin/llm/test");
  }

  adminReports(): Promise<AdminReportsResponse> {
    return this.request("GET", "/api/admin/reports");
  }

  adminSetReactionMinCount(minCount: number): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/admin/reaction-min-count", { minCount });
  }

  disconnectSchool(): Promise<void> {
    return this.request("POST", "/api/school/disconnect");
  }

  deleteImportedData(): Promise<void> {
    return this.request("DELETE", "/api/imported-data");
  }

  async deleteAccount(): Promise<void> {
    await this.request<void>("DELETE", "/api/account");
    this.clearSession();
  }

  clearSession(): void {
    this.storage.removeItem(SESSION_KEY);
  }

  private get session(): SessionTokens | null {
    const raw = this.storage.getItem(SESSION_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as SessionTokens;
    } catch {
      return null;
    }
  }

  private storeSession(session: SessionTokens): void {
    this.storage.setItem(SESSION_KEY, JSON.stringify(session));
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
    opts: { auth?: boolean; retryOn401?: boolean } = {},
  ): Promise<T> {
    const { auth = true, retryOn401 = true } = opts;
    const headers: Record<string, string> = { Accept: "application/json" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth) {
      const session = this.session;
      if (!session) {
        this.onSessionLost?.();
        throw new ApiError(401, "not_authenticated");
      }
      headers["Authorization"] = `Bearer ${session.accessToken}`;
    }

    let res: Response;
    try {
      res = await this.fetchFn(path, {
        method,
        headers,
        // Unauthenticated calls (the identity-free publish) must never ride on
        // ambient credentials: even a future backend cookie may not link them.
        ...(auth ? {} : { credentials: "omit" as const }),
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
    } catch {
      throw new ApiError(0, "network_error");
    }

    if (res.status === 401 && auth) {
      if (retryOn401 && (await this.refreshSession())) {
        return this.request<T>(method, path, body, { auth, retryOn401: false });
      }
      this.clearSession();
      this.onSessionLost?.();
      throw new ApiError(401, "session_expired");
    }

    if (!res.ok) throw await toApiError(res);

    const text = await res.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }

  /** Single-flight: concurrent 401s share one refresh round-trip. */
  private refreshSession(): Promise<boolean> {
    this.refreshing ??= this.doRefresh().finally(() => {
      this.refreshing = null;
    });
    return this.refreshing;
  }

  private async doRefresh(): Promise<boolean> {
    const session = this.session;
    if (!session) return false;
    try {
      const res = await this.fetchFn("/api/auth/refresh", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ refreshToken: session.refreshToken }),
      });
      if (!res.ok) return false;
      // Tolerate both a bare token object and a `{ session: ... }` wrapper.
      const data = (await res.json()) as SessionTokens | { session: SessionTokens };
      this.storeSession("session" in data ? data.session : data);
      return true;
    } catch {
      return false;
    }
  }
}

async function toApiError(res: Response): Promise<ApiError> {
  let code = `http_${res.status}`;
  try {
    const data = (await res.json()) as { error?: unknown };
    if (typeof data.error === "string") code = data.error;
  } catch {
    // Non-JSON error body; fall back to the status code.
  }
  if ((res.status === 502 || res.status === 503) && code === `http_${res.status}`) {
    code = "portal_unavailable";
  }
  return new ApiError(res.status, code);
}

/** Maps API failures to user-facing copy. */
export function describeApiError(error: unknown): string {
  if (error instanceof ApiError) {
    switch (error.code) {
      case "school_credentials_rejected":
        return "The school portal rejected that username or password.";
      case "portal_interactive_challenge":
        return "The school portal is asking for an interactive verification. Sign in once on the portal website, then try again here.";
      case "portal_unavailable":
        return "The school portal is unreachable right now. Please try again in a few minutes.";
      case "network_error":
        return "Could not reach the HOney server. Check your connection and try again.";
      case "session_expired":
      case "not_authenticated":
        return "Your session has expired. Please sign in again.";
      default:
        break;
    }
    if (error.status === 502 || error.status === 503) {
      return "The school portal is unreachable right now. Please try again in a few minutes.";
    }
    return `Something went wrong (${error.code}).`;
  }
  return "Something went wrong. Please try again.";
}

export const api = new ApiClient();
