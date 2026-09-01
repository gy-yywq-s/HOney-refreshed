//
//  TestDoubles.swift
//  HOneyTests — mocks and helpers for the pure-logic tests.
//

import Foundation
@testable import HOney

/// Simple async call counter.
actor Counter {
    private(set) var value = 0
    @discardableResult
    func increment() -> Int { value += 1; return value }
}

/// Configurable mock portal auth API. Tracks login invocations.
actor MockPortalAuthAPI: PortalAuthAPI {
    private(set) var loginCount = 0
    var loginDelayNanos: UInt64 = 0
    var loginResult: Result<String, Error> = .success("token-1")
    var identityStudentID = 88
    var identityExpiry = Date().addingTimeInterval(3600)

    func configure(loginResult: Result<String, Error>? = nil,
                   loginDelayNanos: UInt64? = nil,
                   identityExpiry: Date? = nil) {
        if let loginResult { self.loginResult = loginResult }
        if let loginDelayNanos { self.loginDelayNanos = loginDelayNanos }
        if let identityExpiry { self.identityExpiry = identityExpiry }
    }

    func login(_ credentials: PortalCredentials) async throws -> String {
        loginCount += 1
        if loginDelayNanos > 0 { try? await Task.sleep(nanoseconds: loginDelayNanos) }
        return try loginResult.get()
    }

    func identity(token: String) async throws -> (studentID: Int, expiresAt: Date) {
        (identityStudentID, identityExpiry)
    }
}

/// In-memory PortalCredentialVault. Records whether credentials were deleted.
final class InMemoryVault: PortalCredentialVault, @unchecked Sendable {
    var session: PortalSession?
    var credentials: PortalCredentials?
    private(set) var deleteCredentialsCalled = false

    init(session: PortalSession? = nil, credentials: PortalCredentials? = nil) {
        self.session = session
        self.credentials = credentials
    }

    func loadSession() throws -> PortalSession? { session }
    func saveSession(_ session: PortalSession) throws { self.session = session }
    func deleteSession() throws { session = nil }
    func loadAuthorizedCredentialsSilently() throws -> PortalCredentials? { credentials }
    func saveCredentials(_ credentials: PortalCredentials) throws { self.credentials = credentials }
    func deleteCredentials() throws { credentials = nil; deleteCredentialsCalled = true }
}

// MARK: - Experiences / app-lifecycle doubles

/// In-memory ownership-key store: no Keychain in unit tests.
actor InMemoryOwnershipKeyStore: OwnershipKeyStoring {
    private var storage: [String: String]

    init(_ initial: [String: String] = [:]) {
        self.storage = initial
    }

    func map() throws -> [String: String] { storage }
    func keys() throws -> [String] { Array(storage.values) }
    func ownershipKey(for experienceId: String) throws -> String? { storage[experienceId] }
    func add(experienceId: String, ownershipKey: String) throws { storage[experienceId] = ownershipKey }
    func remove(experienceId: String) throws { storage.removeValue(forKey: experienceId) }
    func clear() throws { storage = [:] }
}

