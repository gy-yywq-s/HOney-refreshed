// Wire contract of Anonymous Control v2 (spec Part III) — the ONLY coupling
// between the iPhone, HOney Core (issuer + vault) and HOney Community.
// Every byte field is base64url; every signed statement is signed over its
// JCS bytes. Mirrors packages/shared/src/community-v2/contract.ts field for
// field; the checked-in v2 fixtures decode into these types in
// FixtureDecodingTests.

import Foundation

// MARK: - Eligibility

public struct EligibilityContexts: Codable, Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var courseId: String?
    public var teacherId: String?
    public var roomId: String?
    public init(lessonId: String? = nil, courseId: String? = nil, teacherId: String? = nil, roomId: String? = nil) {
        self.lessonId = lessonId
        self.courseId = courseId
        self.teacherId = teacherId
        self.roomId = roomId
    }
}

/// The public metadata the issuer signs with the blinded token (JCS bytes = `info`).
public struct EligibilityInfo: Codable, Sendable, Equatable, Hashable {
    public var v: Int
    public var schoolId: String
    public var academicYear: String
    /// "<type>:<canonical id>" — lessons use the opaque lesson id.
    public var scope: String
    public var contexts: EligibilityContexts
    public var provenance: String
    /// Portal week index at issuance; a token is redeemable for two weeks.
    public var week: Int

    public init(v: Int = 2, schoolId: String, academicYear: String, scope: String, contexts: EligibilityContexts, provenance: String, week: Int) {
        self.v = v
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.scope = scope
        self.contexts = contexts
        self.provenance = provenance
        self.week = week
    }

    public var epoch: SchoolEpoch { SchoolEpoch(schoolId: schoolId, academicYear: academicYear) }

    /// "<type>" and "<id>" of the scope.
    public var scopeParts: (type: String, id: String) {
        guard let colon = scope.firstIndex(of: ":") else { return (scope, "") }
        return (String(scope[..<colon]), String(scope[scope.index(after: colon)...]))
    }
}

public struct IssuerDescriptor: Codable, Sendable, Equatable {
    public struct PublicKey: Codable, Sendable, Equatable {
        public var kty: String
        public var n: String
        public var e: String
        public var alg: String?
        public init(kty: String = "RSA", n: String, e: String, alg: String? = nil) {
            self.kty = kty
            self.n = n
            self.e = e
            self.alg = alg
        }
    }
    public var suite: String
    public var keyId: String
    public var publicKey: PublicKey
    public init(suite: String, keyId: String, publicKey: PublicKey) {
        self.suite = suite
        self.keyId = keyId
        self.publicKey = publicKey
    }
}

/// What the client asks the issuer about: exactly one of lessonId / entityKey, or school membership.
public struct EligibilityTarget: Encodable, Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var entityKey: String?
    public var schoolMember: Bool?
    public init(lessonId: String? = nil, entityKey: String? = nil, schoolMember: Bool? = nil) {
        self.lessonId = lessonId
        self.entityKey = entityKey
        self.schoolMember = schoolMember
    }
    public static let member = EligibilityTarget(schoolMember: true)
}

/// POST /api/community/eligibility/info (uncounted): the metadata the issuer would bind.
public struct EligibilityInfoResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var info: EligibilityInfo
    public init(ok: Bool, info: EligibilityInfo) {
        self.ok = ok
        self.info = info
    }
}

public struct EligibilityRequest: Encodable, Sendable, Equatable {
    public var lessonId: String?
    public var entityKey: String?
    public var schoolMember: Bool?
    /// Blinded token message (RSAPBSSA blind output), base64url.
    public var blindedMessage: String
    public init(target: EligibilityTarget, blindedMessage: String) {
        lessonId = target.lessonId
        entityKey = target.entityKey
        schoolMember = target.schoolMember
        self.blindedMessage = blindedMessage
    }
}

