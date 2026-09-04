// The v2 publication flow on the Web (spec §31–§34), in one place:
//
//   1. post controls: the device's active root (created silently the first
//      time — no consent friction — unless a server vault exists that this
//      device has not restored yet);
//   2. eligibility: blind a token under the issuer key, ask Core (signed in),
//      finalize → a token Core cannot recognise, bound to the scope/context it
//      verified;
//   3. envelope: signed with the school/year posting key; a fresh post nonce
//      gives this post its own control key;
//   4. check → lane (+ pass) → publish, both to Community with credentials
//      omitted.
//
// Mine, revoke, reactions and reports use the same keys with challenges.

import {
  blindToken,
  finalizeToken,
  fromBase64Url,
  importIssuerPublicKey,
  postControlKeyPair,
  postingKeyPair,
  randomBytes,
  reactionKeyPair,
  signStatement,
  toBase64Url,
  type CheckResponseV2,
  type CommunityScope,
  type EligibilityInfo,
  type EligibilityToken,
  type IssuerDescriptor,
  type MineExperience,
  type SignedPostEnvelopeV2,
} from "@honey/shared/community-v2";
import { api } from "../../api/client";
import { community } from "../../api/community";
import { apiCache } from "../useApi";
import { localPostControls, type UnlockedRoots } from "./local-store";
import { postControls } from "./post-controls";

export class PostControlsUnavailable extends Error {
  constructor(readonly reason: "restore_needed" | "unsupported") {
    super(reason);
    this.name = "PostControlsUnavailable";
  }
}

export interface PublishTarget {
  lessonId?: string;
  entityKey?: string;
}

interface Session {
  scope: CommunityScope;
  issuer: IssuerDescriptor;
  issuerKey: CryptoKey;
}

let sessionPromise: Promise<Session> | null = null;

/** Scope (canonical exposure) and issuer descriptor, fetched once per session. */
export function communitySession(): Promise<Session> {
  sessionPromise ??= (async () => {
    const [scope, issuer] = await Promise.all([api.communityScope(), api.communityIssuer()]);
    return { scope, issuer, issuerKey: await importIssuerPublicKey(issuer.publicKey) };
  })().catch((err) => {
    sessionPromise = null;
    throw err;
  });
  return sessionPromise;
}

export function resetCommunitySession(): void {
  sessionPromise = null;
}

/** The active root for publishing; created silently when none exists anywhere. */
export async function ensureRoots(account: string): Promise<UnlockedRoots> {
  const status = await postControls.status(account);
  switch (status.kind) {
    case "ready":
    case "local_only":
      return status.roots;
    case "none":
      return postControls.create(account);
    case "restore_needed":
      throw new PostControlsUnavailable("restore_needed");
    case "unsupported":
      throw new PostControlsUnavailable("unsupported");
  }
}

/**
 * Blind issuance. Step 1 asks the issuer which metadata it would bind for the
 * target (standing checked, nothing signed or counted); the client blinds
 * under exactly that; step 2 is the one counted signing round.
 */
export async function obtainToken(target: PublishTarget | { schoolMember: true }): Promise<{ token: EligibilityToken; info: EligibilityInfo }> {
  const session = await communitySession();
  const request = "schoolMember" in target ? { schoolMember: true } : target;
  const stated = await api.communityEligibilityInfo(request);
  const blinded = await blindToken(session.issuerKey, stated.info);
  const issued = await api.communityEligibility({ ...request, blindedMessage: toBase64Url(blinded.blindedMessage) });
  const token = await finalizeToken(session.issuerKey, issued.keyId, blinded, issued.info, fromBase64Url(issued.blindSignature));
  return { token, info: issued.info };
}

export interface PreparedPost {
  token: EligibilityToken;
  envelope: SignedPostEnvelopeV2;
  postSignature: string;
}

export async function preparePost(account: string, target: PublishTarget, body: string, rating: number | null): Promise<PreparedPost> {
  const roots = await ensureRoots(account);
  const { token, info } = await obtainToken(target);
  const epoch = { schoolId: info.schoolId, academicYear: info.academicYear };
  const posting = postingKeyPair(roots.active, epoch);
  const postNonce = randomBytes(32);
  const control = postControlKeyPair(roots.active, postNonce, epoch);
  const sep = info.scope.indexOf(":");
  const envelope: SignedPostEnvelopeV2 = {
    protocolVersion: 2,
    schoolId: info.schoolId,
    academicYear: info.academicYear,
    primaryEntity: { type: info.scope.slice(0, sep) as SignedPostEnvelopeV2["primaryEntity"]["type"], id: info.scope.slice(sep + 1) },
    contexts: { ...info.contexts },
    body: body.trim(),
    rating,
    postNonce: toBase64Url(postNonce),
    postingPublicKey: toBase64Url(posting.publicKey),
    controlPublicKey: toBase64Url(control.publicKey),
    clientNonce: toBase64Url(randomBytes(12)),
  };
  return { token, envelope, postSignature: toBase64Url(signStatement(posting.privateKey, envelope as never)) };
}

export function checkPost(prepared: PreparedPost, cooldownTicket?: string): Promise<CheckResponseV2> {
  return community.check({ ...prepared, ...(cooldownTicket ? { cooldownTicket } : {}) });
}

export async function publishPost(prepared: PreparedPost, pass: string): Promise<{ experienceId: string }> {
  const res = await community.publish({ ...prepared, pass });
  apiCache.invalidate("community");
  return { experienceId: res.experienceId };
}

