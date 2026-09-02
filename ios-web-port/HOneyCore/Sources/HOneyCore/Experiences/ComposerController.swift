// Composer state machine (Web: useComposer.ts). The publication flow is
// eligibility → check → publish. `check` never persists the draft and never
// publishes; publication happens ONLY on an explicit action. A `nudge`
// surfaces a preflight choice (add context / share as written / keep
// private). Every non-publish outcome leaves the draft intact.
//
// Storage truth (review 11d42e3 §3.3): the draft is written to the device
// BEFORE any network call and the outcome says whether that write really
// happened; after a publish the control key is journaled durably BEFORE
// the draft is cleared or the Keychain is asked, and the Keychain write is
// read back before the journal entry is dropped.

import Foundation

public struct ComposerScope: Sendable, Equatable, Hashable {
    public var lessonId: String?
    public var entityKey: String?
    public var isDish: Bool

    public init(lessonId: String? = nil, entityKey: String? = nil, isDish: Bool = false) {
        self.lessonId = lessonId
        self.entityKey = entityKey
        self.isDish = isDish
    }

    public var draftKey: String { lessonId.map { "lesson:\($0)" } ?? (entityKey ?? "") }

    var eligibilityInput: ExperienceEligibilityInput {
        ExperienceEligibilityInput(lessonId: lessonId, entityKey: entityKey)
    }
}

public struct ComposerNotice: Sendable, Equatable {
    public enum Tone: Sendable, Equatable { case warn, danger }
    public var tone: Tone
    public var text: String
    public var reasons: [String]
    public var suggestKeepPrivate: Bool

    public init(tone: Tone, text: String, reasons: [String] = [], suggestKeepPrivate: Bool = false) {
        self.tone = tone
        self.text = text
        self.reasons = reasons
        self.suggestKeepPrivate = suggestKeepPrivate
    }
}

public enum ComposerStatus: Sendable, Equatable {
    case editing
    case checking
    case nudge(reasons: [String])
    case cooldown(retryAt: Int64, reasons: [String])
    case published(experienceId: String, ownershipKey: String)
    /// The post is public but the control key is not in the Keychain.
    /// `journaled` = the key is at least in the on-device recovery journal
    /// and will be retried on every launch; false = only this screen has it.
    case publishedKeyUnsaved(experienceId: String, ownershipKey: String, journaled: Bool)
}

public struct ComposerOutcome: Sendable, Equatable {
    public var status: ComposerStatus
    public var notice: ComposerNotice?
    /// False when the draft could not be written before the network call —
    /// the UI must not say "your draft is safe".
    public var draftPersisted: Bool = true
}

public struct HeldCooldown: Sendable, Equatable {
    public var ticket: String
    public var retryAt: Int64
}

/// The moderation decision as the composer consumes it — an adapter over
/// the current `CheckLane` contract (review §5.1), so a later richer
/// Standing → Expression → Scope → Timing contract changes this mapping
/// and nothing in the views.
public enum ModerationDecision: Sendable, Equatable {
    case publishable(pass: String)
    case nudge(pass: String, reasons: [String])
    case cooldown(ticket: String, retryAt: Int64, reasons: [String])
    case editRequired(reasons: [String])
    case outOfScope(reasons: [String])
    case blocked
    case unavailable

    public init(_ response: CheckExperienceResponse) {
        switch response.lane {
        case .publish:
            if let pass = response.pass { self = .publishable(pass: pass) } else { self = .unavailable }
        case .nudge:
            if let pass = response.pass { self = .nudge(pass: pass, reasons: response.reasons) } else { self = .unavailable }
        case .cooldown:
            if let c = response.cooldown { self = .cooldown(ticket: c.ticket, retryAt: c.retryAt, reasons: response.reasons) } else { self = .unavailable }
        case .editRequired: self = .editRequired(reasons: response.reasons)
        case .outOfScope: self = .outOfScope(reasons: response.reasons)
        case .blockedSerious: self = .blocked
        case .failedClosed, .unknown: self = .unavailable
        }
    }
}

public struct ComposerDependencies: Sendable {
    public var eligibility: @Sendable (ExperienceEligibilityInput) async throws -> ExperienceEligibilityResponse
    public var check: @Sendable (CheckExperienceInput) async throws -> CheckExperienceResponse
    public var publish: @Sendable (PublishExperienceInput) async throws -> PublishExperienceResponse
    public var storeKey: @Sendable (_ experienceId: String, _ key: String) throws -> Void
    /// Read the Keychain back: is the key for this post really there?
    public var keyIsStored: @Sendable (_ experienceId: String) -> Bool
    public var saveDraft: @Sendable (_ key: String, _ body: String, _ rating: Int?) throws -> Void
    public var clearDraft: @Sendable (_ key: String) throws -> Void
    public var journalWrite: @Sendable (PublicationRecord) async throws -> Void
    public var journalRemove: @Sendable (_ experienceId: String) async throws -> Void
    public var didPublish: @Sendable () async -> Void

