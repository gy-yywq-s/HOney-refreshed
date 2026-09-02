// Name resolution (Web: pages/experiences/shared.tsx useNames): directory
// ids + the entity registry → display names, for Mine rows and entity pages.

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

    /// "Lesson · course · teacher" for an own post about a lesson; else the registry name.
    func targetLabel(_ exp: MyExperience) -> String {
        if exp.entityKey.hasPrefix("lesson:") {
            var parts = ["Lesson"]
            if let c = exp.ctxCourseId, let name = course[c] { parts.append(DisplayNames.parseCourseName(name).title) }
            if let t = exp.ctxTeacherId, let name = teacher[t] { parts.append(name) }
            return parts.joined(separator: " · ")
        }
        if let name = entity[exp.entityKey] {
            let type = EntityType(rawValue: String(exp.entityKey.prefix { $0 != ":" }))
            return DisplayNames.entityTitle(type: type, name: name)
        }
        return exp.entityKey
    }

    @MainActor
    static func load(_ env: AppEnvironment, reload: Bool = false) async throws -> NameMaps {
        let repo = env.timetable
        async let directory = repo.directory(reload: reload)
        async let entities = repo.entities(reload: reload)
        return NameMaps(directory: try await directory, entities: try await entities)
    }
}
