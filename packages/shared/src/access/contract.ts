// Web Access wire contract (spec Part II). Core issues a short-lived signed
// capability whose portal session is sealed to the Access Service; the
// browser never holds a reusable portal token. Every physical action goes
// prepare → final confirmation → commit (at most once) → streamed progress.

import type { Door, Permit, AccessRouteKind } from "./rules.js";

export interface SealedPortalSession {
  token: string;
  tokenExpiresAt: number;
  portalStudentId: string;
  schoolId: string;
}

export interface AccessCapabilityBody {
  version: 1;
  audience: "honey-web-access";
  capabilityId: string;
  /** Pseudonymous, short-lived; never an account id. */
  subject: string;
  schoolId: string;
  portalStudentId: string;
  issuedAt: number;
  expiresAt: number;
  /** HPKE enc ‖ ciphertext (base64url) of SealedPortalSession, readable by the Access Service only. */
  sealedPortalSession: { enc: string; ciphertext: string; keyId: string };
}

/** The signed envelope: JCS(body) signed with Core's Ed25519 signing key. */
export interface AccessCapability {
  body: AccessCapabilityBody;
  keyId: string;
  signature: string;
}

export type AccessSessionResponse = { ok: true; capability: string; expiresAt: number } | { ok: false; error: "portal_reconnect_required" | "access_unavailable" | "no_school_connection" };

export interface AccessBootstrap {
  serviceVersion: string;
  enabled: boolean;
  identity: { portalStudentId: string; dayStudent: boolean };
  doors: Door[];
  doorsFresh: boolean;
  permits: Permit[];
  permitsFresh: boolean;
  routes: { dayStudent: boolean; exitPermit: boolean };
  eta: { openGate: string; permit: string };
  /** Epoch ms of the reads behind this bootstrap; physical authority needs a fresh prepare anyway. */
  readAt: number;
}

export interface PrepareOpenInput {
  route: AccessRouteKind;
  gateKey: string;
  permitRecordId?: number;
  clientNonce: string;
}

export interface PreparedOpenOperation {
  operationId: string;
  commitSecret: string;
  expiresAt: number;
  gateDisplayName: string;
  routeDisplayName: string;
  etaLabel: string;
}

export type OperationState =
  | "PREPARED"
  | "EXPIRED"
  | "PAUSED"
  | "COMMITTED"
  | "NOT_SENT"
  | "DISPATCHING"
  | "WAITING_FOR_SCHOOL"
  | "CONFIRMED"
  | "REJECTED"
  | "OUTCOME_UNKNOWN";

export type ProgressStage = "accepted" | "sending" | "waiting_for_school" | "confirmed" | "rejected" | "not_sent" | "outcome_unknown";

export interface AccessProgressEvent {
  stage: ProgressStage;
  elapsedMs: number;
  etaLowMs?: number;
  etaHighMs?: number;
  message: string;
  terminal: boolean;
}

export interface OperationStatus {
  operationId: string;
  state: OperationState;
  outcomeCode: string | null;
  createdAt: number;
  terminalAt: number | null;
}

export interface ApplyPermitInput {
  startTime: string; // "YYYY-MM-DD HH:mm:ss" school zone
  endTime: string;
  note: string;
  clientNonce: string;
}

export type AccessErrorCode =
  | "capability_invalid"
  | "capability_expired"
  | "access_paused"
  | "service_unavailable"
  | "doors_unavailable"
  | "permits_unavailable"
  | "permit_not_usable"
  | "route_not_allowed"
  | "gate_unknown"
  | "operation_in_progress"
  | "operation_not_found"
  | "operation_not_prepared"
  | "commit_secret_invalid"
  | "portal_session_expired"
  | "portal_rejected"
  | "outcome_unknown"
  | "not_sent";

export interface AccessAdminStatus {
  enabled: boolean;
  healthy: boolean;
  serviceVersion: string;
  activeOperations: number;
  typicalOpen: string;
  unknownToday: number;
  egress: { portalOrigin: string };
}