public struct EligibilityIssued: Codable, Sendable, Equatable {
    public var ok: Bool
    public var keyId: String
    public var info: EligibilityInfo
    /// Blind signature, base64url. The client finalizes it into the token.
    public var blindSignature: String
    public init(ok: Bool, keyId: String, info: EligibilityInfo, blindSignature: String) {
        self.ok = ok
        self.keyId = keyId
        self.info = info
        self.blindSignature = blindSignature
    }
}

/// The redeemable token as Community receives it.
public struct EligibilityToken: Codable, Sendable, Equatable, Hashable {
    public var keyId: String
    public var info: EligibilityInfo
    /// The prepared message (random prefix ‖ nonce), base64url.
    public var message: String
    /// The finalized RSA-PSS signature over msg', base64url.
    public var signature: String
    public init(keyId: String, info: EligibilityInfo, message: String, signature: String) {
        self.keyId = keyId
        self.info = info
        self.message = message
        self.signature = signature
    }
}

/// GET /api/community/scope — the viewer's canonical exposure, for feed scoping.
public struct CommunityScope: Codable, Sendable, Equatable {
    public var schoolId: String
    public var academicYear: String
    public var teachers: [String]
    public var courses: [String]
    /// Opaque lesson ids (never the roster-joinable instance ids).
    public var lessons: [String]
    public init(schoolId: String, academicYear: String, teachers: [String], courses: [String], lessons: [String]) {
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.teachers = teachers
        self.courses = courses
        self.lessons = lessons
    }
    public var epoch: SchoolEpoch { SchoolEpoch(schoolId: schoolId, academicYear: academicYear) }
    public var exposure: ExposureScope { ExposureScope(teachers: teachers, courses: courses, lessons: lessons) }
}

// MARK: - Publication (identity-free; credentials omitted)

public struct EnvelopeEntity: Codable, Sendable, Equatable, Hashable {
    public var type: String
    public var id: String
    public init(type: String, id: String) {
        self.type = type
        self.id = id
    }
}

public struct EnvelopeContexts: Codable, Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var courseId: String?
    public var teacherId: String?
    public var roomId: String?
    public var topicName: String?
    public init(lessonId: String? = nil, courseId: String? = nil, teacherId: String? = nil, roomId: String? = nil, topicName: String? = nil) {
        self.lessonId = lessonId
        self.courseId = courseId
        self.teacherId = teacherId
        self.roomId = roomId
        self.topicName = topicName
    }
    public init(_ c: EligibilityContexts) {
        self.init(lessonId: c.lessonId, courseId: c.courseId, teacherId: c.teacherId, roomId: c.roomId)
    }
}

/// The signed post. `rating` is ALWAYS present on the wire (null when absent)
/// because the Web's envelope carries `rating: null` and the signature is
/// over the JCS bytes of exactly these members.
public struct SignedPostEnvelopeV2: Codable, Sendable, Equatable, Hashable {
    public var protocolVersion: Int
    public var schoolId: String
    public var academicYear: String
    public var primaryEntity: EnvelopeEntity
    public var contexts: EnvelopeContexts
    public var body: String
    public var rating: Int?
    public var postNonce: String
    public var postingPublicKey: String
    public var controlPublicKey: String
    public var clientNonce: String

