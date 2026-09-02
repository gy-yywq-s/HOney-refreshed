// Wire contract of Anonymous Control v2 (spec Part III) — the ONLY coupling
// between clients, HOney Core (issuer + vault) and HOney Community. Every
// byte field is base64url. Every signed statement is signed over its JCS
// bytes (canonical-json.ts).

import type { JsonValue } from "./canonical-json.js";

// ---------------------------------------------------------------------------
// Eligibility (Core issues, Community redeems). Privacy Pass style: the token
// value is blind to the issuer; the scope and canonical context are PUBLIC
// METADATA bound into the signature (RSAPBSSA), so Community can check them
// offline with the issuer public key and the issuer never learns the token.
// ---------------------------------------------------------------------------

export type EligibilityScopeType = "lesson" | "course" | "teacher" | "room" | "dish" | "school-member";

/** The public metadata the issuer signs with the blinded token (JCS bytes = `info`). */
export interface EligibilityInfo {
  v: 2;
  schoolId: string;
  academicYear: string;
  /** "<type>:<canonical id>" — lessons use the opaque lesson id. */
  scope: string;
  /** Canonical context the account verifiably had for this scope. */
  contexts: {
    lessonId?: string;
    courseId?: string;
    teacherId?: string;
    roomId?: string;
  };
  provenance: "verified_lesson" | "verified_retrospective" | "verified_member";
  /** Portal week index at issuance; a token is redeemable for two weeks. */
  week: number;
}

export interface IssuerDescriptor {
  suite: string;
  keyId: string;
  /** RSA public key, JWK (n, e). */
  publicKey: { kty: "RSA"; n: string; e: string; alg?: string };
}

export interface EligibilityRequest {
  /** Exactly one of lessonId / entityKey. */
  lessonId?: string;
  entityKey?: string;
  /** Blinded token message (RSAPBSSA blind output), base64url. */
  blindedMessage: string;
}

export interface EligibilityIssued {
  ok: true;
  keyId: string;
  info: EligibilityInfo;
  /** Blind signature, base64url. The client finalizes it into the token. */
  blindSignature: string;
}

export type EligibilityErrorCode =
  | "publications_disabled"
  | "temporarily_suspended"
  | "target_required"
  | "lesson_not_yours"
  | "entity_unknown"
  | "entity_frozen"
  | "standalone_closed"
  | "not_invited"
  | "no_verified_exposure"
  | "issuer_unavailable"
  | "issuance_rate_limited"
  | "blinded_message_invalid";

/** The redeemable token as Community receives it. */
export interface EligibilityToken {
  keyId: string;
  info: EligibilityInfo;
  /** The prepared message (random prefix ‖ nonce), base64url. */
  message: string;
  /** The finalized RSA-PSS signature over msg', base64url. */
  signature: string;
}

/** GET /api/community/scope — the viewer's canonical exposure, for feed scoping. */
export interface CommunityScope {
  schoolId: string;
  academicYear: string;
  teachers: string[];
  courses: string[];
  /** Opaque lesson ids (never the roster-joinable instance ids). */
  lessons: string[];
}

// ---------------------------------------------------------------------------
// Publication (identity-free; credentials omitted)
// ---------------------------------------------------------------------------

export interface SignedPostEnvelopeV2 {
  protocolVersion: 2;
  schoolId: string;
  academicYear: string;
  primaryEntity: { type: "teacher" | "course" | "room" | "dish" | "lesson"; id: string };
  contexts: {
    lessonId?: string;
    courseId?: string;
    teacherId?: string;
    roomId?: string;
    topicName?: string;
  };
  body: string;
  rating: number | null;
  postNonce: string;
  postingPublicKey: string;
  controlPublicKey: string;
  clientNonce: string;
}

export interface CheckRequestV2 {
  token: EligibilityToken;
  envelope: SignedPostEnvelopeV2;
  postSignature: string;
  cooldownTicket?: string;
}

export type CheckLaneV2 =
  | "publish"
  | "nudge"
  | "cooldown"
  | "edit_required"
  | "blocked_serious"
  | "out_of_scope"
  | "failed_closed";

export interface CheckResponseV2 {
  lane: CheckLaneV2;
  reasons: string[];
  policyVersion: number;
  pass?: string;
  cooldown?: { ticket: string; retryAt: number };
}

export type CheckErrorV2 =
  | "publications_disabled"
  | "token_invalid"
  | "token_scope_mismatch"
  | "token_expired"
  | "token_used"
  | "envelope_invalid"
  | "signature_invalid"
  | "body_invalid"
  | "rating_invalid"
  | "rating_not_allowed"
  | "cooldown_ticket_invalid"
  | "already_posted"
  | "entity_frozen"
  | "temporarily_suspended";

