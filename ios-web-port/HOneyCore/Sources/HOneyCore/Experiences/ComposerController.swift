// Composer state machine (Web: useComposer.ts). The v2 publication flow is
// prepare (post controls + blind eligibility + signed envelope) → check →
// publish. `check` never persists the draft and never publishes;
// publication happens ONLY on an explicit action. A `nudge` surfaces a
// preflight choice (add context / share as written / keep private). Every
// non-publish outcome leaves the draft intact.
//
// Storage truth (review 11d42e3 §3.3): the draft is written to the device
// BEFORE any network call and the outcome says whether that write really
// happened. There is no per-post key to store any more: the post's control
// key is derived from the device's root and the post nonce, so nothing can
// be lost between publish and Keychain.

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

    public var target: PublishTarget { PublishTarget(lessonId: lessonId, entityKey: entityKey) }
}

public struct ComposerNotice: Sendable, Equatable {
    public enum Tone: Sendable, Equatable { case warn, danger }
    public var tone: Tone
    public var text: String
    public var reasons: [String]
    public var suggestKeepPrivate: Bool
    /// Out of scope here may belong to the school's own feedback channel
    /// (Web 2026-09-04: "Send this to the school instead").
    public var suggestSchoolReport: Bool

    public init(tone: Tone, text: String, reasons: [String] = [], suggestKeepPrivate: Bool = false, suggestSchoolReport: Bool = false) {
        self.tone = tone
        self.text = text
        self.reasons = reasons
        self.suggestKeepPrivate = suggestKeepPrivate
        self.suggestSchoolReport = suggestSchoolReport
    }
}

public enum ComposerStatus: Sendable, Equatable {
    case editing
    case checking
    case nudge(reasons: [String])
    case cooldown(retryAt: Int64, reasons: [String])
    case published(experienceId: String)
    /// A server vault exists that this iPhone has not restored: sharing waits
    /// for Settings › Post controls (the draft stays).
    case postControlsRestoreNeeded
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
/// the `CheckLaneV2` contract, so a later richer Standing → Expression →
/// Scope → Timing contract changes this mapping and nothing in the views.
public enum ModerationDecision: Sendable, Equatable {
    case publishable(pass: String)
    case nudge(pass: String, reasons: [String])
    case cooldown(ticket: String, retryAt: Int64, reasons: [String])
    case editRequired(reasons: [String])
    case outOfScope(reasons: [String])
    case blocked
    case unavailable

    public init(_ response: CheckResponseV2) {
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
    /// Post controls + blind eligibility + signed envelope (PublishClient.preparePost).
    public var prepare: @Sendable (_ target: PublishTarget, _ body: String, _ rating: Int?) async throws -> PreparedPost
    public var check: @Sendable (_ prepared: PreparedPost, _ cooldownTicket: String?) async throws -> CheckResponseV2
    public var publish: @Sendable (_ prepared: PreparedPost, _ pass: String) async throws -> PublishResponseV2
    public var saveDraft: @Sendable (_ key: String, _ body: String, _ rating: Int?) throws -> Void
    public var clearDraft: @Sendable (_ key: String) throws -> Void
    public var didPublish: @Sendable () async -> Void

    public init(
        prepare: @escaping @Sendable (PublishTarget, String, Int?) async throws -> PreparedPost,
        check: @escaping @Sendable (PreparedPost, String?) async throws -> CheckResponseV2,
        publish: @escaping @Sendable (PreparedPost, String) async throws -> PublishResponseV2,
        saveDraft: @escaping @Sendable (String, String, Int?) throws -> Void,
        clearDraft: @escaping @Sendable (String) throws -> Void,
        didPublish: @escaping @Sendable () async -> Void = {}
    ) {
        self.prepare = prepare
        self.check = check
        self.publish = publish
        self.saveDraft = saveDraft
        self.clearDraft = clearDraft
        self.didPublish = didPublish
    }
}

public actor ComposerController {
    public let scope: ComposerScope
    private let deps: ComposerDependencies

    /// Held between a `nudge` and the student's explicit follow-up: the
    /// prepared (token + signed envelope) post and its content-bound pass.
    private var held: (prepared: PreparedPost, pass: String)?
    /// The cooldown ticket is CONTENT-BOUND server-side: keep the text it was
    /// issued for, so an edited draft re-checks fresh.
    private var cooldown: (ticket: String, retryAt: Int64, body: String, rating: Int?)?
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
        let heldTicket = heldCooldown(body: body, rating: rating)
        return await runCheck(body: body, rating: rating, ticket: heldTicket?.ticket)
    }

