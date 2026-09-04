// Fixed domain-separation labels of the Anonymous Control v2 key hierarchy
// (spec §30.4). These strings ARE the protocol: Web and iPhone read the same
// values, and the shared vectors fail if one drifts.
// Mirrors packages/shared/src/community-v2/key-labels.ts.

import Foundation

public enum V2Labels {
    public static let schoolEpochSaltPrefix = "honey/v2/school-epoch\0"
    public static let postingSigning = "honey/v2/posting-signing"
    public static let postControlPrefix = "honey/v2/post-control\0"
    public static let authorTagPrefix = "honey/v2/author-tag\0"
    public static let reactorTagPrefix = "honey/v2/reactor-tag\0"
    public static let privateNotesLocal = "honey/v2/private-notes-local"
    public static let reactionSigning = "honey/v2/reaction-signing"
    public static let vaultDeviceWrap = "honey/v2/vault-device-wrap"
    public static let vaultPrfWrap = "honey/v2/vault-prf-wrap"
    public static let vaultPhraseWrap = "honey/v2/vault-phrase-wrap"
    public static let vaultPrfInputPrefix = "honey/v2/vault-prf-input\0"
    public static let pairingInfo = "honey/v2/pairing"
    public static let purposeMine = "honey/v2/mine"
    public static let purposeRevoke = "honey/v2/revoke"
    public static let purposeReact = "honey/v2/react"
    public static let purposeReport = "honey/v2/report"
    public static let purposeRegisterReactor = "honey/v2/register-reactor"

    public static let protocolVersion = 2
    public static let vaultVersion = 2
    public static let recoveryPhraseFormat = "words12-v1"
    public static let eligibilitySuite = "RSAPBSSA-SHA384-PSS-Randomized"
    public static let eligibilityModulusBits = 2048
}
