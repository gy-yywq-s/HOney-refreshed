// Composer presentation state (spec §15): resolves the target, hydrates the
// draft, debounces autosave, and maps ComposerController outcomes into
// what the editor shows. The v2 publication sequence itself lives in
// HOneyCore (ComposerController over PublishClient): post controls, blind
// eligibility, the signed envelope, check, publish — none of it here.
//
// Every claim the editor makes about storage is backed by a verified write
// (review 11d42e3 §3.3): "Saved" only after the bytes are on the device,
// the cooldown sheet only says the words were kept when the note really
// was, and "kept private" says whether the text went through the check.

import Foundation
import Observation
import HOneyCore

@MainActor
@Observable
final class ComposerViewModel {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    private let env: AppEnvironment
    let target: ComposeTarget

    private(set) var scope: ComposerScope?
    private(set) var label = ""
    private(set) var detail: String?
    private(set) var loading = true
    private(set) var loadError: String?
    /// The entity is no longer listed; a survivor of the same name may exist.
    private(set) var unlisted: Bool = false
    private(set) var survivor: EntityRef?
    private(set) var note: PrivateNote?

    var body = "" {
        didSet { if body != oldValue { scheduleAutosave() } }
    }
    var rating: Int? {
        didSet { if rating != oldValue { scheduleAutosave() } }
    }
    private(set) var status: ComposerStatus = .editing
    private(set) var notice: ComposerNotice?
    private(set) var saveState: SaveState = .idle
    /// The last check ran without a durable draft (shown above the editor).
    private(set) var draftUnsavedBeforeCheck = false
    private(set) var keptPrivate = false
    /// The kept note went through the check path first (copy differs).
    private(set) var keptAfterCheck = false
    private(set) var privateSaveError: String?
    private(set) var busySavingNote = false
    /// The cooldown outcome could not keep the note on this iPhone.
    private(set) var cooldownSaveFailed = false

    private var controller: ComposerController?
    private var autosaveTask: Task<Void, Never>?
    private var keptForTicket: String?

    init(env: AppEnvironment, target: ComposeTarget) {
        self.env = env
        self.target = target
    }

    var isDish: Bool { scope?.isDish ?? false }
    var checking: Bool { status == .checking }
    var isNote: Bool { if case .note = target { return true }; return false }

    /// A kept note still in its pause: the same words cannot be shared before
    /// the time is up; edited words check afresh.
    func pauseRemaining(now: Date = HOneyClock.now()) async -> Int64? {
        guard let cooldown = note?.cooldown, let controller,
              await controller.heldCooldown(body: body, rating: rating) != nil else { return nil }
        let remaining = cooldown.until - now.epochMillis
        return remaining > 0 ? remaining : nil
    }

    var canAct: Bool { !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !checking }

    // MARK: Load

    func load() async {
        loading = true
        loadError = nil
        do {
            var lessonId: String?
            var lessonDate: String?
            var entityKey: String?
            if case .note(let id) = target {
                guard let n = try await env.notes.note(id: id) else {
                    loadError = "This note is no longer on this iPhone."
                    loading = false
                    return
                }
                note = n
                lessonId = n.target.lessonId
                lessonDate = n.target.lessonDate
                entityKey = n.target.entityKey
                if n.target.lessonId == nil, n.target.entityKey == nil {
                    label = n.target.label
                    scope = nil
                }
            } else if case .lesson(let id, let date) = target {
                lessonId = id
                lessonDate = date
            } else if case .entity(let key) = target {
                entityKey = key
            }

            if let lessonId {
                let lessons: [Lesson]
                if let lessonDate {
                    lessons = try await env.timetable.day(lessonDate).lessons
                } else {
                    lessons = try await env.timetable.history(HistoryParams(limit: 200, order: .desc)).lessons
                }
                let lesson = lessons.first { $0.id == lessonId }
                label = lesson?.title ?? "A lesson from your history"
                detail = lesson.map { l in
                    [Formatters.shortDate(l.startsAt), Formatters.timeRange(l.startsAt, l.endsAt), l.teacherName ?? "", DisplayNames.roomLabel(l.roomName)]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                }
                scope = ComposerScope(lessonId: lessonId, isDish: false)
            } else if let entityKey {
                let registry = try await env.timetable.entities()
                let type = EntityType(rawValue: String(entityKey.prefix { $0 != ":" }))
                if let entity = registry.entities.first(where: { $0.entityKey == entityKey }) {
                    label = entity.name
                    detail = kindLabel(entity.type)
                    scope = ComposerScope(entityKey: entityKey, isDish: entity.type == .dish)
                } else {
                    unlisted = true
                    let names = try? await NameMaps.load(env)
                    let id = String(entityKey.drop { $0 != ":" }.dropFirst())
                    let known: String? = {
                        switch type {
                        case .teacher: return names?.teacher[id]
                        case .room: return names?.room[id]
                        case .course: return names?.course[id]
                        default: return nil
                        }
                    }()
                    if let known {
                        survivor = registry.entities.first { $0.type == type && $0.name == known }
                    }
                    label = known ?? ""
                }
            }

            if let scope {
                let controller = makeController(scope)
                self.controller = controller
                if let note {
                    body = note.body
                    rating = note.rating
                    if let cooldown = note.cooldown {
                        await controller.seedCooldown(ticket: cooldown.ticket, retryAt: cooldown.until, body: note.body, rating: note.rating)
                    }
                } else if let draft = env.drafts.get(scope.draftKey) {
                    body = draft.body
                    rating = draft.rating
                    saveState = .saved
                }
            }
        } catch {
            loadError = APIErrorCopy.describe(error)
        }
        loading = false
    }

