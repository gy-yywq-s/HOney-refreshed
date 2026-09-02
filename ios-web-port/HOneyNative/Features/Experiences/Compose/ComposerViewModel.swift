// Composer presentation state (spec §15): resolves the target, hydrates the
// draft, debounces autosave, and maps ComposerController outcomes into
// what the editor shows. The publication sequence itself lives in
// HOneyCore.ComposerController; the identity-free publish goes through the
// dedicated PublicationAPIClient.

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
    private(set) var keptPrivate = false
    private(set) var privateSaveError: String?
    private(set) var busySavingNote = false

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
                    // A note with no publishable target (should not happen): edit only.
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
                label = lesson?.subjectName ?? "A lesson from your history"
                detail = lesson.map { l in
                    [Formatters.shortDate(l.startsAt), Formatters.timeRange(l.startsAt, l.endsAt), l.teacherName ?? "", DisplayNames.roomLabel(l.roomName)]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                }
                scope = ComposerScope(lessonId: lessonId, isDish: false)
            } else if let entityKey {
                let registry = try await env.timetable.entities()
                let type = EntityType(rawValue: String(entityKey.prefix { $0 != ":" }))
                if let entity = registry.entities.first(where: { $0.entityKey == entityKey }) {
                    label = DisplayNames.entityTitle(type: entity.type, name: entity.name)
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
        let api = env.api
        let publication = env.publication
        let keys = env.keys
        let drafts = env.drafts
        let feedStore = env.feedStore
        let timetable = env.timetable
        return ComposerController(scope: scope, deps: ComposerDependencies(
            eligibility: { try await api.experienceEligibility($0) },
            check: { try await api.checkExperience($0) },
            publish: { try await publication.publish($0) },
            storeKey: { id, key in try keys.add(key: key, experienceId: id) },
            saveDraft: { key, body, rating in drafts.save(targetKey: key, body: body, rating: rating) },
            clearDraft: { key in drafts.clear(key) },
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
            await controller.autosave(body: body, rating: rating)
            if !Task.isCancelled { saveState = body.isEmpty && rating == nil ? .idle : .saved }
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

    func retryStoringKey() async {
        guard let controller else { return }
        await apply(await controller.retryStoringKey())
    }

    private func apply(_ outcome: ComposerOutcome) async {
        status = outcome.status
        notice = outcome.notice
        if case .cooldown(let retryAt, _) = outcome.status, let controller,
           let held = await controller.heldCooldown(body: body, rating: rating), keptForTicket != held.ticket {
            // A cooling-off outcome keeps the words private on this iPhone at once.
            keptForTicket = held.ticket
            _ = await saveNote(cooldown: .some(NoteCooldown(until: retryAt, ticket: held.ticket)), quiet: true)
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
        if await saveNote(cooldown: cooldown, quiet: false) { keptPrivate = true }
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
            if let scope { env.drafts.clear(scope.draftKey) }
            return true
        } catch {
            privateSaveError = "Could not save the note on this iPhone."
            return false
        }
    }
}
