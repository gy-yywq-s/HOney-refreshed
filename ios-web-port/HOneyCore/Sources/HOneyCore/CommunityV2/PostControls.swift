// Post controls on this iPhone (spec §35–§40; Web: lib/community-v2/
// local-store.ts + vault-client.ts + post-controls.ts). The active root and
// the wrapping root R live in the Keychain, sealed under a random device
// secret that never leaves the device; the Control Vault on Core holds the
// same roots as ciphertext under R; wrappers (recovery words · passkey PRF ·
// another device) only wrap R. Nothing here ever creates a second root
// while a server vault exists.

import Foundation

public struct LocalRoot: Sendable, Equatable {
    public var rootId: String
    public var secret: Data
    public var state: String
    public init(rootId: String, secret: Data, state: String) {
        self.rootId = rootId
        self.secret = secret
        self.state = state
    }
}

/// Roots unlocked on this device: the active root first.
public struct UnlockedRoots: Sendable, Equatable {
    public var vaultId: String
    public var r: Data
    public var roots: [LocalRoot]
    public var active: LocalRoot { roots[0] }
    public init(vaultId: String, r: Data, roots: [LocalRoot]) {
        self.vaultId = vaultId
        self.r = r
        self.roots = roots
    }
}

/// What the Keychain holds per account: R wrapped by the device secret, the
/// payload sealed under R, the last server revision and its wrappers.
public struct LocalVaultState: Codable, Sendable, Equatable {
    public var vaultId: String
    public var revision: Int
    public var wrappers: [VaultWrapper]
    public var rIv: String
    public var rWrapped: String
    public var payloadIv: String
    public var payloadCiphertext: String
}

public protocol PostControlStorage: Sendable {
    func loadState(account: String) throws -> LocalVaultState?
    func saveState(account: String, _ state: LocalVaultState) throws
    func clearState(account: String) throws
    /// A random 32-byte secret per account, created on first use; never exported.
    func deviceSecret(account: String) throws -> Data
    func clearDeviceSecret(account: String) throws
}

/// Keychain-backed storage (`SecretStore` is the Keychain abstraction the app injects).
public final class SecretPostControlStore: PostControlStorage, @unchecked Sendable {
    private let store: SecretStore
    private let prefix: String
    private let lock = NSLock()

    public init(store: SecretStore, prefix: String = "honey.v2") {
        self.store = store
        self.prefix = prefix
    }

    private func name(_ kind: String, _ account: String) -> String {
        "\(prefix).\(kind).\(AccountFiles.safeName(account))"
    }

    public func loadState(account: String) throws -> LocalVaultState? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try store.read(name("vault", account)) else { return nil }
        return try? JSONDecoder().decode(LocalVaultState.self, from: data)
    }

    public func saveState(account: String, _ state: LocalVaultState) throws {
        lock.lock(); defer { lock.unlock() }
        try store.write(name("vault", account), try JSONEncoder().encode(state))
        guard let back = try store.read(name("vault", account)), (try? JSONDecoder().decode(LocalVaultState.self, from: back)) == state else {
            throw SecretStoreError.writeFailed
        }
    }

    public func clearState(account: String) throws {
        lock.lock(); defer { lock.unlock() }
        try store.delete(name("vault", account))
    }

    public func deviceSecret(account: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        if let existing = try store.read(name("device", account)), existing.count == 32 { return existing }
        let secret = Data.random(32)
        try store.write(name("device", account), secret)
        guard try store.read(name("device", account)) == secret else { throw SecretStoreError.writeFailed }
        return secret
    }

    public func clearDeviceSecret(account: String) throws {
        lock.lock(); defer { lock.unlock() }
        try store.delete(name("device", account))
    }
}