export interface PublishRequestV2 {
  token: EligibilityToken;
  envelope: SignedPostEnvelopeV2;
  postSignature: string;
  pass: string;
}

export interface PublishResponseV2 {
  ok: true;
  experienceId: string;
  postNonce: string;
}

export type PublishErrorV2 = CheckErrorV2 | "pass_invalid" | "pass_mismatch";

// ---------------------------------------------------------------------------
// Ownership: mine (school/year posting key) · revoke (per-post control key)
// ---------------------------------------------------------------------------

export interface ChallengeResponse {
  challenge: string;
  expiresAt: number;
}

export interface MineStatement {
  purpose: "honey/v2/mine";
  schoolId: string;
  academicYear: string;
  challenge: string;
  expiresAt: number;
}

export interface MineRequest {
  statement: MineStatement;
  postingPublicKey: string;
  signature: string;
}

export interface MineExperience {
  id: string;
  primaryEntity: { type: string; id: string; name: string | null };
  contexts: { type: string; id: string; name: string | null }[];
  body: string | null;
  rating: number | null;
  provenance: string;
  status: "published" | "blocked";
  statusDetail: string | null;
  postNonce: string;
  controlPublicKey: string;
  createdAt: number;
}

export interface MineResponse {
  experiences: MineExperience[];
}

export interface RevokeStatement {
  purpose: "honey/v2/revoke";
  experienceId: string;
  challenge: string;
  expiresAt: number;
}

export interface RevokeRequest {
  statement: RevokeStatement;
  signature: string;
}

// ---------------------------------------------------------------------------
// Reactions and reports (school/year reactor key; purpose-separated from posting)
// ---------------------------------------------------------------------------

export interface RegisterReactorRequest {
  token: EligibilityToken; // scope school-member:<schoolId>
  statement: { purpose: "honey/v2/register-reactor"; schoolId: string; academicYear: string; reactionPublicKey: string };
  signature: string;
}

export interface ReactStatement {
  purpose: "honey/v2/react";
  schoolId: string;
  academicYear: string;
  experienceId: string;
  value: 1 | -1 | 0;
  nonce: string;
}

export interface ReactRequestV2 {
  statement: ReactStatement;
  reactionPublicKey: string;
  signature: string;
}

export interface ReportStatement {
  purpose: "honey/v2/report";
  schoolId: string;
  academicYear: string;
  experienceId: string;
  category: string;
  nonce: string;
}

export interface ReportRequestV2 {
  statement: ReportStatement;
  reactionPublicKey: string;
  signature: string;
}

// ---------------------------------------------------------------------------
// Control Vault (Core stores ciphertext it cannot read)
// ---------------------------------------------------------------------------

export interface ControlRootRecord {
  rootId: string;
  /** M_i, base64url (32 bytes). Plaintext exists only on clients. */
  secret: string;
  state: "active" | "legacy";
  createdAt: number;
  retiredAt?: number;
}

export interface ControlVaultPayload {
  version: 2;
  roots: ControlRootRecord[];
  activeRootId: string;
  schoolEpochs: { schoolId: string; academicYear: string }[];
  createdAt: number;
  updatedAt: number;
}

export interface PasskeyPrfWrapper {
  type: "passkey_prf";
  credentialId: string;
  prfInput: string;
  iv: string;
  wrappedR: string;
  createdAt: number;
  /** Where it was set up ("Safari on iPhone"), for the student's list. */
  label?: string;
}

export interface RecoveryPhraseWrapper {
  type: "recovery_phrase";
  format: "words12-v1";
  iv: string;
  wrappedR: string;
  createdAt: number;
}

export type VaultWrapper = PasskeyPrfWrapper | RecoveryPhraseWrapper;

export interface VaultRecord {
  vaultId: string;
  revision: number;
  iv: string;
  /** AES-256-GCM ciphertext ‖ tag, base64url. */
  ciphertext: string;
  wrappers: VaultWrapper[];
  updatedAt: number;
}

export interface VaultPutRequest {
  vaultId: string;
  /** The revision this write is based on (0 for a first write). */
  baseRevision: number;
  iv: string;
  ciphertext: string;
  wrappers: VaultWrapper[];
}

export type VaultPutResponse = { ok: true; revision: number; updatedAt: number } | { ok: false; error: "conflict"; current: VaultRecord };

/** Pairing relay: short-lived HPKE ciphertext of R, addressed by a code. */
export interface PairingOffer {
  pairingId: string;
  /** New device's ephemeral X25519 public key, base64url (32 bytes). */
  recipientPublicKey: string;
  expiresAt: number;
}

export interface PairingDelivery {
  pairingId: string;
  /** HPKE enc ‖ ciphertext, base64url. */
  enc: string;
  ciphertext: string;
}

export type ToJson<T> = T & JsonValue;