/// Scripted stub for the composer's publication flow. Each `…Results` queue is
/// consumed front-to-back; the last element repeats.
actor StubExperienceAPI: ExperiencePublishing {
    private var eligibilityResults: [Result<ExperienceEligibilityResponse, Error>]
    private var checkResults: [Result<CheckExperienceResponse, Error>]
    private var publishResults: [Result<PublishExperienceResponse, Error>]

    private(set) var eligibilityCalls = 0
    private(set) var checkRequests: [CheckExperienceRequest] = []
    private(set) var publishRequests: [PublishExperienceRequest] = []

    var totalCalls: Int { eligibilityCalls + checkRequests.count + publishRequests.count }

    init(
        eligibility: [Result<ExperienceEligibilityResponse, Error>] = [
            .success(ExperienceEligibilityResponse(ok: true, eligibilityToken: "elig-1", expiresAt: 4_000_000_000_000))
        ],
        check: [Result<CheckExperienceResponse, Error>] = [],
        publish: [Result<PublishExperienceResponse, Error>] = [
            .success(PublishExperienceResponse(ok: true, experienceId: "exp-1", ownershipKey: "own-1"))
        ]
    ) {
        self.eligibilityResults = eligibility
        self.checkResults = check
        self.publishResults = publish
    }

    static func lane(
        _ lane: CheckLane,
        reasons: [String] = [],
        pass: String? = nil,
        cooldown: CheckCooldown? = nil
    ) -> CheckExperienceResponse {
        CheckExperienceResponse(lane: lane, reasons: reasons, policyVersion: 1, pass: pass, cooldown: cooldown)
    }

    func experienceEligibility(lessonId: String?, entityKey: String?) async throws -> ExperienceEligibilityResponse {
        eligibilityCalls += 1
        return try Self.next(&eligibilityResults).get()
    }

    func checkExperience(_ request: CheckExperienceRequest) async throws -> CheckExperienceResponse {
        checkRequests.append(request)
        return try Self.next(&checkResults).get()
    }

    func publishExperience(_ request: PublishExperienceRequest) async throws -> PublishExperienceResponse {
        publishRequests.append(request)
        return try Self.next(&publishResults).get()
    }

    private static func next<T>(_ queue: inout [Result<T, Error>]) -> Result<T, Error> {
        guard let first = queue.first else {
            return .failure(HOneyAPIError.invalidResponse)
        }
        if queue.count > 1 { queue.removeFirst() }
        return first
    }
}

/// URLProtocol stub: every request gets a canned per-path response (default 200 {}).
final class StubURLProtocol: URLProtocol {
    /// path → (status, body). Reset per test.
    nonisolated(unsafe) static var responses: [String: (Int, Data)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let (status, data) = Self.responses[path] ?? (200, Data("{}".utf8))
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension AppServices {
    /// Offline stub container for AppModel lifecycle tests: HOney API calls hit
    /// `StubURLProtocol`, stores live in memory / a per-test temp directory.
    static func stub(
        tempDir: URL,
        ownershipKeyStore: any OwnershipKeyStoring = InMemoryOwnershipKeyStore()
    ) -> AppServices {
        let config = AppConfig(
            honeyBaseURL: URL(string: "https://stub.invalid")!,
            portalBaseURL: URL(string: "https://stub.invalid")!,
            portalWebURL: URL(string: "https://stub.invalid")!
        )
        let unique = UUID().uuidString
        let sessionStore = SessionStore(
            keychain: Keychain(service: "test.session.\(unique)"),
            persistenceEnabled: false
        )
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let honeyAPI = HOneyAPI(
            baseURL: config.honeyBaseURL,
            store: sessionStore,
            session: URLSession(configuration: sessionConfig)
        )
        let vault = InMemoryVault()
        return AppServices(
            config: config,
            sessionStore: sessionStore,
            honeyAPI: honeyAPI,
            nextLessonRepository: NextLessonRepository(provider: honeyAPI),
            historyRepository: HistoryRepository(provider: honeyAPI),
            timetableRepository: TimetableRepository(provider: honeyAPI),
            experienceFeedRepository: ExperienceFeedRepository(provider: honeyAPI),
            experienceTargetRepository: ExperienceTargetRepository(api: honeyAPI),
            portalAPI: PortalAPI(baseURL: config.portalBaseURL),
            credentialVault: KeychainCredentialVault(keychain: Keychain(service: "test.portal.\(unique)")),
            portalCoordinator: PortalSessionCoordinator(api: MockPortalAuthAPI(), vault: vault),
            ownershipKeyStore: ownershipKeyStore,
            composerDraftStore: ComposerDraftStore(directory: tempDir),
            privateNoteStore: PrivateNoteStore(directory: tempDir),
            publishedKeyRecoveryStore: PublishedKeyRecoveryStore(directory: tempDir)
        )
    }
}