/// The vault endpoints of Core the controls need (APIClient conforms).
public protocol VaultAPI: Sendable {
    func vault() async throws -> VaultRecord?
    func vaultPut(_ request: VaultPutRequest) async throws -> VaultPutResponse
    func vaultDelete() async throws
    func vaultPairingOffer(recipientPublicKey: String) async throws -> PairingOffer
    func vaultPairingRead(pairingId: String) async throws -> PairingOffer
    func vaultPairingDeliver(pairingId: String, enc: String, ciphertext: String) async throws
    func vaultPairingClaim(pairingId: String) async throws -> PairingDelivery?
}

public enum PostControlsStatus: Sendable, Equatable {
    /// No local root, no server vault → create silently at first share.
    case none
    /// Local root, no server vault yet → offer the encrypted backup.
    case localOnly(UnlockedRoots)
    /// A server vault exists but this device has no root → restore.
    case restoreNeeded(VaultRecord)
    case ready(UnlockedRoots, record: VaultRecord?, wrappers: [VaultWrapper])

    public var roots: UnlockedRoots? {
        switch self {
        case .localOnly(let r), .ready(let r, _, _): return r
        default: return nil
        }
    }
}

public enum PostControlsError: Error, Sendable, Equatable {
    case vaultExists
    case noLocalRoots
    case restoreNeeded
    case readbackFailed
    case wrongWords
    case pairingExpired
}

