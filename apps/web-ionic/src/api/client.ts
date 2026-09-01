import type {
  CheckExperienceInput,
  CheckExperienceResponse,
  DirectoryResponse,
  EntitiesResponse,
  EntityType,
  ExperienceEligibilityInput,
  ExperienceEligibilityResponse,
  FeedPage,
  FeedParams,
  FeedScope,
  FeedUpdatesResponse,
  HistoryParams,
  HistoryResponse,
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
  SyncResponse,
  TimetableResponse,
} from "@honey/shared/api";
import { FixtureClient } from "./fixtures";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message?: string,
  ) {
    super(message ?? code);
    this.name = "ApiError";
  }
}

export interface HoneyClient {
  readonly fixtureMode: boolean;
  onSessionLost: (() => void) | null;
  hasSession(): boolean;
  login(input: LoginInput): Promise<LoginResponse>;
  logout(): Promise<void>;
  me(): Promise<Me>;
  setConsent(timetable: boolean): Promise<void>;
  syncSeamless(): Promise<{ result: SyncResponse; reconnected: boolean }>;
  nextLesson(): Promise<NextLessonResponse>;
  timetable(date: string): Promise<TimetableResponse>;
  history(params?: HistoryParams): Promise<HistoryResponse>;
  directory(): Promise<DirectoryResponse>;
  entities(type?: EntityType, q?: string): Promise<EntitiesResponse>;
  feedPage(params: FeedParams): Promise<FeedPage>;
  feedUpdates(scope: FeedScope, head: string): Promise<FeedUpdatesResponse>;
  experienceEligibility(input: ExperienceEligibilityInput): Promise<ExperienceEligibilityResponse>;
  checkExperience(input: CheckExperienceInput): Promise<CheckExperienceResponse>;
  publishExperience(input: PublishExperienceInput): Promise<PublishExperienceResponse>;
  myExperiences(keys: string[]): Promise<MyExperiencesResponse>;
  revokeExperience(ownershipKey: string): Promise<{ ok: boolean }>;
  reactToExperience(id: string, value: 1 | -1 | 0): Promise<ReactResponse>;
  reportExperience(id: string, category: ReportCategory): Promise<{ ok: boolean }>;
  disconnectSchool(): Promise<void>;
  deleteImportedData(): Promise<void>;
  deleteAccount(): Promise<void>;
}

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;
const SESSION_KEY = "HOney.ionic.session";

export class LiveClient implements HoneyClient {
  readonly fixtureMode = false;
  onSessionLost: (() => void) | null = null;
  private refreshing: Promise<boolean> | null = null;

  constructor(private readonly fetchFn: FetchLike = (input, init) => fetch(input, init)) {}

  hasSession(): boolean {
    return this.session !== null;
  }

  async login(input: LoginInput): Promise<LoginResponse> {
    const result = await this.request<LoginResponse>("POST", "/api/auth/login", input, { auth: false });
    this.storeSession(result.session);
    return result;
  }

  async logout(): Promise<void> {
    try {
      if (this.hasSession()) await this.request("POST", "/api/auth/logout", undefined, { retryOn401: false });
    } finally {
      this.clearSession();
    }
  }

  me(): Promise<Me> { return this.request("GET", "/api/me"); }
  setConsent(timetable: boolean): Promise<void> { return this.request("POST", "/api/consent", { timetable }); }
  nextLesson(): Promise<NextLessonResponse> { return this.request("GET", "/api/next-lesson"); }
  timetable(date: string): Promise<TimetableResponse> { return this.request("GET", `/api/timetable?date=${encodeURIComponent(date)}`); }

  history(params: HistoryParams = {}): Promise<HistoryResponse> {
    return this.request("GET", withQuery("/api/history", params));
  }

  directory(): Promise<DirectoryResponse> { return this.request("GET", "/api/directory"); }

  entities(type?: EntityType, q?: string): Promise<EntitiesResponse> {
    return this.request("GET", withQuery("/api/entities", { type, q }));
  }

  feedPage(params: FeedParams): Promise<FeedPage> {
    return this.request("GET", withQuery("/api/experiences/feed", params));
  }

  feedUpdates(scope: FeedScope, head: string): Promise<FeedUpdatesResponse> {
    return this.request("GET", withQuery("/api/experiences/feed/updates", { scope, head }));
  }

  experienceEligibility(input: ExperienceEligibilityInput): Promise<ExperienceEligibilityResponse> {
    return this.request("POST", "/api/experiences/eligibility", input);
  }

  checkExperience(input: CheckExperienceInput): Promise<CheckExperienceResponse> {
    return this.request("POST", "/api/experiences/check", input);
  }

