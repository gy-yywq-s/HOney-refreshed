//
//  ComposeExperienceViewModel.swift
//  HOney — the composer state machine (Band 1, no SwiftUI).
//
//  Ports the web useComposer semantics (audit §3.3 real nudge, §3.4 draft
//  preservation). The publication flow is eligibility → check → publish:
//  `check` never persists the draft and never publishes; publication happens
//  ONLY on an explicit user action. A `nudge` lane surfaces a preflight choice
//  (add context / publish as is / keep private) — it does not auto-publish.
//  Every non-publish outcome leaves the draft intact in the editor.
//

import Foundation
import Observation

/// The slice of HOneyAPI the composer needs — a protocol so tests can stub it.
protocol ExperiencePublishing: Sendable {
    func experienceEligibility(lessonId: String?, entityKey: String?) async throws -> ExperienceEligibilityResponse
    func checkExperience(_ request: CheckExperienceRequest) async throws -> CheckExperienceResponse
    func publishExperience(_ request: PublishExperienceRequest) async throws -> PublishExperienceResponse
}

extension HOneyAPI: ExperiencePublishing {}

/// What the composer is writing about: one of the user's own lessons, or a
/// registry entity (teacher / place / dish).
struct ComposerTarget: Sendable, Equatable {
    let label: String
    var detail: String?
    var lessonId: String?
    var entityKey: String?
    var isDish: Bool = false

    /// Draft-slot key: "lesson:<id>" or the entity_key.
    var targetKey: String {
        if let lessonId { return "lesson:\(lessonId)" }
        return entityKey ?? ""
    }

