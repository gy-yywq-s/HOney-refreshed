// Fixed domain-separation labels of the Anonymous Control v2 key hierarchy
// (spec §30.4). These strings are part of the protocol: changing one changes
// every derived key. Web and iOS read the same values (see fixtures/vectors.json).

export const LABELS = {
  schoolEpochSaltPrefix: "honey/v2/school-epoch\0",
  postingSigning: "honey/v2/posting-signing",
  postControlPrefix: "honey/v2/post-control\0",
  authorTagPrefix: "honey/v2/author-tag\0",
  reactorTagPrefix: "honey/v2/reactor-tag\0",
  privateNotesLocal: "honey/v2/private-notes-local",
  reactionSigning: "honey/v2/reaction-signing",
  vaultDeviceWrap: "honey/v2/vault-device-wrap",
  vaultPrfWrap: "honey/v2/vault-prf-wrap",
  vaultPhraseWrap: "honey/v2/vault-phrase-wrap",
  vaultPrfInputPrefix: "honey/v2/vault-prf-input\0",
  pairingInfo: "honey/v2/pairing",
  /** Signed-statement purposes. */
  purposeMine: "honey/v2/mine",
  purposeRevoke: "honey/v2/revoke",
  purposeReact: "honey/v2/react",
  purposeReport: "honey/v2/report",
  purposeRegisterReactor: "honey/v2/register-reactor",
} as const;

export const PROTOCOL_VERSION = 2 as const;
export const VAULT_VERSION = 2 as const;
export const RECOVERY_PHRASE_FORMAT = "words12-v1" as const;

/** The blind-signature suite every eligibility token uses (Privacy Pass style, public metadata). */
export const ELIGIBILITY_SUITE = "RSAPBSSA-SHA384-PSS-Randomized" as const;
export const ELIGIBILITY_MODULUS_BITS = 2048 as const;