  publishExperience(input: PublishExperienceInput): Promise<PublishExperienceResponse> {
    return this.request("POST", "/api/experiences/publish", input, { auth: false });
  }

  myExperiences(keys: string[]): Promise<MyExperiencesResponse> {
    return this.request("POST", "/api/experiences/mine", { keys });
  }

  revokeExperience(ownershipKey: string): Promise<{ ok: boolean }> {
    return this.request("POST", "/api/experiences/revoke", { ownershipKey });
  }

  reactToExperience(id: string, value: 1 | -1 | 0): Promise<ReactResponse> {
    return this.request("POST", `/api/experiences/${encodeURIComponent(id)}/react`, { value });
  }

  reportExperience(id: string, category: ReportCategory): Promise<{ ok: boolean }> {
    return this.request("POST", `/api/experiences/${encodeURIComponent(id)}/report`, { category });
  }

  disconnectSchool(): Promise<void> { return this.request("POST", "/api/school/disconnect"); }
  deleteImportedData(): Promise<void> { return this.request("DELETE", "/api/imported-data"); }

  async deleteAccount(): Promise<void> {
    await this.request("DELETE", "/api/account");
    this.clearSession();
  }

  async syncSeamless(): Promise<{ result: SyncResponse; reconnected: boolean }> {
    return { result: await this.request("POST", "/api/sync"), reconnected: false };
  }

  private get session(): SessionTokens | null {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    try { return JSON.parse(raw) as SessionTokens; } catch { return null; }
  }

  private storeSession(session: SessionTokens): void { localStorage.setItem(SESSION_KEY, JSON.stringify(session)); }
  private clearSession(): void { localStorage.removeItem(SESSION_KEY); }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
    options: { auth?: boolean; retryOn401?: boolean } = {},
  ): Promise<T> {
    const { auth = true, retryOn401 = true } = options;
    const headers: Record<string, string> = { Accept: "application/json" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (auth) {
      const session = this.session;
      if (!session) throw new ApiError(401, "not_authenticated");
      headers.Authorization = `Bearer ${session.accessToken}`;
    }

    let response: Response;
    try {
      response = await this.fetchFn(path, {
        method,
        headers,
        ...(auth ? {} : { credentials: "omit" as const }),
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch {
      throw new ApiError(0, "network_error");
    }

    if (response.status === 401 && auth) {
      if (retryOn401 && (await this.refreshSession())) {
        return this.request(method, path, body, { auth, retryOn401: false });
      }
      this.clearSession();
      this.onSessionLost?.();
      throw new ApiError(401, "session_expired");
    }
    if (!response.ok) throw await responseError(response);
    const text = await response.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }

  private refreshSession(): Promise<boolean> {
    this.refreshing ??= this.doRefresh().finally(() => { this.refreshing = null; });
    return this.refreshing;
  }

  private async doRefresh(): Promise<boolean> {
    const session = this.session;
    if (!session) return false;
    try {
      const response = await this.fetchFn("/api/auth/refresh", {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify({ refreshToken: session.refreshToken }),
      });
      if (!response.ok) return false;
      const data = (await response.json()) as SessionTokens | { session: SessionTokens };
      this.storeSession("session" in data ? data.session : data);
      return true;
    } catch {
      return false;
    }
  }
}

function withQuery(path: string, values: object): string {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== "") query.set(key, String(value));
  }
  const encoded = query.toString();
  return encoded ? `${path}?${encoded}` : path;
}

async function responseError(response: Response): Promise<ApiError> {
  let code = `http_${response.status}`;
  try {
    const data = (await response.json()) as { error?: unknown };
    if (typeof data.error === "string") code = data.error;
  } catch { /* non-JSON error */ }
  return new ApiError(response.status, code);
}

export function describeApiError(error: unknown): string {
  if (!(error instanceof ApiError)) return "Something went wrong. Please try again.";
  const copy: Record<string, string> = {
    network_error: "Could not reach HOney. Check your connection and try again.",
    not_authenticated: "Continue with your school account to use HOney.",
    session_expired: "Your HOney session has expired. Sign in again.",
    school_credentials_rejected: "The school portal rejected that username or password.",
    portal_interactive_challenge: "The school portal needs an interactive sign-in before HOney can reconnect.",
    portal_unavailable: "The school portal is unavailable right now. Try again in a few minutes.",
  };
  return copy[error.code] ?? `Something went wrong (${error.code}).`;
}

const fixtureRequested =
  import.meta.env.VITE_DEMO_FIXTURES === "1" ||
  (typeof window !== "undefined" && new URLSearchParams(window.location.search).get("demo") === "1");

export const api: HoneyClient = fixtureRequested ? new FixtureClient() : new LiveClient();
