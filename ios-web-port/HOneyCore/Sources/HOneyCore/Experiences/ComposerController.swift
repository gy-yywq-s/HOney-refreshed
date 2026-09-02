// Composer state machine (Web: useComposer.ts). The publication flow is
// eligibility → check → publish. `check` never persists the draft and never
// publishes; publication happens ONLY on an explicit action. A `nudge`
// surfaces a preflight choice (add context / share as written / keep
// private). Every non-publish outcome leaves the draft intact. The draft is
// written to the device BEFORE any network call.

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
    /// The post is public but the control key could not be stored on this
    /// iPhone: shown honestly, with the key, until storage succeeds.
    case publishedKeyUnsaved(experienceId: String, ownershipKey: String)
}

public struct ComposerOutcome: Sendable, Equatable {
    public var status: ComposerStatus
    public var notice: ComposerNotice?
}

public struct HeldCooldown: Sendable, Equatable {
    public var ticket: String
    public var retryAt: Int64
}

public struct ComposerDependencies: Sendable {
    public var eligibility: @Sendable (ExperienceEligibilityInput) async throws -> ExperienceEligibilityResponse
    public var check: @Sendable (CheckExperienceInput) async throws -> CheckExperienceResponse
    public var publish: @Sendable (PublishExperienceInput) async throws -> PublishExperienceResponse
    public var storeKey: @Sendable (_ experienceId: String, _ key: String) throws -> Void
    public var saveDraft: @Sendable (_ key: String, _ body: String, _ rating: Int?) -> Void
    public var clearDraft: @Sendable (_ key: String) -> Void
    public var didPublish: @Sendable () async -> Void

    public init(
        eligibility: @escaping @Sendable (ExperienceEligibilityInput) async throws -> ExperienceEligibilityResponse,
        check: @escaping @Sendable (CheckExperienceInput) async throws -> CheckExperienceResponse,
        publish: @escaping @Sendable (PublishExperienceInput) async throws -> PublishExperienceResponse,
        storeKey: @escaping @Sendable (String, String) throws -> Void,
        saveDraft: @escaping @Sendable (String, String, Int?) -> Void,
        clearDraft: @escaping @Sendable (String) -> Void,
        didPublish: @escaping @Sendable () async -> Void = {}
    ) {
        self.eligibility = eligibility
        self.check = check
        self.publish = publish
        self.storeKey = storeKey
        self.saveDraft = saveDraft
        self.clearDraft = clearDraft
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
    private var lastPublished: (experienceId: String, ownershipKey: String)?

    public init(scope: ComposerScope, deps: ComposerDependencies) {
        self.scope = scope
        self.deps = deps
    }

    /// A kept note that was cooling: hold its ticket so the re-check after
    /// the pause reuses it.
    public func seedCooldown(ticket: String, retryAt: Int64, body: String, rating: Int?) {
        cooldown = (ticket, retryAt, body.trimmingCharacters(in: .whitespacesAndNewlines), rating)
    }

    /// The cooling ticket for exactly this text, or nil once the text changed.
    public func heldCooldown(body: String, rating: Int?) -> HeldCooldown? {
        guard let c = cooldown, c.body == body.trimmingCharacters(in: .whitespacesAndNewlines), c.rating == rating else { return nil }
        return HeldCooldown(ticket: c.ticket, retryAt: c.retryAt)
    }

    /// Autosave: keep the durable draft current with the editor.
    public func autosave(body: String, rating: Int?) {
        guard !scope.draftKey.isEmpty else { return }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, rating == nil { return }
        deps.saveDraft(scope.draftKey, body, rating)
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
    public func retryStoringKey() -> ComposerOutcome {
        guard let last = lastPublished else { return ComposerOutcome(status: .editing, notice: nil) }
        do {
            try deps.storeKey(last.experienceId, last.ownershipKey)
            return ComposerOutcome(status: .published(experienceId: last.experienceId, ownershipKey: last.ownershipKey), notice: nil)
        } catch {
            return ComposerOutcome(status: .publishedKeyUnsaved(experienceId: last.experienceId, ownershipKey: last.ownershipKey), notice: nil)
        }
    }

    // MARK: Internals

    private func runCheck(body: String, rating: Int?, ticket: String?) async -> ComposerOutcome {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scope.draftKey.isEmpty else { return ComposerOutcome(status: .editing, notice: nil) }
        // Persist the draft BEFORE any network call — nothing below can lose it.
        deps.saveDraft(scope.draftKey, body, rating)
        pass = nil
        let ratingToSend = scope.isDish ? rating : nil
        do {
            let elig = try await deps.eligibility(scope.eligibilityInput)
            let check = try await deps.check(CheckExperienceInput(
                lessonId: scope.lessonId, entityKey: scope.entityKey, body: trimmed, rating: ratingToSend, cooldownTicket: ticket
            ))
            switch check.lane {
            case .publish:
                guard let contentPass = check.pass else {
                    return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.failedClosed))
                }
                return try await finishPublish(eligibilityToken: elig.eligibilityToken, pass: contentPass, body: body, rating: rating)
            case .nudge:
                guard let contentPass = check.pass else {
                    return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.failedClosed))
                }
                pass = (elig.eligibilityToken, contentPass)
                return ComposerOutcome(status: .nudge(reasons: check.reasons), notice: nil)
            case .cooldown:
                guard let c = check.cooldown else {
                    return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.failedClosed))
                }
                cooldown = (c.ticket, c.retryAt, trimmed, rating)
                return ComposerOutcome(status: .cooldown(retryAt: c.retryAt, reasons: check.reasons), notice: nil)
            case .editRequired:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.editRequired, reasons: check.reasons))
            case .outOfScope:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.outOfScope, reasons: check.reasons, suggestKeepPrivate: true))
            case .blockedSerious:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.blocked))
            case .failedClosed, .unknown:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.failedClosed))
            }
        } catch {
            return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: SubmitErrorCopy.describe(error)))
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
        lastPublished = (result.experienceId, result.ownershipKey)
        await deps.didPublish()
        deps.clearDraft(scope.draftKey)
        do {
            try deps.storeKey(result.experienceId, result.ownershipKey)
        } catch {
            return ComposerOutcome(status: .publishedKeyUnsaved(experienceId: result.experienceId, ownershipKey: result.ownershipKey), notice: nil)
        }
        return ComposerOutcome(status: .published(experienceId: result.experienceId, ownershipKey: result.ownershipKey), notice: nil)
    }
}
