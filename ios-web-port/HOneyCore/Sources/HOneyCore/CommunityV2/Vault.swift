// The encrypted Control Vault (spec §35): every root the student has used,
// which one is active, the school epochs seen — AES-256-GCM under the
// random wrapping root R with {revision, vaultId, version} as AAD. Core
// stores ciphertext it cannot read. Mirrors packages/shared/src/community-v2/vault.ts.

import Crypto
import Foundation

public struct ControlRootRecord: Codable, Sendable, Equatable {
    public var rootId: String
    /// M_i, base64url (32 bytes). Plaintext exists only on clients.
    public var secret: String
    public var state: String // "active" | "legacy"
    public var createdAt: Int64
    public var retiredAt: Int64?

    public init(rootId: String, secret: String, state: String, createdAt: Int64, retiredAt: Int64? = nil) {
        self.rootId = rootId
        self.secret = secret
        self.state = state
        self.createdAt = createdAt
        self.retiredAt = retiredAt
    }
}

public struct ControlVaultPayload: Codable, Sendable, Equatable {
    public var version: Int
    public var roots: [ControlRootRecord]
    public var activeRootId: String
    public var schoolEpochs: [SchoolEpoch]
    public var createdAt: Int64
    public var updatedAt: Int64

    public init(version: Int = V2Labels.vaultVersion, roots: [ControlRootRecord], activeRootId: String, schoolEpochs: [SchoolEpoch], createdAt: Int64, updatedAt: Int64) {
        self.version = version
        self.roots = roots
        self.activeRootId = activeRootId
        self.schoolEpochs = schoolEpochs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct SealedVault: Sendable, Equatable {
    public var iv: String
    public var ciphertext: String
}

public enum ControlVault {
    /// AAD = JCS({revision, vaultId, version: 2}).
    public static func aad(vaultId: String, revision: Int) -> Data {
        JSONValue.object(["revision": .int(Int64(revision)), "vaultId": .string(vaultId), "version": .int(Int64(V2Labels.vaultVersion))]).canonicalData
    }

    static func aesSeal(key: Data, plaintext: Data, aad: Data) throws -> (iv: Data, ciphertext: Data) {
        guard key.count == 32 else { throw V2Error.invalidInput("AES-256 key must be 32 bytes") }
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), nonce: nonce, authenticating: aad)
        return (Data(nonce), box.ciphertext + box.tag)
    }