public actor PostControls {
    private let api: VaultAPI
    private let storage: PostControlStorage
    private let now: @Sendable () -> Int64

    public init(api: VaultAPI, storage: PostControlStorage, now: @escaping @Sendable () -> Int64 = { HOneyClock.now().epochMillis }) {
        self.api = api
        self.storage = storage
        self.now = now
    }

    // MARK: local

    /// The roots kept on this device, or nil.
    public func unlock(account: String) throws -> UnlockedRoots? {
        guard let state = try storage.loadState(account: account) else { return nil }
        let device = try storage.deviceSecret(account: account)
        let r = try VaultWrappers.unwrapWithDevice(deviceSecret: device, vaultId: state.vaultId, wrapped: WrappedR(iv: state.rIv, wrappedR: state.rWrapped))
        let payload = try ControlVault.open(r: r, vaultId: state.vaultId, revision: state.revision, iv: state.payloadIv, ciphertext: state.payloadCiphertext)
        return try Self.roots(vaultId: state.vaultId, r: r, payload: payload)
    }

    public func localState(account: String) throws -> LocalVaultState? {
        try storage.loadState(account: account)
    }

    private func save(account: String, roots: UnlockedRoots, payload: ControlVaultPayload, revision: Int, wrappers: [VaultWrapper]) throws {
        let device = try storage.deviceSecret(account: account)
        let wrapped = try VaultWrappers.wrapWithDevice(deviceSecret: device, vaultId: roots.vaultId, r: roots.r)
        let sealed = try ControlVault.seal(r: roots.r, vaultId: roots.vaultId, revision: revision, payload: payload)
        try storage.saveState(account: account, LocalVaultState(vaultId: roots.vaultId, revision: revision, wrappers: wrappers, rIv: wrapped.iv, rWrapped: wrapped.wrappedR, payloadIv: sealed.iv, payloadCiphertext: sealed.ciphertext))
    }

    static func roots(vaultId: String, r: Data, payload: ControlVaultPayload) throws -> UnlockedRoots {
        let active = try ControlVault.activeRoot(payload)
        var roots: [LocalRoot] = []
        for record in payload.roots {
            guard let secret = Base64URL.decode(record.secret) else { throw V2Error.vaultInvalid("root secret") }
            roots.append(LocalRoot(rootId: record.rootId, secret: secret, state: record.state))
        }
        let ordered = roots.filter { $0.rootId == active.rootId } + roots.filter { $0.rootId != active.rootId }
        return UnlockedRoots(vaultId: vaultId, r: r, roots: ordered)
    }

    /// The payload this device would upload (the vault content is derivable from what it holds).
    public func payload(for roots: UnlockedRoots, epochs: [SchoolEpoch]) -> ControlVaultPayload {
        let t = now()
        var payload = ControlVaultPayload(
            roots: roots.roots.map { ControlRootRecord(rootId: $0.rootId, secret: Base64URL.encode($0.secret), state: $0.state, createdAt: t) },
            activeRootId: roots.active.rootId,
            schoolEpochs: [],
            createdAt: t,
            updatedAt: t
        )
        for e in epochs { payload = ControlVault.withEpoch(payload, e, now: t) }
        return payload
    }

    /// Every school/year epoch known locally (plus the server's, when readable).
    public func epochs(account: String, roots: UnlockedRoots) async -> [SchoolEpoch] {
        var out: [SchoolEpoch] = []
        if let state = try? storage.loadState(account: account),
           let payload = try? ControlVault.open(r: roots.r, vaultId: state.vaultId, revision: state.revision, iv: state.payloadIv, ciphertext: state.payloadCiphertext) {
            out = payload.schoolEpochs
        }
        if let record = try? await api.vault(), let payload = try? ControlVault.open(r: roots.r, vaultId: record.vaultId, revision: record.revision, iv: record.iv, ciphertext: record.ciphertext) {
            for e in payload.schoolEpochs where !out.contains(e) { out.append(e) }
        }
        return out
    }

    // MARK: the decision table (spec §40.1)

    public func status(account: String) async throws -> PostControlsStatus {
        let local = try unlock(account: account)
        let record = try await api.vault()
        switch (local, record) {
        case (let local?, let record?):
            // Both: a newer server revision is merged into the local roots.
            if let state = try storage.loadState(account: account), record.revision > state.revision {
                let payload = try ControlVault.open(r: local.r, vaultId: record.vaultId, revision: record.revision, iv: record.iv, ciphertext: record.ciphertext)
                let roots = try Self.roots(vaultId: record.vaultId, r: local.r, payload: payload)
                try save(account: account, roots: roots, payload: payload, revision: record.revision, wrappers: record.wrappers)
                return .ready(roots, record: record, wrappers: record.wrappers)
            }
            return .ready(local, record: record, wrappers: record.wrappers)
        case (let local?, nil):
            return .localOnly(local)
        case (nil, let record?):
            return .restoreNeeded(record)
        case (nil, nil):
            return .none
        }
    }

    /// Create the initial root M1 and wrapping root R (no/no); nothing uploads until a wrapper exists.
    public func create(account: String, epoch: SchoolEpoch) async throws -> UnlockedRoots {
        if try await api.vault() != nil { throw PostControlsError.vaultExists }
        let m = Data.random(32)
        let r = Data.random(32)
        let t = now()
        let root = ControlVault.newRootRecord(secret: m, now: t)
        let payload = ControlVault.initialPayload(root: root, epochs: [epoch], now: t)
        let vaultId = "v_" + Base64URL.encode(.random(16))
        let roots = try Self.roots(vaultId: vaultId, r: r, payload: payload)
        try save(account: account, roots: roots, payload: payload, revision: 0, wrappers: [])
        return roots
    }

    /// The active roots for publishing; created silently when none exist anywhere.
    public func ensureRoots(account: String, epoch: SchoolEpoch) async throws -> UnlockedRoots {
        switch try await status(account: account) {
        case .ready(let roots, _, _), .localOnly(let roots): return roots
        case .none: return try await create(account: account, epoch: epoch)
        case .restoreNeeded: throw PostControlsError.restoreNeeded
        }
    }

    // MARK: upload with one merge retry (spec §40.2)

    @discardableResult
    public func upload(account: String, roots: UnlockedRoots, payload: ControlVaultPayload, wrappers: [VaultWrapper]) async throws -> VaultRecord {
        var base = try storage.loadState(account: account)?.revision ?? 0
        var current = payload
        var currentWrappers = wrappers
        for _ in 0..<2 {
            let revision = base + 1
            let sealed = try ControlVault.seal(r: roots.r, vaultId: roots.vaultId, revision: revision, payload: current)
            let result = try await api.vaultPut(VaultPutRequest(vaultId: roots.vaultId, baseRevision: base, iv: sealed.iv, ciphertext: sealed.ciphertext, wrappers: currentWrappers))
            switch result {
            case .ok(let rev, _):
                guard let record = try await api.vault(), record.revision == rev else { throw PostControlsError.readbackFailed }
                // Readback + decrypt-verify before anything reports success (spec §40.3 no.6).
                let verified = try ControlVault.open(r: roots.r, vaultId: record.vaultId, revision: record.revision, iv: record.iv, ciphertext: record.ciphertext)
                let merged = try Self.roots(vaultId: record.vaultId, r: roots.r, payload: verified)
                try save(account: account, roots: merged, payload: verified, revision: record.revision, wrappers: record.wrappers)
                return record
            case .conflict(let remoteRecord):
                guard remoteRecord.revision > 0, remoteRecord.vaultId == roots.vaultId else { throw V2Error.vaultConflict("a different vault exists for this account") }
                let remote = try ControlVault.open(r: roots.r, vaultId: remoteRecord.vaultId, revision: remoteRecord.revision, iv: remoteRecord.iv, ciphertext: remoteRecord.ciphertext)
                current = try ControlVault.merge(local: current, remote: remote, now: now())
                currentWrappers = ControlVault.mergeWrappers(local: currentWrappers, remote: remoteRecord.wrappers)
                base = remoteRecord.revision
            }
        }
        throw V2Error.vaultConflict("could not merge")
    }

    // MARK: recovery words (spec §37)

    /// Generates the 12 words, wraps R with them and uploads; the words are returned only after the readback decrypted.
    public func setupRecoveryWords(account: String, epochs: [SchoolEpoch]) async throws -> [String] {
        guard let roots = try unlock(account: account) else { throw PostControlsError.noLocalRoots }
        let secret = RecoveryWords.newSecret()
        let wrapper = try VaultWrappers.wrapWithPhrase(recoverySecret: secret, vaultId: roots.vaultId, r: roots.r, now: now())
        let existing = (try storage.loadState(account: account)?.wrappers ?? []).filter { if case .recoveryPhrase = $0 { return false } else { return true } }
        try await upload(account: account, roots: roots, payload: payload(for: roots, epochs: epochs), wrappers: existing + [.recoveryPhrase(wrapper)])
        return try RecoveryWords.words(from: secret)
    }

    /// Restore on a fresh device from the words (spec §37.3).
    public func restore(account: String, words: String) async throws -> UnlockedRoots {
        guard let secret = RecoveryWords.secret(from: words) else { throw PostControlsError.wrongWords }
        guard let record = try await api.vault() else { throw PostControlsError.noLocalRoots }
        for case .recoveryPhrase(let wrapper) in record.wrappers {
            if let r = try? VaultWrappers.unwrapWithPhrase(recoverySecret: secret, vaultId: record.vaultId, wrapper: wrapper) {
                return try restore(account: account, record: record, r: r)
            }
        }
        throw PostControlsError.wrongWords
    }

    /// With R recovered through any wrapper: decrypt the server vault and keep the roots locally.
    public func restore(account: String, record: VaultRecord, r: Data) throws -> UnlockedRoots {
        let payload = try ControlVault.open(r: r, vaultId: record.vaultId, revision: record.revision, iv: record.iv, ciphertext: record.ciphertext)
        let roots = try Self.roots(vaultId: record.vaultId, r: r, payload: payload)
        try save(account: account, roots: roots, payload: payload, revision: record.revision, wrappers: record.wrappers)
        return roots
    }

    // MARK: passkey PRF (spec §36) — the PRF output comes from the app layer (ASAuthorization)

    public func addPasskeyWrapper(account: String, prfOutput: Data, credentialId: String, label: String?, epochs: [SchoolEpoch]) async throws {
        guard let roots = try unlock(account: account) else { throw PostControlsError.noLocalRoots }
        let wrapper = try VaultWrappers.wrapWithPrf(prfOutput: prfOutput, vaultId: roots.vaultId, credentialId: credentialId, r: roots.r, now: now(), label: label)
        let existing = try storage.loadState(account: account)?.wrappers ?? []
        try await upload(account: account, roots: roots, payload: payload(for: roots, epochs: epochs), wrappers: existing + [.passkeyPrf(wrapper)])
    }

    public func restore(account: String, prfOutput: Data, credentialId: String) async throws -> UnlockedRoots {
        guard let record = try await api.vault() else { throw PostControlsError.noLocalRoots }
        for case .passkeyPrf(let wrapper) in record.wrappers where wrapper.credentialId == credentialId {
            let r = try VaultWrappers.unwrapWithPrf(prfOutput: prfOutput, vaultId: record.vaultId, wrapper: wrapper)
            return try restore(account: account, record: record, r: r)
        }
        throw PostControlsError.wrongWords
    }

    // MARK: another device (spec §38)

    /// New device: make an ephemeral key, register the offer, return the code + the private half to keep in memory.
    public func beginPairing(account: String) async throws -> (offer: PairingOffer, privateKey: String) {
        let pair = Pairing.newKeyPair()
        let offer = try await api.vaultPairingOffer(recipientPublicKey: pair.publicKey)
        return (offer, pair.privateKey)
    }

    /// Signed-in device: seal R to the offer's key.
    public func deliverPairing(account: String, pairingId: String) async throws {
        guard let roots = try unlock(account: account) else { throw PostControlsError.noLocalRoots }
        let offer = try await api.vaultPairingRead(pairingId: pairingId)
        let sealed = try Pairing.seal(recipientPublicKey: offer.recipientPublicKey, pairingId: offer.pairingId, r: roots.r)
        try await api.vaultPairingDeliver(pairingId: offer.pairingId, enc: sealed.enc, ciphertext: sealed.ciphertext)
    }

    /// New device: claim the delivery (nil while the other device has not answered) and restore.
    public func claimPairing(account: String, pairingId: String, privateKey: String) async throws -> UnlockedRoots? {
        guard let delivery = try await api.vaultPairingClaim(pairingId: pairingId) else { return nil }
        guard let record = try await api.vault() else { throw PostControlsError.noLocalRoots }
        let r = try Pairing.open(privateKey: privateKey, pairingId: delivery.pairingId, enc: delivery.enc, ciphertext: delivery.ciphertext)
        return try restore(account: account, record: record, r: r)
    }

    // MARK: rotation · erase · delete (spec §40.3, §40.4)

    public func rotate(account: String, epochs: [SchoolEpoch]) async throws -> UnlockedRoots {
        guard let roots = try unlock(account: account) else { throw PostControlsError.noLocalRoots }
        let rotated = ControlVault.rotated(payload(for: roots, epochs: epochs), newSecret: Data.random(32), now: now())
        let wrappers = try storage.loadState(account: account)?.wrappers ?? []
        let record = try await upload(account: account, roots: roots, payload: rotated, wrappers: wrappers)
        let verified = try ControlVault.open(r: roots.r, vaultId: record.vaultId, revision: record.revision, iv: record.iv, ciphertext: record.ciphertext)
        return try Self.roots(vaultId: record.vaultId, r: roots.r, payload: verified)
    }

    /// Remove the roots from this device only (the server vault stays; restore later through a wrapper).
    public func eraseLocal(account: String) throws {
        try storage.clearState(account: account)
        try storage.clearDeviceSecret(account: account)
    }

    /// Delete the server vault and the local roots (account deletion).
    public func deleteEverywhere(account: String) async throws {
        try await api.vaultDelete()
        try eraseLocal(account: account)
    }
}