    private func kindLabel(_ type: EntityType) -> String {
        switch type {
        case .room: return "Place"
        case .dish: return "Food"
        case .course: return "Course"
        default: return "Teacher"
        }
    }

    private func makeController(_ scope: ComposerScope) -> ComposerController {
        let publish = env.publish
        let drafts = env.drafts
        let feedStore = env.feedStore
        let timetable = env.timetable
        let account = env.scope?.honeyId ?? ""
        return ComposerController(scope: scope, deps: ComposerDependencies(
            prepare: { target, body, rating in try await publish.preparePost(account: account, target: target, body: body, rating: rating) },
            check: { prepared, ticket in try await publish.check(prepared, cooldownTicket: ticket) },
            publish: { prepared, pass in try await publish.publish(prepared, pass: pass) },
            saveDraft: { key, body, rating in try drafts.save(targetKey: key, body: body, rating: rating) },
            clearDraft: { key in try drafts.clear(key) },
            didPublish: {
                await feedStore.invalidateAll()
                await timetable.invalidateEntities()
            }
        ))
    }

    // MARK: Draft

    private func scheduleAutosave() {
        guard !loading, let controller else { return }
        autosaveTask?.cancel()
        saveState = .saving
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            let ok = await controller.autosave(body: body, rating: rating)
            guard !Task.isCancelled else { return }
            if body.isEmpty, rating == nil {
                saveState = .idle
            } else {
                saveState = ok ? .saved : .failed(ModerationCopy.draftNotSaved)
            }
        }
    }

    // MARK: Actions

    func continueToShare() async {
        guard let controller, canAct else { return }
        autosaveTask?.cancel()
        status = .checking
        notice = nil
        let outcome = await controller.continueToShare(body: body, rating: rating)
        await apply(outcome)
    }

    func shareAsWritten() async {
        guard let controller else { return }
        status = .checking
        let outcome = await controller.shareAsWritten(body: body, rating: rating)
        await apply(outcome)
    }

    func addContext() async {
        guard let controller else { return }
        let outcome = await controller.backToEditing()
        await apply(outcome)
    }

    /// Back to the editor after the post-controls notice (the draft is still here).
    func backToEditing() {
        status = .editing
    }

    private func apply(_ outcome: ComposerOutcome) async {
        status = outcome.status
        notice = outcome.notice
        draftUnsavedBeforeCheck = !outcome.draftPersisted
        if !outcome.draftPersisted { saveState = .failed(ModerationCopy.draftNotSaved) }
        if case .cooldown(let retryAt, _) = outcome.status, let controller,
           let held = await controller.heldCooldown(body: body, rating: rating), keptForTicket != held.ticket {
            // A cooling-off outcome keeps the words private on this iPhone at
            // once — and says so only when that really happened.
            keptForTicket = held.ticket
            cooldownSaveFailed = !(await saveNote(cooldown: .some(NoteCooldown(until: retryAt, ticket: held.ticket)), quiet: true))
        }
    }

    /// "Keep private": the note travels with its cooling state, if any.
    func keepPrivate() async {
        guard !busySavingNote else { return }
        var cooldown: NoteCooldown?? = .some(nil)
        if case .cooldown(let retryAt, _) = status, let controller, let held = await controller.heldCooldown(body: body, rating: rating) {
            cooldown = .some(NoteCooldown(until: retryAt, ticket: held.ticket))
        } else if let existing = note?.cooldown, let controller, await controller.heldCooldown(body: body, rating: rating) != nil {
            cooldown = .some(existing)
        }
        keptAfterCheck = await controller?.wasChecked(body: body, rating: rating) ?? false
        if await saveNote(cooldown: cooldown, quiet: false) {
            cooldownSaveFailed = false
            keptPrivate = true
        }
    }

    @discardableResult
    private func saveNote(cooldown: NoteCooldown??, quiet: Bool) async -> Bool {
        busySavingNote = true
        privateSaveError = nil
        defer { busySavingNote = false }
        var targetInfo = PrivateNoteTarget(label: [label, detail ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
        if let lessonId = scope?.lessonId {
            targetInfo.lessonId = lessonId
            if case .lesson(_, let date) = target { targetInfo.lessonDate = date } else { targetInfo.lessonDate = note?.target.lessonDate }
        }
        if let entityKey = scope?.entityKey { targetInfo.entityKey = entityKey }
        if isDish { targetInfo.entityType = "dish" }
        do {
            let saved = try await env.notes.save(id: note?.id, body: body, rating: isDish ? rating : nil, target: targetInfo, cooldown: cooldown)
            note = saved
            if let scope { try? env.drafts.clear(scope.draftKey) }
            return true
        } catch {
            privateSaveError = "Could not save the note on this iPhone."
            return false
        }
    }
}
