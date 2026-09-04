// The v2 publication flow on the iPhone (spec §31–§34; Web:
// lib/community-v2/publish-client.ts), in one place:
//
//   1. post controls: the device's active root (created silently at the
//      first share unless a server vault exists that this device has not
//      restored yet);
//   2. eligibility: ask the issuer which metadata it would bind (uncounted),
//      blind a token under exactly that, one counted signing round, finalize
//      → a token Core cannot recognise, bound to the scope it verified;
//   3. envelope: signed with the school/year posting key; a fresh post nonce
//      gives this post its own control key;
//   4. check → lane (+ pass) → publish, both to Community with no identity.
//
// Mine, revoke, reactions and reports use the same keys with challenges.

import Foundation

/// The issuer/scope endpoints of Core the flow needs (APIClient conforms).
public protocol IssuerAPI: Sendable {
    func communityIssuer() async throws -> IssuerDescriptor
    func communityScope() async throws -> CommunityScope
    func communityEligibilityInfo(_ target: EligibilityTarget) async throws -> EligibilityInfoResponse
    func communityEligibility(_ request: EligibilityRequest) async throws -> EligibilityIssued
}

/// Device memory of the viewer's own reactions and reactor registrations
/// (Community keeps no per-viewer state; the feed carries none).
public protocol ReactionMemory: Sendable {
    func myReaction(_ experienceId: String) -> Int
    func setMyReaction(_ experienceId: String, _ value: Int)
    func reactorRegistered(_ mark: String) -> Bool
    func setReactorRegistered(_ mark: String)
}

public struct PublishTarget: Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var entityKey: String?
    public init(lessonId: String? = nil, entityKey: String? = nil) {
        self.lessonId = lessonId
        self.entityKey = entityKey
    }
    var eligibility: EligibilityTarget { EligibilityTarget(lessonId: lessonId, entityKey: entityKey) }
}

public struct PreparedPost: Sendable, Equatable {
    public var token: EligibilityToken
    public var envelope: SignedPostEnvelopeV2
    public var postSignature: String
}

public struct OwnedPost: Sendable, Equatable, Identifiable {
    public var experience: MineExperience
    public var rootId: String
    public var epoch: SchoolEpoch
    public var id: String { experience.id }
}

public enum PublishError: Error, Sendable, Equatable {
    case postControlsRestoreNeeded
    case rootNotOnThisDevice
    case controlKeyMismatch
}

