// "Delete account and public content" (spec §40.4): list every post any
// stored root controls, revoke each with its derived control key, verify,
// delete the encrypted vault, then ask Core to delete the account. Core never
// queries Community by account; Community sees only cryptographic proofs. A
// resumable checklist on this device keeps partial progress honest.

import { api } from "../../api/client";
import { portalCredentials } from "../portalCredentials";
import { localPostControls } from "./local-store";
import { communitySession, listOwnedPosts, revokePost, type OwnedPost } from "./publish-client";
import { postControls } from "./post-controls";

const CHECKLIST_KEY = "honey.account-deletion";

export interface DeletionChecklist {
  startedAt: number;
  postsFound: number;
  postsRevoked: number;
  failedPosts: string[];
  vaultDeleted: boolean;
  accountDeleted: boolean;
}

export type DeletionOutcome =
  | { kind: "done"; checklist: DeletionChecklist }
  | { kind: "vault_locked"; status: Awaited<ReturnType<typeof postControls.status>> }
  | { kind: "partial"; checklist: DeletionChecklist };

export function readChecklist(): DeletionChecklist | null {
  try {
    const raw = localStorage.getItem(CHECKLIST_KEY);
    return raw ? (JSON.parse(raw) as DeletionChecklist) : null;
  } catch {
    return null;
  }
}

function write(checklist: DeletionChecklist): void {
  try {
    localStorage.setItem(CHECKLIST_KEY, JSON.stringify(checklist));
  } catch {
    /* best effort */
  }
}

export function clearChecklist(): void {
  localStorage.removeItem(CHECKLIST_KEY);
}

/**
 * Step 1+2: revoke public content by proof. Returns "vault_locked" when this
 * device cannot unlock the roots (nothing is deleted then — the caller offers
 * passkey / pairing / recovery words, or an explicit account-only deletion).
 */
export async function deletePublicContent(account: string): Promise<DeletionOutcome> {
  const status = await postControls.status(account);
  if (status.kind === "restore_needed" || status.kind === "unsupported") return { kind: "vault_locked", status };
  const checklist: DeletionChecklist = readChecklist() ?? { startedAt: Date.now(), postsFound: 0, postsRevoked: 0, failedPosts: [], vaultDeleted: false, accountDeleted: false };
  const session = await communitySession();
  let posts: OwnedPost[] = [];
  if (status.kind !== "none") {
    posts = await listOwnedPosts(account);
    checklist.postsFound = posts.length;
    checklist.failedPosts = [];
    for (const post of posts) {
      try {
        await revokePost(account, post, session.scope.schoolId);
        checklist.postsRevoked += 1;
      } catch {
        checklist.failedPosts.push(post.id);
      }
      write(checklist);
    }
    // Verify: nothing must remain listable.
    const remaining = await listOwnedPosts(account);
    if (remaining.length > 0) {
      checklist.failedPosts = [...new Set([...checklist.failedPosts, ...remaining.map((p) => p.id)])];
      write(checklist);
      return { kind: "partial", checklist };
    }
  }
  if (checklist.failedPosts.length > 0) return { kind: "partial", checklist };
  return { kind: "done", checklist };
}

/** Step 3+4: the vault, the local roots, the saved school login, then the account. */
export async function deleteAccountAfterContent(account: string): Promise<void> {
  const checklist = readChecklist();
  try {
    await api.vaultDelete();
  } catch {
    /* no vault or already gone */
  }
  if (checklist) {
    checklist.vaultDeleted = true;
    write(checklist);
  }
  await localPostControls.erase(account);
  await api.deleteAccount();
  portalCredentials.clear();
  clearChecklist();
}