    public init(protocolVersion: Int = 2, schoolId: String, academicYear: String, primaryEntity: EnvelopeEntity, contexts: EnvelopeContexts, body: String, rating: Int?, postNonce: String, postingPublicKey: String, controlPublicKey: String, clientNonce: String) {
        self.protocolVersion = protocolVersion
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.primaryEntity = primaryEntity
        self.contexts = contexts
        self.body = body
        self.rating = rating
        self.postNonce = postNonce
        self.postingPublicKey = postingPublicKey
        self.controlPublicKey = controlPublicKey
        self.clientNonce = clientNonce
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion, schoolId, academicYear, primaryEntity, contexts, body, rating, postNonce, postingPublicKey, controlPublicKey, clientNonce
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(protocolVersion, forKey: .protocolVersion)
        try c.encode(schoolId, forKey: .schoolId)
        try c.encode(academicYear, forKey: .academicYear)
        try c.encode(primaryEntity, forKey: .primaryEntity)
        try c.encode(contexts, forKey: .contexts)
        try c.encode(body, forKey: .body)
        if let rating { try c.encode(rating, forKey: .rating) } else { try c.encodeNil(forKey: .rating) }
        try c.encode(postNonce, forKey: .postNonce)
        try c.encode(postingPublicKey, forKey: .postingPublicKey)
        try c.encode(controlPublicKey, forKey: .controlPublicKey)
        try c.encode(clientNonce, forKey: .clientNonce)
    }
}

public struct CheckRequestV2: Encodable, Sendable, Equatable {
    public var token: EligibilityToken
    public var envelope: SignedPostEnvelopeV2
    public var postSignature: String
    public var cooldownTicket: String?
    public init(token: EligibilityToken, envelope: SignedPostEnvelopeV2, postSignature: String, cooldownTicket: String? = nil) {
        self.token = token
        self.envelope = envelope
        self.postSignature = postSignature
        self.cooldownTicket = cooldownTicket
    }
}

public enum CheckLaneV2: Sendable, Equatable, Hashable, Codable {
    case publish, nudge, cooldown, editRequired, blockedSerious, outOfScope, failedClosed
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "publish": self = .publish
        case "nudge": self = .nudge
        case "cooldown": self = .cooldown
        case "edit_required": self = .editRequired
        case "blocked_serious": self = .blockedSerious
        case "out_of_scope": self = .outOfScope
        case "failed_closed": self = .failedClosed
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .publish: return "publish"
        case .nudge: return "nudge"
        case .cooldown: return "cooldown"
        case .editRequired: return "edit_required"
        case .blockedSerious: return "blocked_serious"
        case .outOfScope: return "out_of_scope"
        case .failedClosed: return "failed_closed"
        case .unknown(let raw): return raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

public struct CheckResponseV2: Codable, Sendable, Equatable {
    public struct Cooldown: Codable, Sendable, Equatable {
        public var ticket: String
        public var retryAt: Int64
        public init(ticket: String, retryAt: Int64) {
            self.ticket = ticket
            self.retryAt = retryAt
        }
    }
    public var lane: CheckLaneV2
    public var reasons: [String]
    public var policyVersion: Int
    public var pass: String?
    public var cooldown: Cooldown?
    public init(lane: CheckLaneV2, reasons: [String], policyVersion: Int, pass: String? = nil, cooldown: Cooldown? = nil) {
        self.lane = lane
        self.reasons = reasons
        self.policyVersion = policyVersion
        self.pass = pass
        self.cooldown = cooldown
    }
}

public struct PublishRequestV2: Encodable, Sendable, Equatable {
    public var token: EligibilityToken
    public var envelope: SignedPostEnvelopeV2
    public var postSignature: String
    public var pass: String
    public init(token: EligibilityToken, envelope: SignedPostEnvelopeV2, postSignature: String, pass: String) {
        self.token = token
        self.envelope = envelope
        self.postSignature = postSignature
        self.pass = pass
    }
}

public struct PublishResponseV2: Codable, Sendable, Equatable {
    public var ok: Bool
    public var experienceId: String
    public var postNonce: String
    public init(ok: Bool, experienceId: String, postNonce: String) {
        self.ok = ok
        self.experienceId = experienceId
        self.postNonce = postNonce
    }
}

// MARK: - Reading (identity-free; names are null on the wire)

public struct EntityRefV2: Codable, Sendable, Equatable, Hashable {
    public var type: EntitySummaryType
    public var id: String
    /// Always null from Community; clients fill it from Core's entity directory.
    public var name: String?
    public init(type: EntitySummaryType, id: String, name: String? = nil) {
        self.type = type
        self.id = id
        self.name = name
    }
    public var entityKey: String { "\(type.rawValue):\(id)" }
}

public struct ReactionCounts: Codable, Sendable, Equatable, Hashable {
    public var likes: Int
    public var dislikes: Int
    public init(likes: Int, dislikes: Int) {
        self.likes = likes
        self.dislikes = dislikes
    }
}

public struct PublicExperienceV2: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var primary: EntityRefV2
    public var contexts: [EntityRefV2]
    public var body: String?
    public var rating: Int?
    public var provenance: ExperienceProvenance
    /// Days since epoch — exact timestamps never exist publicly.
    public var publishedDay: Int?
    /// nil = counts hidden (small cohort).
    public var reactions: ReactionCounts?

