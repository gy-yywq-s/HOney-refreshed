// The identity-free client for HOney Community (`/community/v2/*`). Every
// request here omits credentials and carries no Authorization header: the
// process on the other side has no account database, and this client must
// never give it a correlation handle. Proofs (tokens, signed statements) are
// the only authentication.

import type {
  CheckRequestV2,
  CheckResponseV2,
  ChallengeResponse,
  EntityStatsV2,
  FeedPageV2,
  FeedRequestV2,
  FeedUpdatesRequestV2,
  FromMyClassesRequestV2,
  MineRequest,
  MineResponse,
  PublicExperienceV2,
  PublishRequestV2,
  PublishResponseV2,
  ReactRequestV2,
  RegisterReactorRequest,
  ReportRequestV2,
  RevokeRequest,
  SearchResponseV2,
} from "@honey/shared/community-v2";
import { ApiError } from "./client";

async function call<T>(method: "GET" | "POST", path: string, body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, {
      method,
      credentials: "omit",
      headers: { Accept: "application/json", ...(body !== undefined ? { "Content-Type": "application/json" } : {}) },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
  } catch {
    throw new ApiError(0, "network_error");
  }
  if (!res.ok) {
    let code = `http_${res.status}`;
    let parsed: unknown;
    try {
      parsed = await res.json();
      const e = (parsed as { error?: unknown }).error;
      if (typeof e === "string") code = e;
    } catch {
      /* non-JSON error */
    }
    throw new ApiError(res.status, code, undefined, parsed);
  }
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

export const community = {
  feed(req: FeedRequestV2): Promise<FeedPageV2> {
    return call("POST", "/community/v2/feed", req);
  },
  feedUpdates(req: FeedUpdatesRequestV2): Promise<{ newItemsAvailable: boolean }> {
    return call("POST", "/community/v2/feed/updates", req);
  },
  fromMyClasses(req: FromMyClassesRequestV2): Promise<{ experiences: PublicExperienceV2[] }> {
    return call("POST", "/community/v2/from-my-classes", req);
  },
  search(q: string): Promise<SearchResponseV2> {
    return call("GET", `/community/v2/search?q=${encodeURIComponent(q)}`);
  },
  stats(entityKey: string): Promise<EntityStatsV2> {
    return call("GET", `/community/v2/stats?entityKey=${encodeURIComponent(entityKey)}`);
  },
  check(req: CheckRequestV2): Promise<CheckResponseV2> {
    return call("POST", "/community/v2/check", req);
  },
  publish(req: PublishRequestV2): Promise<PublishResponseV2> {
    return call("POST", "/community/v2/publish", req);
  },
  mineChallenge(): Promise<ChallengeResponse> {
    return call("POST", "/community/v2/mine/challenge", {});
  },
  mine(req: MineRequest): Promise<MineResponse> {
    return call("POST", "/community/v2/mine", req);
  },
  revokeChallenge(id: string): Promise<ChallengeResponse> {
    return call("POST", `/community/v2/posts/${encodeURIComponent(id)}/revoke/challenge`, {});
  },
  revoke(id: string, req: RevokeRequest): Promise<{ ok: true }> {
    return call("POST", `/community/v2/posts/${encodeURIComponent(id)}/revoke`, req);
  },
  registerReactor(req: RegisterReactorRequest): Promise<{ ok: true }> {
    return call("POST", "/community/v2/reactors/register", req);
  },
  react(id: string, req: ReactRequestV2): Promise<{ ok: true; value: 1 | -1 | 0; reactions: { likes: number; dislikes: number } | null }> {
    return call("POST", `/community/v2/posts/${encodeURIComponent(id)}/react`, req);
  },
  report(id: string, req: ReportRequestV2): Promise<{ ok: true }> {
    return call("POST", `/community/v2/posts/${encodeURIComponent(id)}/report`, req);
  },
};
