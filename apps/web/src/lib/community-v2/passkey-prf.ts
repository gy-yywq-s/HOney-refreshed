// WebAuthn Level 3 `prf` extension (spec §36): a passkey whose PRF output
// derives the local wrapping key for R. The credential is never sent to a
// server for verification here — it exists to unlock the vault on this
// device family — and the PRF output never leaves the client. Support is
// discovered by trying; unsupported combinations fall back to words/pairing.

import { fromBase64Url, plain, randomBytes, toBase64Url } from "@honey/shared/community-v2";

export interface PrfResult {
  credentialId: string; // base64url
  prfOutput: Uint8Array; // 32 bytes
}

type PrfExtensionResults = { prf?: { enabled?: boolean; results?: { first?: ArrayBuffer | Uint8Array } } };

function rpId(): string {
  return location.hostname;
}

export function passkeysAvailable(): boolean {
  return typeof PublicKeyCredential !== "undefined" && typeof navigator.credentials?.create === "function";
}

/** Create a discoverable passkey for HOney Post Controls and read its PRF output for `prfInput`. */
export async function createPasskeyWithPrf(userHandle: string, displayName: string, prfInput: Uint8Array): Promise<PrfResult | null> {
  if (!passkeysAvailable()) return null;
  const creation: CredentialCreationOptions = {
    publicKey: {
      challenge: plain(randomBytes(32)),
      rp: { id: rpId(), name: "HOney" },
      user: { id: plain(new TextEncoder().encode(userHandle)), name: `HOney ${userHandle}`, displayName },
      pubKeyCredParams: [
        { type: "public-key", alg: -8 },
        { type: "public-key", alg: -7 },
        { type: "public-key", alg: -257 },
      ],
      authenticatorSelection: { residentKey: "required", userVerification: "required" },
      timeout: 120_000,
      extensions: { prf: { eval: { first: plain(prfInput) } } } as AuthenticationExtensionsClientInputs,
    },
  };
  const cred = (await navigator.credentials.create(creation)) as PublicKeyCredential | null;
  if (!cred) return null;
  const ext = cred.getClientExtensionResults() as PrfExtensionResults;
  const credentialId = toBase64Url(new Uint8Array(cred.rawId));
  const first = ext.prf?.results?.first;
  if (first) return { credentialId, prfOutput: new Uint8Array(first instanceof Uint8Array ? first : new Uint8Array(first)) };
  // No output at creation (allowed by the spec): one immediate assertion.
  if (ext.prf?.enabled === false) return null;
  return getPrf(credentialId, prfInput);
}

/** Assert with the credential and evaluate the PRF; null when unsupported or cancelled. */
export async function getPrf(credentialId: string | null, prfInput: Uint8Array): Promise<PrfResult | null> {
  if (!passkeysAvailable()) return null;
  try {
    const request: CredentialRequestOptions = {
      publicKey: {
        challenge: plain(randomBytes(32)),
        rpId: rpId(),
        userVerification: "required",
        timeout: 120_000,
        ...(credentialId ? { allowCredentials: [{ type: "public-key", id: plain(fromBase64Url(credentialId)) }] } : {}),
        extensions: { prf: { eval: { first: plain(prfInput) } } } as AuthenticationExtensionsClientInputs,
      },
    };
    const cred = (await navigator.credentials.get(request)) as PublicKeyCredential | null;
    if (!cred) return null;
    const ext = cred.getClientExtensionResults() as PrfExtensionResults;
    const first = ext.prf?.results?.first;
    if (!first) return null;
    return { credentialId: toBase64Url(new Uint8Array(cred.rawId)), prfOutput: new Uint8Array(first instanceof Uint8Array ? first : new Uint8Array(first)) };
  } catch {
    return null; // cancelled, unsupported, credential gone: the caller offers the other ways
  }
}

/** A short label for the wrapper list ("Safari on iPhone"). */
export function deviceLabel(): string {
  const ua = navigator.userAgent;
  const browser = /CriOS|Chrome/.test(ua) ? "Chrome" : /Firefox/.test(ua) ? "Firefox" : /Safari/.test(ua) ? "Safari" : "Browser";
  const device = /iPhone/.test(ua) ? "iPhone" : /iPad/.test(ua) ? "iPad" : /Android/.test(ua) ? "Android" : /Mac/.test(ua) ? "Mac" : /Windows/.test(ua) ? "Windows" : "device";
  const standalone = (navigator as Navigator & { standalone?: boolean }).standalone || matchMedia("(display-mode: standalone)").matches;
  return `${standalone ? "HOney app" : browser} on ${device}`;
}