    static func aesOpen(key: Data, iv: Data, ciphertext: Data, aad: Data) throws -> Data {
        guard key.count == 32 else { throw V2Error.invalidInput("AES-256 key must be 32 bytes") }
        guard ciphertext.count >= 16 else { throw V2Error.wrongKey }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ciphertext.dropLast(16), tag: ciphertext.suffix(16))
        do {
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
        } catch {
            throw V2Error.wrongKey
        }
    }

    /// Encrypt a payload for revision `revision` under R with a fresh IV.
    public static func seal(r: Data, vaultId: String, revision: Int, payload: ControlVaultPayload) throws -> SealedVault {
        let bytes = try CanonicalJSON.bytes(of: payload)
        let sealed = try aesSeal(key: r, plaintext: bytes, aad: aad(vaultId: vaultId, revision: revision))
        return SealedVault(iv: Base64URL.encode(sealed.iv), ciphertext: Base64URL.encode(sealed.ciphertext))
    }

    /// Decrypt + authenticate; throws on the wrong key, IV, AAD or a tampered revision.
    public static func open(r: Data, vaultId: String, revision: Int, iv: String, ciphertext: String) throws -> ControlVaultPayload {
        guard let ivData = Base64URL.decode(iv), let ct = Base64URL.decode(ciphertext) else { throw V2Error.vaultInvalid("bad encoding") }
        let pt = try aesOpen(key: r, iv: ivData, ciphertext: ct, aad: aad(vaultId: vaultId, revision: revision))
        let payload = try WireCoding.decode(ControlVaultPayload.self, from: pt)
        guard payload.version == V2Labels.vaultVersion, !payload.activeRootId.isEmpty else { throw V2Error.vaultInvalid("payload invalid") }
        return payload
    }

    public static func newRootRecord(secret: Data, now: Int64) -> ControlRootRecord {
        ControlRootRecord(rootId: Base64URL.encode(.random(12)), secret: Base64URL.encode(secret), state: "active", createdAt: now)
    }

    public static func initialPayload(root: ControlRootRecord, epochs: [SchoolEpoch], now: Int64) -> ControlVaultPayload {
        ControlVaultPayload(roots: [root], activeRootId: root.rootId, schoolEpochs: epochs, createdAt: now, updatedAt: now)
    }

    public static func activeRoot(_ payload: ControlVaultPayload) throws -> ControlRootRecord {
        guard let r = payload.roots.first(where: { $0.rootId == payload.activeRootId }), r.state == "active" else {
            throw V2Error.vaultInvalid("vault has no active root")
        }
        return r
    }

    /// Root rotation (spec §40.3): the active root becomes legacy, the new one is the sole active root.
    public static func rotated(_ payload: ControlVaultPayload, newSecret: Data, now: Int64) -> ControlVaultPayload {
        let fresh = newRootRecord(secret: newSecret, now: now)
        var roots = payload.roots.map { r -> ControlRootRecord in
            guard r.rootId == payload.activeRootId else { return r }
            var legacy = r
            legacy.state = "legacy"
            legacy.retiredAt = now
            return legacy
        }
        roots.append(fresh)
        var out = payload
        out.roots = roots
        out.activeRootId = fresh.rootId
        out.updatedAt = now
        return out
    }

    public static func withEpoch(_ payload: ControlVaultPayload, _ epoch: SchoolEpoch, now: Int64) -> ControlVaultPayload {
        if payload.schoolEpochs.contains(epoch) { return payload }
        var out = payload
        out.schoolEpochs.append(epoch)
        out.updatedAt = now
        return out
    }

    /// Conflict merge (spec §40.2): union roots, epochs and wrappers by stable id;
    /// contradictory active roots are rejected rather than guessed.
    public static func merge(local: ControlVaultPayload, remote: ControlVaultPayload, now: Int64) throws -> ControlVaultPayload {
        var roots: [String: ControlRootRecord] = [:]
        var order: [String] = []
        for r in remote.roots + local.roots {
            if let prev = roots[r.rootId] {
                roots[r.rootId] = prev.state == "legacy" ? prev : r
            } else {
                roots[r.rootId] = r
                order.append(r.rootId)
            }
        }
        var activeRootId = local.activeRootId
        if local.activeRootId != remote.activeRootId {
            let localRetiredRemote = roots[remote.activeRootId]?.state == "legacy" && local.roots.contains { $0.rootId == remote.activeRootId }
            let remoteRetiredLocal = roots[local.activeRootId]?.state == "legacy" && remote.roots.contains { $0.rootId == local.activeRootId }
            if localRetiredRemote, !remoteRetiredLocal { activeRootId = local.activeRootId }
            else if remoteRetiredLocal, !localRetiredRemote { activeRootId = remote.activeRootId }
            else { throw V2Error.vaultConflict("contradictory active roots") }
        }
        guard var active = roots[activeRootId] else { throw V2Error.vaultConflict("active root missing") }
        active.state = "active"
        roots[activeRootId] = active
        var epochs: [SchoolEpoch] = []
        for e in remote.schoolEpochs + local.schoolEpochs where !epochs.contains(e) { epochs.append(e) }
        return ControlVaultPayload(
            roots: order.compactMap { roots[$0] },
            activeRootId: activeRootId,
            schoolEpochs: epochs,
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: now
        )
    }

    public static func mergeWrappers(local: [VaultWrapper], remote: [VaultWrapper]) -> [VaultWrapper] {
        var byId: [String: VaultWrapper] = [:]
        var order: [String] = []
        for w in remote + local {
            let id = w.stableId
            if byId[id] == nil { order.append(id) }
            byId[id] = w
        }
        return order.compactMap { byId[$0] }
    }

    public static func fingerprint(_ payload: ControlVaultPayload) throws -> String {
        try JSONValue(encoding: payload).canonical
    }
}