    public init(
        eligibility: @escaping @Sendable (ExperienceEligibilityInput) async throws -> ExperienceEligibilityResponse,
        check: @escaping @Sendable (CheckExperienceInput) async throws -> CheckExperienceResponse,
        publish: @escaping @Sendable (PublishExperienceInput) async throws -> PublishExperienceResponse,
        storeKey: @escaping @Sendable (String, String) throws -> Void,
        keyIsStored: @escaping @Sendable (String) -> Bool,
        saveDraft: @escaping @Sendable (String, String, Int?) throws -> Void,
        clearDraft: @escaping @Sendable (String) throws -> Void,
        journalWrite: @escaping @Sendable (PublicationRecord) async throws -> Void,
        journalRemove: @escaping @Sendable (String) async throws -> Void,
        didPublish: @escaping @Sendable () async -> Void = {}
    ) {
        self.eligibility = eligibility
        self.check = check
        self.publish = publish
        self.storeKey = storeKey
        self.keyIsStored = keyIsStored
        self.saveDraft = saveDraft
        self.clearDraft = clearDraft
        self.journalWrite = journalWrite
        self.journalRemove = journalRemove
        self.didPublish = didPublish
    }
}

public actor ComposerController {
    public let scope: ComposerScope
    private let deps: ComposerDependencies

    /// Held between a `nudge` and the student's explicit follow-up.
    private var pass: (eligibilityToken: String, pass: String)?
    /// The cooldown ticket is CONTENT-BOUND server-side: keep the text it was
    /// issued for, so an edited draft re-checks fresh.
    private var cooldown: (ticket: String, retryAt: Int64, body: String, rating: Int?)?
    private var lastPublished: (experienceId: String, ownershipKey: String, journaled: Bool)?
    /// The last text that went through the check path (for honest "kept private" copy).
    private var lastChecked: (body: String, rating: Int?)?

    public init(scope: ComposerScope, deps: ComposerDependencies) {
        self.scope = scope
        self.deps = deps
    }

    /// A kept note that was cooling: hold its ticket so the re-check after
    /// the pause reuses it.
    public func seedCooldown(ticket: String, retryAt: Int64, body: String, rating: Int?) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        cooldown = (ticket, retryAt, trimmed, rating)
        lastChecked = (trimmed, rating)
    }

    /// The cooling ticket for exactly this text, or nil once the text changed.
    public func heldCooldown(body: String, rating: Int?) -> HeldCooldown? {
        guard let c = cooldown, c.body == body.trimmingCharacters(in: .whitespacesAndNewlines), c.rating == rating else { return nil }
        return HeldCooldown(ticket: c.ticket, retryAt: c.retryAt)
    }

    /// Whether exactly this text was sent through the pre-publication check.
    public func wasChecked(body: String, rating: Int?) -> Bool {
        guard let c = lastChecked else { return false }
        return c.body == body.trimmingCharacters(in: .whitespacesAndNewlines) && c.rating == rating
    }

    /// Autosave: keep the durable draft current with the editor. Returns
    /// whether the bytes are really on the device.
    @discardableResult
    public func autosave(body: String, rating: Int?) -> Bool {
        guard !scope.draftKey.isEmpty else { return false }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rating == nil { return true }
        do {
            try deps.saveDraft(scope.draftKey, body, rating)
            return true
        } catch {
            return false
        }
    }

    /// "Continue to share": an ordinary check; after a pause the held ticket
    /// is reused for unchanged text.
    public func continueToShare(body: String, rating: Int?) async -> ComposerOutcome {
        let held = heldCooldown(body: body, rating: rating)
        return await runCheck(body: body, rating: rating, ticket: held?.ticket)
    }

    /// "Share as written" from the nudge preflight: an explicit publish.
    public func shareAsWritten(body: String, rating: Int?) async -> ComposerOutcome {
        guard let held = pass else { return await runCheck(body: body, rating: rating, ticket: nil) }
        do {
            return try await finishPublish(eligibilityToken: held.eligibilityToken, pass: held.pass, body: body, rating: rating)
        } catch let error as APIError where error.code.hasPrefix("eligibility_") || error.code.hasPrefix("pass_") {
            // A stale token/pass (rare — 10 min+ later) just re-runs the check.
            pass = nil
            return await runCheck(body: body, rating: rating, ticket: nil)
        } catch {
            return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: SubmitErrorCopy.describe(error)))
        }
    }

    /// Leave the nudge preflight to add more context, keeping the draft.
    public func backToEditing() -> ComposerOutcome {
        pass = nil
        return ComposerOutcome(status: .editing, notice: nil)
    }

    /// Retry storing the control key after a publish whose key save failed.
    public func retryStoringKey() async -> ComposerOutcome {
        guard let last = lastPublished else { return ComposerOutcome(status: .editing, notice: nil) }
        return await settleKey(experienceId: last.experienceId, ownershipKey: last.ownershipKey, journaled: last.journaled)
    }

    // MARK: Internals

    private func runCheck(body: String, rating: Int?, ticket: String?) async -> ComposerOutcome {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scope.draftKey.isEmpty else { return ComposerOutcome(status: .editing, notice: nil) }
        // Persist the draft BEFORE any network call; say so honestly if it failed.
        var persisted = true
        do { try deps.saveDraft(scope.draftKey, body, rating) } catch { persisted = false }
        pass = nil
        let ratingToSend = scope.isDish ? rating : nil
        do {
            let elig = try await deps.eligibility(scope.eligibilityInput)
            let check = try await deps.check(CheckExperienceInput(
                lessonId: scope.lessonId, entityKey: scope.entityKey, body: trimmed, rating: ratingToSend, cooldownTicket: ticket
            ))
            lastChecked = (trimmed, rating)
            switch ModerationDecision(check) {
            case .publishable(let contentPass):
                var outcome = try await finishPublish(eligibilityToken: elig.eligibilityToken, pass: contentPass, body: body, rating: rating)
                outcome.draftPersisted = persisted
                return outcome
            case .nudge(let contentPass, let reasons):
                pass = (elig.eligibilityToken, contentPass)
                return ComposerOutcome(status: .nudge(reasons: reasons), notice: nil, draftPersisted: persisted)
            case .cooldown(let cooldownTicket, let retryAt, let reasons):
                cooldown = (cooldownTicket, retryAt, trimmed, rating)
                return ComposerOutcome(status: .cooldown(retryAt: retryAt, reasons: reasons), notice: nil, draftPersisted: persisted)
            case .editRequired(let reasons):
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.editRequired, reasons: reasons), draftPersisted: persisted)
            case .outOfScope(let reasons):
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.outOfScope, reasons: reasons, suggestKeepPrivate: true), draftPersisted: persisted)
            case .blocked:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.blocked), draftPersisted: persisted)
            case .unavailable:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: persisted ? ModerationCopy.failedClosed : ModerationCopy.failedClosedUnsaved), draftPersisted: persisted)
            }
        } catch {
            return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: SubmitErrorCopy.describe(error)), draftPersisted: persisted)
        }
    }

    private func finishPublish(eligibilityToken: String, pass contentPass: String, body: String, rating: Int?) async throws -> ComposerOutcome {
        let result = try await deps.publish(PublishExperienceInput(
            eligibilityToken: eligibilityToken,
            pass: contentPass,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: scope.isDish ? rating : nil
        ))
        pass = nil
        cooldown = nil
        // The post is public from here on. Journal the key durably first.
        var journaled = false
        do {
            try await deps.journalWrite(PublicationRecord(experienceId: result.experienceId, ownershipKey: result.ownershipKey, targetKey: scope.draftKey, createdAt: HOneyClock.now().epochMillis))
            journaled = true
        } catch {
            journaled = false
        }
        lastPublished = (result.experienceId, result.ownershipKey, journaled)
        await deps.didPublish()
        return await settleKey(experienceId: result.experienceId, ownershipKey: result.ownershipKey, journaled: journaled)
    }

    /// Keychain write + readback; only then the journal entry and the draft go.
    private func settleKey(experienceId: String, ownershipKey: String, journaled: Bool) async -> ComposerOutcome {
        do {
            try deps.storeKey(experienceId, ownershipKey)
            guard deps.keyIsStored(experienceId) else { throw SecretStoreError.writeFailed }
        } catch {
            if !journaled {
                // Keep the draft too: the words are the only other thing the student has.
                return ComposerOutcome(status: .publishedKeyUnsaved(experienceId: experienceId, ownershipKey: ownershipKey, journaled: false), notice: nil)
            }
            try? deps.clearDraft(scope.draftKey)
            return ComposerOutcome(status: .publishedKeyUnsaved(experienceId: experienceId, ownershipKey: ownershipKey, journaled: true), notice: nil)
        }
        if journaled { try? await deps.journalRemove(experienceId) }
        try? deps.clearDraft(scope.draftKey)
        lastPublished = nil
        return ComposerOutcome(status: .published(experienceId: experienceId, ownershipKey: ownershipKey), notice: nil)
    }
}