// ---- mine / revoke ----------------------------------------------------------

export interface OwnedPost extends MineExperience {
  rootId: string;
  academicYear: string;
}

/** Every post any root controls, across every school/year epoch known. */
export async function listOwnedPosts(account: string): Promise<OwnedPost[]> {
  const roots = await localPostControls.unlock(account);
  if (!roots) return [];
  const epochs = await postControls.epochs(account, roots);
  const out: OwnedPost[] = [];
  for (const root of roots.roots) {
    for (const epoch of epochs) {
      const posting = postingKeyPair(root.secret, epoch);
      const ch = await community.mineChallenge();
      const statement = { purpose: "honey/v2/mine" as const, schoolId: epoch.schoolId, academicYear: epoch.academicYear, challenge: ch.challenge, expiresAt: ch.expiresAt };
      const res = await community.mine({ statement, postingPublicKey: toBase64Url(posting.publicKey), signature: toBase64Url(signStatement(posting.privateKey, statement)) });
      for (const e of res.experiences) out.push({ ...e, rootId: root.rootId, academicYear: epoch.academicYear });
    }
  }
  return out.sort((a, b) => b.createdAt - a.createdAt);
}

export async function revokePost(account: string, post: OwnedPost, schoolId: string): Promise<void> {
  const roots = await localPostControls.unlock(account);
  const root = roots?.roots.find((r) => r.rootId === post.rootId);
  if (!root) throw new Error("the root that controls this post is not on this device");
  const control = postControlKeyPair(root.secret, fromBase64Url(post.postNonce), { schoolId, academicYear: post.academicYear });
  if (toBase64Url(control.publicKey) !== post.controlPublicKey) throw new Error("control key mismatch");
  const ch = await community.revokeChallenge(post.id);
  const statement = { purpose: "honey/v2/revoke" as const, experienceId: post.id, challenge: ch.challenge, expiresAt: ch.expiresAt };
  await community.revoke(post.id, { statement, signature: toBase64Url(signStatement(control.privateKey, statement)) });
  apiCache.invalidate("community");
}

// ---- reactions / reports -------------------------------------------------------

const REGISTERED_KEY = "honey.reactor.registered";

function registeredEpochs(): Set<string> {
  try {
    return new Set(JSON.parse(localStorage.getItem(REGISTERED_KEY) ?? "[]") as string[]);
  } catch {
    return new Set();
  }
}

async function reactorFor(account: string): Promise<{ privateKey: Uint8Array; publicKey: string; schoolId: string; academicYear: string }> {
  const roots = await ensureRoots(account);
  const session = await communitySession();
  const epoch = { schoolId: session.scope.schoolId, academicYear: session.scope.academicYear };
  const key = reactionKeyPair(roots.active, epoch);
  const publicKey = toBase64Url(key.publicKey);
  const mark = `${epoch.schoolId}\0${epoch.academicYear}\0${publicKey}`;
  const known = registeredEpochs();
  if (!known.has(mark)) {
    // Membership token → the reactor key is registered once per school/year.
    const { token } = await obtainToken({ schoolMember: true });
    const statement = { purpose: "honey/v2/register-reactor" as const, schoolId: epoch.schoolId, academicYear: epoch.academicYear, reactionPublicKey: publicKey };
    await community.registerReactor({ token, statement, signature: toBase64Url(signStatement(key.privateKey, statement)) });
    known.add(mark);
    try {
      localStorage.setItem(REGISTERED_KEY, JSON.stringify([...known]));
    } catch {
      /* the next reaction registers again; the server is idempotent */
    }
  }
  return { privateKey: key.privateKey, publicKey, ...epoch };
}

export async function reactToPost(account: string, experienceId: string, value: 1 | -1 | 0) {
  const r = await reactorFor(account);
  const statement = { purpose: "honey/v2/react" as const, schoolId: r.schoolId, academicYear: r.academicYear, experienceId, value, nonce: toBase64Url(randomBytes(12)) };
  return community.react(experienceId, { statement, reactionPublicKey: r.publicKey, signature: toBase64Url(signStatement(r.privateKey, statement)) });
}

export async function reportPost(account: string, experienceId: string, category: string) {
  const r = await reactorFor(account);
  const statement = { purpose: "honey/v2/report" as const, schoolId: r.schoolId, academicYear: r.academicYear, experienceId, category, nonce: toBase64Url(randomBytes(12)) };
  return community.report(experienceId, { statement, reactionPublicKey: r.publicKey, signature: toBase64Url(signStatement(r.privateKey, statement)) });
}

// The viewer's own reactions, remembered on this device (Community is not
// told who reads: the feed carries no per-viewer state).
const MY_REACTIONS_KEY = "honey.reactions.mine";
export const myReactions = {
  get(id: string): 1 | -1 | 0 {
    try {
      const v = (JSON.parse(localStorage.getItem(MY_REACTIONS_KEY) ?? "{}") as Record<string, number>)[id];
      return v === 1 || v === -1 ? v : 0;
    } catch {
      return 0;
    }
  },
  set(id: string, value: 1 | -1 | 0): void {
    try {
      const all = JSON.parse(localStorage.getItem(MY_REACTIONS_KEY) ?? "{}") as Record<string, number>;
      if (value === 0) delete all[id];
      else all[id] = value;
      localStorage.setItem(MY_REACTIONS_KEY, JSON.stringify(all));
    } catch {
      /* best effort */
    }
  },
};