public actor PublishClient {
    private let api: IssuerAPI
    private let community: CommunityAPIClient
    private let controls: PostControls
    private let memory: ReactionMemory
    private var session: (scope: CommunityScope, issuer: IssuerDescriptor, key: IssuerRSAPublicKey)?

    public init(api: IssuerAPI, community: CommunityAPIClient, controls: PostControls, memory: ReactionMemory) {
        self.api = api
        self.community = community
        self.controls = controls
        self.memory = memory
    }

    /// Scope (canonical exposure) and issuer descriptor, fetched once per session.
    public func communitySession() async throws -> (scope: CommunityScope, issuer: IssuerDescriptor, key: IssuerRSAPublicKey) {
        if let session { return session }
        async let scope = api.communityScope()
        async let issuer = api.communityIssuer()
        let s = try await scope
        let i = try await issuer
        let session = (s, i, try IssuerRSAPublicKey(descriptor: i))
        self.session = session
        return session
    }

    public func resetSession() { session = nil }

    public func exposure() async throws -> ExposureScope { try await communitySession().scope.exposure }

    private func roots(account: String) async throws -> UnlockedRoots {
        let epoch = try await communitySession().scope.epoch
        do {
            return try await controls.ensureRoots(account: account, epoch: epoch)
        } catch PostControlsError.restoreNeeded {
            throw PublishError.postControlsRestoreNeeded
        }
    }

    // MARK: eligibility (two rounds; only the second is counted)

    public func obtainToken(_ target: EligibilityTarget) async throws -> (token: EligibilityToken, info: EligibilityInfo) {
        let session = try await communitySession()
        let stated = try await api.communityEligibilityInfo(target)
        let info = try BlindToken.infoBytes(stated.info)
        let message = BlindToken.prepare(Data.random(32))
        let blinded = try BlindToken.blind(publicKey: session.key, message: message, info: info)
        let issued = try await api.communityEligibility(EligibilityRequest(target: target, blindedMessage: Base64URL.encode(blinded.blindedMessage)))
        guard let blindSig = Base64URL.decode(issued.blindSignature) else { throw BlindTokenError.unexpectedInputSize }
        let signature = try BlindToken.finalize(publicKey: session.key, blinded: blinded, blindSignature: blindSig)
        return (EligibilityToken(keyId: issued.keyId, info: issued.info, message: Base64URL.encode(message), signature: Base64URL.encode(signature)), issued.info)
    }

    // MARK: prepare · check · publish

    public func preparePost(account: String, target: PublishTarget, body: String, rating: Int?) async throws -> PreparedPost {
        let roots = try await roots(account: account)
        let (token, info) = try await obtainToken(target.eligibility)
        let epoch = info.epoch
        let posting = try V2Derivation.postingKeyPair(root: roots.active.secret, epoch: epoch)
        let postNonce = Data.random(32)
        let control = try V2Derivation.postControlKeyPair(root: roots.active.secret, postNonce: postNonce, epoch: epoch)
        let scope = info.scopeParts
        let envelope = SignedPostEnvelopeV2(
            schoolId: info.schoolId,
            academicYear: info.academicYear,
            primaryEntity: EnvelopeEntity(type: scope.type, id: scope.id),
            contexts: EnvelopeContexts(info.contexts),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: rating,
            postNonce: Base64URL.encode(postNonce),
            postingPublicKey: Base64URL.encode(posting.publicKey),
            controlPublicKey: Base64URL.encode(control.publicKey),
            clientNonce: Base64URL.encode(.random(12))
        )
        let signature = try V2Derivation.signStatement(privateKey: posting.privateKey, envelope)
        return PreparedPost(token: token, envelope: envelope, postSignature: Base64URL.encode(signature))
    }

    public func check(_ prepared: PreparedPost, cooldownTicket: String?) async throws -> CheckResponseV2 {
        try await community.check(CheckRequestV2(token: prepared.token, envelope: prepared.envelope, postSignature: prepared.postSignature, cooldownTicket: cooldownTicket))
    }

    public func publish(_ prepared: PreparedPost, pass: String) async throws -> PublishResponseV2 {
        try await community.publish(PublishRequestV2(token: prepared.token, envelope: prepared.envelope, postSignature: prepared.postSignature, pass: pass))
    }

    // MARK: mine / revoke

    /// Every post any root controls, across every school/year epoch known.
    public func listOwnedPosts(account: String) async throws -> [OwnedPost] {
        guard let roots = try await controls.unlock(account: account) else { return [] }
        let epochs = await controls.epochs(account: account, roots: roots)
        var out: [OwnedPost] = []
        for root in roots.roots {
            for epoch in epochs {
                let posting = try V2Derivation.postingKeyPair(root: root.secret, epoch: epoch)
                let challenge = try await community.mineChallenge()
                let statement = MineStatement(schoolId: epoch.schoolId, academicYear: epoch.academicYear, challenge: challenge.challenge, expiresAt: challenge.expiresAt)
                let signature = try V2Derivation.signStatement(privateKey: posting.privateKey, statement)
                let res = try await community.mine(MineRequest(statement: statement, postingPublicKey: Base64URL.encode(posting.publicKey), signature: Base64URL.encode(signature)))
                for e in res.experiences { out.append(OwnedPost(experience: e, rootId: root.rootId, epoch: epoch)) }
            }
        }
        return out.sorted { $0.experience.createdAt > $1.experience.createdAt }
    }

    public func revoke(account: String, post: OwnedPost) async throws {
        guard let roots = try await controls.unlock(account: account), let root = roots.roots.first(where: { $0.rootId == post.rootId }) else {
            throw PublishError.rootNotOnThisDevice
        }
        guard let nonce = Base64URL.decode(post.experience.postNonce) else { throw PublishError.controlKeyMismatch }
        let control = try V2Derivation.postControlKeyPair(root: root.secret, postNonce: nonce, epoch: post.epoch)
        guard Base64URL.encode(control.publicKey) == post.experience.controlPublicKey else { throw PublishError.controlKeyMismatch }
        let challenge = try await community.revokeChallenge(experienceId: post.id)
        let statement = RevokeStatement(experienceId: post.id, challenge: challenge.challenge, expiresAt: challenge.expiresAt)
        let signature = try V2Derivation.signStatement(privateKey: control.privateKey, statement)
        _ = try await community.revoke(experienceId: post.id, RevokeRequest(statement: statement, signature: Base64URL.encode(signature)))
    }

    // MARK: reactions / reports

    private func reactor(account: String) async throws -> (privateKey: Data, publicKey: String, epoch: SchoolEpoch) {
        let roots = try await roots(account: account)
        let epoch = try await communitySession().scope.epoch
        let key = try V2Derivation.reactionKeyPair(root: roots.active.secret, epoch: epoch)
        let publicKey = Base64URL.encode(key.publicKey)
        let mark = "\(epoch.schoolId)\0\(epoch.academicYear)\0\(publicKey)"
        if !memory.reactorRegistered(mark) {
            // Membership token → the reactor key is registered once per school/year (the server is idempotent).
            let (token, _) = try await obtainToken(.member)
            let statement = RegisterReactorStatement(schoolId: epoch.schoolId, academicYear: epoch.academicYear, reactionPublicKey: publicKey)
            let signature = try V2Derivation.signStatement(privateKey: key.privateKey, statement)
            _ = try await community.registerReactor(RegisterReactorRequest(token: token, statement: statement, signature: Base64URL.encode(signature)))
            memory.setReactorRegistered(mark)
        }
        return (key.privateKey, publicKey, epoch)
    }

    public func react(account: String, experienceId: String, value: Int) async throws -> ReactResponseV2 {
        let r = try await reactor(account: account)
        let statement = ReactStatement(schoolId: r.epoch.schoolId, academicYear: r.epoch.academicYear, experienceId: experienceId, value: value, nonce: Base64URL.encode(.random(12)))
        let signature = try V2Derivation.signStatement(privateKey: r.privateKey, statement)
        let res = try await community.react(experienceId: experienceId, ReactRequestV2(statement: statement, reactionPublicKey: r.publicKey, signature: Base64URL.encode(signature)))
        memory.setMyReaction(experienceId, res.value)
        return res
    }

    public func report(account: String, experienceId: String, category: ReportCategory) async throws {
        let r = try await reactor(account: account)
        let statement = ReportStatement(schoolId: r.epoch.schoolId, academicYear: r.epoch.academicYear, experienceId: experienceId, category: category.rawValue, nonce: Base64URL.encode(.random(12)))
        let signature = try V2Derivation.signStatement(privateKey: r.privateKey, statement)
        _ = try await community.report(experienceId: experienceId, ReportRequestV2(statement: statement, reactionPublicKey: r.publicKey, signature: Base64URL.encode(signature)))
    }
}