    public init(id: String, primary: EntityRefV2, contexts: [EntityRefV2], body: String?, rating: Int? = nil, provenance: ExperienceProvenance, publishedDay: Int?, reactions: ReactionCounts?) {
        self.id = id
        self.primary = primary
        self.contexts = contexts
        self.body = body
        self.rating = rating
        self.provenance = provenance
        self.publishedDay = publishedDay
        self.reactions = reactions
    }
}

public struct ExposureScope: Codable, Sendable, Equatable, Hashable {
    public var teachers: [String]
    public var courses: [String]
    public var lessons: [String]
    public init(teachers: [String], courses: [String], lessons: [String]) {
        self.teachers = teachers
        self.courses = courses
        self.lessons = lessons
    }
}

public enum FeedScope: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case myClasses = "my_classes"
    case school
}

public struct FeedRequestV2: Encodable, Sendable, Equatable, Hashable {
    public var scope: FeedScope
    public var exposure: ExposureScope?
    public var cursor: String?
    public var limit: Int?
    public var entityKey: String?
    public var teacherId: String?
    public var courseId: String?
    public var roomId: String?
    public init(scope: FeedScope, exposure: ExposureScope? = nil, cursor: String? = nil, limit: Int? = nil, entityKey: String? = nil, teacherId: String? = nil, courseId: String? = nil, roomId: String? = nil) {
        self.scope = scope
        self.exposure = exposure
        self.cursor = cursor
        self.limit = limit
        self.entityKey = entityKey
        self.teacherId = teacherId
        self.courseId = courseId
        self.roomId = roomId
    }
}

public struct FeedPageV2: Codable, Sendable, Equatable {
    public var items: [PublicExperienceV2]
    public var nextCursor: String?
    public var headCursor: String?
    public init(items: [PublicExperienceV2], nextCursor: String?, headCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
        self.headCursor = headCursor
    }
}

public struct FeedUpdatesRequestV2: Encodable, Sendable, Equatable {
    public var scope: FeedScope
    public var exposure: ExposureScope?
    public var head: String
    public init(scope: FeedScope, exposure: ExposureScope?, head: String) {
        self.scope = scope
        self.exposure = exposure
        self.head = head
    }
}

public struct FeedUpdatesResponse: Codable, Sendable, Equatable {
    public var newItemsAvailable: Bool
    public init(newItemsAvailable: Bool) { self.newItemsAvailable = newItemsAvailable }
}

public struct FromMyClassesRequestV2: Encodable, Sendable, Equatable {
    public var exposure: ExposureScope
    public var before: Int64?
    public var limit: Int?
    public init(exposure: ExposureScope, before: Int64? = nil, limit: Int? = nil) {
        self.exposure = exposure
        self.before = before
        self.limit = limit
    }
}

public struct ExperiencesListV2: Codable, Sendable, Equatable {
    public var experiences: [PublicExperienceV2]
    public init(experiences: [PublicExperienceV2]) { self.experiences = experiences }
}