    /// "Share as written" from the nudge preflight: an explicit publish of
    /// exactly the prepared post the check saw.
    public func shareAsWritten(body: String, rating: Int?) async -> ComposerOutcome {
        guard let held else { return await runCheck(body: body, rating: rating, ticket: nil) }
        do {
            return try await finishPublish(prepared: held.prepared, pass: held.pass)
        } catch let error as APIError where error.code.hasPrefix("token_") || error.code.hasPrefix("pass_") {
            // A stale token/pass (rare — later) just re-runs the check.
            self.held = nil
            return await runCheck(body: body, rating: rating, ticket: nil)
        } catch {
            return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: SubmitErrorCopy.describe(error)))
        }
    }

    /// Leave the nudge preflight to add more context, keeping the draft.
    public func backToEditing() -> ComposerOutcome {
        held = nil
        return ComposerOutcome(status: .editing, notice: nil)
    }

    // MARK: Internals

    private func runCheck(body: String, rating: Int?, ticket: String?) async -> ComposerOutcome {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scope.draftKey.isEmpty else { return ComposerOutcome(status: .editing, notice: nil) }
        // Persist the draft BEFORE any network call; say so honestly if it failed.
        var persisted = true
        do { try deps.saveDraft(scope.draftKey, body, rating) } catch { persisted = false }
        held = nil
        let ratingToSend = scope.isDish ? rating : nil
        do {
            let prepared: PreparedPost
            do {
                prepared = try await deps.prepare(scope.target, trimmed, ratingToSend)
            } catch PublishError.postControlsRestoreNeeded {
                return ComposerOutcome(status: .postControlsRestoreNeeded, notice: ComposerNotice(tone: .warn, text: ModerationCopy.restoreNeeded), draftPersisted: persisted)
            }
            let check = try await deps.check(prepared, ticket)
            lastChecked = (trimmed, rating)
            switch ModerationDecision(check) {
            case .publishable(let pass):
                var outcome = try await finishPublish(prepared: prepared, pass: pass)
                outcome.draftPersisted = persisted
                return outcome
            case .nudge(let pass, let reasons):
                held = (prepared, pass)
                return ComposerOutcome(status: .nudge(reasons: reasons), notice: nil, draftPersisted: persisted)
            case .cooldown(let cooldownTicket, let retryAt, let reasons):
                cooldown = (cooldownTicket, retryAt, trimmed, rating)
                return ComposerOutcome(status: .cooldown(retryAt: retryAt, reasons: reasons), notice: nil, draftPersisted: persisted)
            case .editRequired(let reasons):
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.editRequired, reasons: reasons), draftPersisted: persisted)
            case .outOfScope(let reasons):
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .warn, text: ModerationCopy.outOfScope, reasons: reasons, suggestKeepPrivate: true, suggestSchoolReport: true), draftPersisted: persisted)
            case .blocked:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: ModerationCopy.blocked), draftPersisted: persisted)
            case .unavailable:
                return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: persisted ? ModerationCopy.failedClosed : ModerationCopy.failedClosedUnsaved), draftPersisted: persisted)
            }
        } catch {
            return ComposerOutcome(status: .editing, notice: ComposerNotice(tone: .danger, text: SubmitErrorCopy.describe(error)), draftPersisted: persisted)
        }
    }

    private func finishPublish(prepared: PreparedPost, pass: String) async throws -> ComposerOutcome {
        let result = try await deps.publish(prepared, pass)
        held = nil
        cooldown = nil
        // The post is public from here on; its control key derives from the root on this device.
        try? deps.clearDraft(scope.draftKey)
        await deps.didPublish()
        return ComposerOutcome(status: .published(experienceId: result.experienceId), notice: nil)
    }
}
