// Name resolution (Web: lib/entityNames.ts): Community sends canonical ids
// only — `name` is null on the wire — so every screen joins names from
// Core's directory + entity registry here. Nothing else names a post.

import Foundation
import HOneyCore

struct NameMaps {
    var teacher: [String: String] = [:]
    var course: [String: String] = [:]
    var room: [String: String] = [:]
    /// entity_key → registry name (covers dishes and admin-imported entries).
    var entity: [String: String] = [:]
    var entities: [EntityRef] = []
    var loaded = false

    init() {}

    init(directory: DirectoryResponse?, entities: EntitiesResponse?) {
        if let directory {
            teacher = Dictionary(directory.teachers.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            course = Dictionary(directory.courses.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            room = Dictionary(directory.rooms.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        }
        if let entities {
            self.entities = entities.entities
            entity = Dictionary(entities.entities.map { ($0.entityKey, $0.name) }, uniquingKeysWith: { a, _ in a })
        }
        loaded = directory != nil && entities != nil
    }

    /// The display name of a post reference, or nil when nothing on this device knows it.
    func name(_ ref: EntityRefV2) -> String? {
        if let n = ref.name, !n.isEmpty { return n }
        switch ref.type {
        case .teacher: return teacher[ref.id] ?? entity[ref.entityKey]
        case .course: return course[ref.id] ?? entity[ref.entityKey]
        case .room: return room[ref.id] ?? entity[ref.entityKey]
        case .dish: return entity[ref.entityKey]
        case .lesson, .unknown: return nil
        }
    }

    func name(type: String, id: String) -> String? {
        name(EntityRefV2(type: EntitySummaryType(rawValue: type), id: id))
    }

    /// The resolver the display helpers take.
    var resolver: NameResolver { { [self] ref in self.name(ref) } }

    /// "Lesson · course · teacher" for an own post about a lesson; else the entity's name.
    func targetLabel(_ post: MineExperience) -> String {
        if post.primaryEntity.type == "lesson" {
            var parts = ["Lesson"]
            if let c = post.contexts.first(where: { $0.type == "course" }), let n = c.name ?? name(type: c.type, id: c.id) { parts.append(n) }
            if let t = post.contexts.first(where: { $0.type == "teacher" }), let n = t.name ?? name(type: t.type, id: t.id) { parts.append(n) }
            return parts.joined(separator: " · ")
        }
        return post.primaryEntity.name ?? name(type: post.primaryEntity.type, id: post.primaryEntity.id) ?? post.primaryEntity.type.capitalized
    }

    @MainActor
    static func load(_ env: AppEnvironment, reload: Bool = false) async throws -> NameMaps {
        let repo = env.timetable
        async let directory = repo.directory(reload: reload)
        async let entities = repo.entities(reload: reload)
        return NameMaps(directory: try await directory, entities: try await entities)
    }
}