public struct SearchResponseV2: Codable, Sendable, Equatable {
    public var q: String
    public var experiences: [PublicExperienceV2]
    public init(q: String, experiences: [PublicExperienceV2]) {
        self.q = q
        self.experiences = experiences
    }
}

/// Descriptive counts for an entity page — never a score.
public struct EntityStatsV2: Codable, Sendable, Equatable {
    public var experiences: Int
    public var courses: Int
    public var teachers: Int
    public init(experiences: Int, courses: Int, teachers: Int) {
        self.experiences = experiences
        self.courses = courses
        self.teachers = teachers
    }
}

// MARK: - Ownership: mine (posting key) · revoke (control key)

public struct ChallengeResponse: Codable, Sendable, Equatable {
    public var challenge: String
    public var expiresAt: Int64
    public init(challenge: String, expiresAt: Int64) {
        self.challenge = challenge
        self.expiresAt = expiresAt
    }
}

public struct MineStatement: Codable, Sendable, Equatable {
    public var purpose: String
    public var schoolId: String
    public var academicYear: String
    public var challenge: String
    public var expiresAt: Int64
    public init(schoolId: String, academicYear: String, challenge: String, expiresAt: Int64) {
        purpose = V2Labels.purposeMine
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.challenge = challenge
        self.expiresAt = expiresAt
    }
}

public struct MineRequest: Encodable, Sendable, Equatable {
    public var statement: MineStatement
    public var postingPublicKey: String
    public var signature: String
    public init(statement: MineStatement, postingPublicKey: String, signature: String) {
        self.statement = statement
        self.postingPublicKey = postingPublicKey
        self.signature = signature
    }
}

public struct MineEntity: Codable, Sendable, Equatable, Hashable {
    public var type: String
    public var id: String
    public var name: String?
    public init(type: String, id: String, name: String? = nil) {
        self.type = type
        self.id = id
        self.name = name
    }
}

public enum MineStatus: Sendable, Equatable, Hashable, Codable {
    case published, blocked
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "published": self = .published
        case "blocked": self = .blocked
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .published: return "published"
        case .blocked: return "blocked"
        case .unknown(let raw): return raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

public struct MineExperience: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var primaryEntity: MineEntity
    public var contexts: [MineEntity]
    public var body: String?
    public var rating: Int?
    public var provenance: ExperienceProvenance
    public var status: MineStatus
    public var statusDetail: String?
    public var postNonce: String
    public var controlPublicKey: String
    public var createdAt: Int64

    public init(id: String, primaryEntity: MineEntity, contexts: [MineEntity], body: String?, rating: Int? = nil, provenance: ExperienceProvenance, status: MineStatus, statusDetail: String? = nil, postNonce: String, controlPublicKey: String, createdAt: Int64) {
        self.id = id
        self.primaryEntity = primaryEntity
        self.contexts = contexts
        self.body = body
        self.rating = rating
        self.provenance = provenance
        self.status = status
        self.statusDetail = statusDetail
        self.postNonce = postNonce
        self.controlPublicKey = controlPublicKey
        self.createdAt = createdAt
    }
}

public struct MineResponse: Codable, Sendable, Equatable {
    public var experiences: [MineExperience]
    public init(experiences: [MineExperience]) { self.experiences = experiences }
}

public struct RevokeStatement: Codable, Sendable, Equatable {
    public var purpose: String
    public var experienceId: String
    public var challenge: String
    public var expiresAt: Int64
    public init(experienceId: String, challenge: String, expiresAt: Int64) {
        purpose = V2Labels.purposeRevoke
        self.experienceId = experienceId
        self.challenge = challenge
        self.expiresAt = expiresAt
    }
}

public struct RevokeRequest: Encodable, Sendable, Equatable {
    public var statement: RevokeStatement
    public var signature: String
    public init(statement: RevokeStatement, signature: String) {
        self.statement = statement
        self.signature = signature
    }
}

// MARK: - Reactions and reports (school/year reactor key)