    /// The label stored on a private note ("<label> · <detail>").
    var noteLabel: String {
        [label, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Inline banner shown above the editor for outcomes that keep the draft.
struct ComposerNotice: Sendable, Equatable {
    enum Tone: Sendable {
        case warn
        case danger
    }

    let tone: Tone
    let text: String
    var reasons: [String] = []
    var suggestKeepPrivate: Bool = false
}

enum ComposerStatus: Sendable, Equatable {
    case editing
    case checking
    case nudge(reasons: [String])
    /// `retryAt` is epoch milliseconds.
    case cooldown(retryAt: Int, reasons: [String])
    case published(ownershipKey: String, experienceId: String)
    case publishedKeyRecovery(ownershipKey: String, experienceId: String, journalSaved: Bool)
}

@MainActor
@Observable
final class ComposeExperienceViewModel {
    // Web-identical notice copy (useComposer.ts).
    static let editRequiredCopy = "This needs a small rephrase before it can be public — say it more directly, as your own experience. Nothing was kept, so you can still share here later."
    static let outOfScopeCopy = "This reads as something for the school to handle directly, not a public feed. You can keep it as a private note instead."
    static let blockedCopy = "This can't be published under the community rules. Nothing was stored — your draft is still here if you want to reshape it."
    static let failedClosedCopy = "The safety check couldn't run just now, and nothing publishes unchecked. Your draft is safe — please try again in a moment."

    let target: ComposerTarget?

    var body = "" { didSet { autosave() } }
    var rating: Int? { didSet { autosave() } }
    private(set) var status: ComposerStatus = .editing
    private(set) var notice: ComposerNotice?
    /// Set after "Keep private" succeeds; the view shows the kept-private state.
    private(set) var savedNote: PrivateNote?
    private(set) var keepPrivateError: String?
    private(set) var isSavingNote = false
    private(set) var keyRecoveryError: String?
    private(set) var isSavingRecoveryKey = false

    private let api: any ExperiencePublishing
    private let drafts: ComposerDraftStore
    private let notes: PrivateNoteStore
    private let ownershipKeys: any OwnershipKeyStoring
    private let recoveryStore: PublishedKeyRecoveryStore

    /// When seeded from an existing private note, "Keep private" updates it.
    private let seedNote: PrivateNote?
    private var noteId: String?
    private var hydrated = false

    /// Held between a `nudge` and the user's explicit follow-up action.
    private var heldPass: HeldPass?
    private var cooldownTicket: String?

    /// The most recent fire-and-forget autosave, awaited before any explicit
    /// save/clear so an in-flight autosave can never resurrect a cleared slot.
    private var pendingAutosave: Task<Void, Never>?

    private struct HeldPass {
        let eligibilityToken: String
        let pass: String
    }

    init(
        target: ComposerTarget?,
        seedNote: PrivateNote? = nil,
        api: any ExperiencePublishing,
        drafts: ComposerDraftStore,
        notes: PrivateNoteStore,
        ownershipKeys: any OwnershipKeyStoring,
        recoveryStore: PublishedKeyRecoveryStore
    ) {
        self.target = target
        self.seedNote = seedNote
        self.noteId = seedNote?.id
        self.api = api
        self.drafts = drafts
        self.notes = notes
        self.ownershipKeys = ownershipKeys
        self.recoveryStore = recoveryStore
    }

    convenience init(services: AppServices, target: ComposerTarget?, seedNote: PrivateNote? = nil) {
        self.init(
            target: target,
            seedNote: seedNote,
            api: services.honeyAPI,
            drafts: services.composerDraftStore,
            notes: services.privateNoteStore,
            ownershipKeys: services.ownershipKeyStore,
            recoveryStore: services.publishedKeyRecoveryStore
        )
    }

    var canAct: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && status != .checking
    }

    /// Restore any saved draft for this target (audit §3.4). A seeding private
    /// note wins over the draft slot (the web noteId flow).
    func hydrate() async {
        defer { hydrated = true }
        guard !hydrated else { return }
        if let recovery = try? await recoveryStore.record(forTarget: target?.targetKey ?? ""),
           recovery.targetKey == target?.targetKey {
            body = recovery.body
            rating = recovery.rating
            status = .publishedKeyRecovery(
                ownershipKey: recovery.ownershipKey,
                experienceId: recovery.experienceId,
                journalSaved: true
            )
            keyRecoveryError = "This published post still needs its post-control key saved on this iPhone."
            return
        }
        if let seedNote {
            body = seedNote.body
            rating = seedNote.rating
            return
        }
        guard let key = target?.targetKey, !key.isEmpty else { return }
        if let saved = await drafts.get(key) {
            body = saved.body
            rating = saved.rating
        }
    }

    func publish() async {
        await runCheck(ticket: nil)
    }

    /// Cooldown expiry: re-check the SAME words with the held ticket.
    func recheckAfterCooldown() async {
        await runCheck(ticket: cooldownTicket)
    }

    /// "Publish as is" from the nudge preflight: an explicit publish action
    /// using the held eligibility token + content-bound pass.
    func publishAsIs() async {
        guard let held = heldPass else {
            await runCheck(ticket: nil)
            return
        }
        status = .checking
        do {
            try await finishPublish(eligibilityToken: held.eligibilityToken, pass: held.pass)
        } catch {
            // A stale token/pass (rare — 10 min+ later) silently re-runs the check.
            if let code = (error as? HOneyAPIError)?.apiErrorCode,
               code.contains("eligibility_") || code.contains("pass_") {
                heldPass = nil
                await runCheck(ticket: nil)
                return
            }
            status = .editing
            notice = ComposerNotice(tone: .danger, text: ExperienceSubmitCopy.describe(error))
        }
    }

    /// Leave the nudge preflight to add more context, keeping the draft. The
    /// held pass is dropped — edited words need a fresh check.
    func backToEditing() {
        heldPass = nil
        status = .editing
    }

    /// "Keep private": save a device-only note. NEVER touches the network, and
    /// is always available while editing — the suggested action for out_of_scope.
    func keepPrivate() async {
        guard !isSavingNote else { return }
        isSavingNote = true
        keepPrivateError = nil
        defer { isSavingNote = false }
        do {
            let note = try await notes.save(
                id: noteId,
                body: body,
                rating: target?.isDish == true ? rating : nil,
                target: PrivateNoteTarget(
                    label: target.map(\.noteLabel) ?? "No target",
                    lessonId: target?.lessonId,
                    entityKey: target?.entityKey,
                    entityType: target?.isDish == true ? "dish" : nil
                )
            )
            noteId = note.id
            savedNote = note
        } catch {
            keepPrivateError = "Could not save the note on this device."
        }
    }

    func retryOwnershipKeyStorage() async {
        guard !isSavingRecoveryKey,
              case .publishedKeyRecovery(let ownershipKey, let experienceId, _) = status else { return }
        isSavingRecoveryKey = true
        defer { isSavingRecoveryKey = false }
        keyRecoveryError = nil
        do {
            try await ownershipKeys.add(experienceId: experienceId, ownershipKey: ownershipKey)
            guard try await ownershipKeys.ownershipKey(for: experienceId) == ownershipKey else {
                throw OwnershipKeyStoreError.verificationFailed
            }
            if let key = target?.targetKey, !key.isEmpty {
                await pendingAutosave?.value
                try await drafts.clear(key)
            }
            try await recoveryStore.clear(experienceId: experienceId)
            status = .published(ownershipKey: ownershipKey, experienceId: experienceId)
        } catch {
            keyRecoveryError = "The post is public, but its post-control key still could not be saved. Copy the key below and try saving again."
        }
    }

    // MARK: - eligibility → check → (publish | nudge | cooldown | keep-draft)

    private func runCheck(ticket: String?) async {
        guard let target, !target.targetKey.isEmpty else { return }
        // Persist the draft BEFORE any network call — nothing below can lose it.
        await pendingAutosave?.value
        await drafts.save(targetKey: target.targetKey, body: body, rating: rating)
        status = .checking
        notice = nil
        heldPass = nil
        do {
            let eligibility = try await api.experienceEligibility(
                lessonId: target.lessonId,
                entityKey: target.entityKey
            )
            let check = try await api.checkExperience(CheckExperienceRequest(
                lessonId: target.lessonId,
                entityKey: target.entityKey,
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: target.isDish ? rating : nil,
                cooldownTicket: ticket
            ))
            switch check.lane {
            case .publish:
                guard let pass = check.pass else { return failClosed() }
                try await finishPublish(eligibilityToken: eligibility.eligibilityToken, pass: pass)
            case .nudge:
                guard let pass = check.pass else { return failClosed() }
                heldPass = HeldPass(eligibilityToken: eligibility.eligibilityToken, pass: pass)
                status = .nudge(reasons: check.reasons)
            case .cooldown:
                guard let cooldown = check.cooldown else { return failClosed() }
                cooldownTicket = cooldown.ticket
                status = .cooldown(retryAt: cooldown.retryAt, reasons: check.reasons)
            case .editRequired:
                status = .editing
                notice = ComposerNotice(tone: .warn, text: Self.editRequiredCopy, reasons: check.reasons)
            case .outOfScope:
                status = .editing
                notice = ComposerNotice(
                    tone: .warn,
                    text: Self.outOfScopeCopy,
                    reasons: check.reasons,
                    suggestKeepPrivate: true
                )
            case .blockedSerious:
                status = .editing
                notice = ComposerNotice(tone: .danger, text: Self.blockedCopy)
            case .failedClosed:
                status = .editing
                notice = ComposerNotice(tone: .danger, text: Self.failedClosedCopy)
            }
        } catch {
            status = .editing
            notice = ComposerNotice(tone: .danger, text: ExperienceSubmitCopy.describe(error))
        }
    }

    /// The single public write. On success the ownership key is stored (the
    /// only control over the anonymous post) and the draft slot is cleared.
    private func finishPublish(eligibilityToken: String, pass: String) async throws {
        let result = try await api.publishExperience(PublishExperienceRequest(
            eligibilityToken: eligibilityToken,
            pass: pass,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: target?.isDish == true ? rating : nil
        ))
        let recoveryRecord = PublishedKeyRecoveryRecord(
            experienceId: result.experienceId,
            ownershipKey: result.ownershipKey,
            targetKey: target?.targetKey ?? "",
            body: body,
            rating: rating,
            createdAt: .now
        )
        let journalSaved = (try? await recoveryStore.save(recoveryRecord)) != nil
        do {
            try await ownershipKeys.add(experienceId: result.experienceId, ownershipKey: result.ownershipKey)
            guard try await ownershipKeys.ownershipKey(for: result.experienceId) == result.ownershipKey else {
                throw OwnershipKeyStoreError.verificationFailed
            }
            if let key = target?.targetKey, !key.isEmpty {
                await pendingAutosave?.value
                try await drafts.clear(key)
            }
            try? await recoveryStore.clear(experienceId: result.experienceId)
            status = .published(ownershipKey: result.ownershipKey, experienceId: result.experienceId)
        } catch {
            // Publication already succeeded. Keep the durable draft and expose
            // the returned key until storage is verified; never republish.
            status = .publishedKeyRecovery(
                ownershipKey: result.ownershipKey,
                experienceId: result.experienceId,
                journalSaved: journalSaved
            )
            keyRecoveryError = journalSaved
                ? "The post is public. Its recovery key is protected locally, but it still needs to be saved to the post-control key store."
                : "The post is public, but neither key storage nor the protected recovery journal succeeded. Copy the key now."
        }
    }

    /// A publish/nudge response missing its pass — treat as fail-closed.
    private func failClosed() {
        status = .editing
        notice = ComposerNotice(tone: .danger, text: Self.failedClosedCopy)
    }

    /// Autosave keeps the durable draft current with the editor (web parity).
    private func autosave() {
        guard hydrated, let key = target?.targetKey, !key.isEmpty else { return }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rating == nil { return }
        let body = self.body
        let rating = self.rating
        let drafts = self.drafts
        pendingAutosave = Task { await drafts.save(targetKey: key, body: body, rating: rating) }
    }
}