public struct RegisterReactorStatement: Codable, Sendable, Equatable {
    public var purpose: String
    public var schoolId: String
    public var academicYear: String
    public var reactionPublicKey: String
    public init(schoolId: String, academicYear: String, reactionPublicKey: String) {
        purpose = V2Labels.purposeRegisterReactor
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.reactionPublicKey = reactionPublicKey
    }
}

public struct RegisterReactorRequest: Encodable, Sendable, Equatable {
    public var token: EligibilityToken
    public var statement: RegisterReactorStatement
    public var signature: String
    public init(token: EligibilityToken, statement: RegisterReactorStatement, signature: String) {
        self.token = token
        self.statement = statement
        self.signature = signature
    }
}

public struct ReactStatement: Codable, Sendable, Equatable {
    public var purpose: String
    public var schoolId: String
    public var academicYear: String
    public var experienceId: String
    public var value: Int
    public var nonce: String
    public init(schoolId: String, academicYear: String, experienceId: String, value: Int, nonce: String) {
        purpose = V2Labels.purposeReact
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.experienceId = experienceId
        self.value = value
        self.nonce = nonce
    }
}

public struct ReactRequestV2: Encodable, Sendable, Equatable {
    public var statement: ReactStatement
    public var reactionPublicKey: String
    public var signature: String
    public init(statement: ReactStatement, reactionPublicKey: String, signature: String) {
        self.statement = statement
        self.reactionPublicKey = reactionPublicKey
        self.signature = signature
    }
}

public struct ReactResponseV2: Codable, Sendable, Equatable {
    public var ok: Bool
    public var value: Int
    public var reactions: ReactionCounts?
    public init(ok: Bool, value: Int, reactions: ReactionCounts?) {
        self.ok = ok
        self.value = value
        self.reactions = reactions
    }
}

public struct ReportStatement: Codable, Sendable, Equatable {
    public var purpose: String
    public var schoolId: String
    public var academicYear: String
    public var experienceId: String
    public var category: String
    public var nonce: String
    public init(schoolId: String, academicYear: String, experienceId: String, category: String, nonce: String) {
        purpose = V2Labels.purposeReport
        self.schoolId = schoolId
        self.academicYear = academicYear
        self.experienceId = experienceId
        self.category = category
        self.nonce = nonce
    }
}

public struct ReportRequestV2: Encodable, Sendable, Equatable {
    public var statement: ReportStatement
    public var reactionPublicKey: String
    public var signature: String
    public init(statement: ReportStatement, reactionPublicKey: String, signature: String) {
        self.statement = statement
        self.reactionPublicKey = reactionPublicKey
        self.signature = signature
    }
}

// MARK: - Control Vault (Core stores ciphertext it cannot read)

public struct PasskeyPrfWrapper: Codable, Sendable, Equatable {
    public var type: String = "passkey_prf"
    public var credentialId: String
    public var prfInput: String
    public var iv: String
    public var wrappedR: String
    public var createdAt: Int64
    public var label: String?
    public init(credentialId: String, prfInput: String, iv: String, wrappedR: String, createdAt: Int64, label: String? = nil) {
        self.credentialId = credentialId
        self.prfInput = prfInput
        self.iv = iv
        self.wrappedR = wrappedR
        self.createdAt = createdAt
        self.label = label
    }
}

public struct RecoveryPhraseWrapper: Codable, Sendable, Equatable {
    public var type: String = "recovery_phrase"
    public var format: String = V2Labels.recoveryPhraseFormat
    public var iv: String
    public var wrappedR: String
    public var createdAt: Int64
    public init(iv: String, wrappedR: String, createdAt: Int64) {
        self.iv = iv
        self.wrappedR = wrappedR
        self.createdAt = createdAt
    }
}

/// A wrapper as the vault record lists it; unknown kinds are carried through untouched.
public enum VaultWrapper: Codable, Sendable, Equatable {
    case passkeyPrf(PasskeyPrfWrapper)
    case recoveryPhrase(RecoveryPhraseWrapper)
    case unknown(JSONValue)

    public var stableId: String {
        switch self {
        case .passkeyPrf(let w): return "prf:\(w.credentialId)"
        case .recoveryPhrase(let w): return "phrase:\(w.wrappedR)"
        case .unknown(let v): return "unknown:\(v.canonical)"
        }
    }

    private struct Probe: Decodable { let type: String }

    public init(from decoder: Decoder) throws {
        let type = try Probe(from: decoder).type
        switch type {
        case "passkey_prf": self = .passkeyPrf(try PasskeyPrfWrapper(from: decoder))
        case "recovery_phrase": self = .recoveryPhrase(try RecoveryPhraseWrapper(from: decoder))
        default: self = .unknown(try JSONValue(decoding: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .passkeyPrf(let w): try w.encode(to: encoder)
        case .recoveryPhrase(let w): try w.encode(to: encoder)
        case .unknown(let v): try v.encode(to: encoder)
        }
    }
}

public struct VaultRecord: Codable, Sendable, Equatable {
    public var vaultId: String
    public var revision: Int
    public var iv: String
    /// AES-256-GCM ciphertext ‖ tag, base64url.
    public var ciphertext: String
    public var wrappers: [VaultWrapper]
    public var updatedAt: Int64
    public init(vaultId: String, revision: Int, iv: String, ciphertext: String, wrappers: [VaultWrapper], updatedAt: Int64) {
        self.vaultId = vaultId
        self.revision = revision
        self.iv = iv
        self.ciphertext = ciphertext
        self.wrappers = wrappers
        self.updatedAt = updatedAt
    }
}

public struct VaultPutRequest: Encodable, Sendable, Equatable {
    public var vaultId: String
    /// The revision this write is based on (0 for a first write).
    public var baseRevision: Int
    public var iv: String
    public var ciphertext: String
    public var wrappers: [VaultWrapper]
    public init(vaultId: String, baseRevision: Int, iv: String, ciphertext: String, wrappers: [VaultWrapper]) {
        self.vaultId = vaultId
        self.baseRevision = baseRevision
        self.iv = iv
        self.ciphertext = ciphertext
        self.wrappers = wrappers
    }
}

public enum VaultPutResponse: Sendable, Equatable, Decodable {
    case ok(revision: Int, updatedAt: Int64)
    case conflict(current: VaultRecord)

    private enum CodingKeys: String, CodingKey { case ok, revision, updatedAt, error, current }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if try c.decode(Bool.self, forKey: .ok) {
            self = .ok(revision: try c.decode(Int.self, forKey: .revision), updatedAt: try c.decode(Int64.self, forKey: .updatedAt))
        } else {
            self = .conflict(current: try c.decode(VaultRecord.self, forKey: .current))
        }
    }
}

/// Pairing relay: short-lived HPKE ciphertext of R, addressed by a code.
public struct PairingOffer: Codable, Sendable, Equatable {
    public var pairingId: String
    /// New device's ephemeral X25519 public key, base64url (32 bytes).
    public var recipientPublicKey: String
    public var expiresAt: Int64
    public init(pairingId: String, recipientPublicKey: String, expiresAt: Int64) {
        self.pairingId = pairingId
        self.recipientPublicKey = recipientPublicKey
        self.expiresAt = expiresAt
    }
}

public struct PairingDelivery: Codable, Sendable, Equatable {
    public var pairingId: String
    public var enc: String
    public var ciphertext: String
    public init(pairingId: String, enc: String, ciphertext: String) {
        self.pairingId = pairingId
        self.enc = enc
        self.ciphertext = ciphertext
    }
}

// MARK: - JSONValue as Codable (carries unknown wrapper kinds through)

extension JSONValue: Codable {
    public init(decoding decoder: Decoder) throws {
        try self.init(from: decoder)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int64.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
