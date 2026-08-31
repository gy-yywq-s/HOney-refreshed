//
//  PortalModels.swift
//  HOney — wire types for the direct-to-school portal (Access only).
//  Band 2/4, no SwiftUI. All snake_case; decoded via PortalCoding.decoder.
//

import Foundation

// MARK: - Auth / identity

struct PortalLoginRequest: Encodable, Sendable {
    let username: String
    let password: String
}

/// Login response is quirky: the token may appear at the top level or inside
/// `data`, and `status`/`code` vary. Parsed leniently.
struct PortalLoginResponse: Decodable, Sendable {
    let status: Int?
    let code: Int?
    let message: String?
    let token: String?

    private struct DataBlock: Decodable {
        let token: String?
        let accessToken: String?
    }

    private enum CodingKeys: String, CodingKey {
        case status, code, message, token, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decode(Int.self, forKey: .status)
        code = try? container.decode(Int.self, forKey: .code)
        message = try? container.decode(String.self, forKey: .message)
        let topToken = try? container.decode(String.self, forKey: .token)
        let block = try? container.decode(DataBlock.self, forKey: .data)
        token = [topToken, block?.token, block?.accessToken]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }
}

/// `GET /api/public/user_info` → identity + token expiry.
struct PortalUserInfoResponse: Decodable, Sendable {
    let status: Int?
    let data: PortalUserInfo?
}

struct PortalUserInfo: Decodable, Sendable {
    let id: Int
    let name: String?
    let type: Int?
    let exp: Double?   // Unix seconds
}

// MARK: - Access: doors

/// `GET /api/user/get_door_list` — the documented quirk: success is `status == 1`
/// and the doors live in `message` as an array of `{ key, value }`.
struct PortalDoor: Decodable, Sendable, Identifiable, Hashable {
    let key: String
    let value: String
    var id: String { key }
    var displayName: String { value.isEmpty ? key : value }
}

struct PortalDoorListResponse: Decodable, Sendable {
    let status: Int
    let message: [PortalDoor]

    var isSuccess: Bool { status == 1 }
}

// MARK: - Access: permits

struct PortalPermitRow: Decodable, Sendable, Identifiable, Hashable {
    let recordId: Int
    let staffName: String?
    let status: Int
    let statusName: String?
    let note: String?
    let flag: Int?
    let startTime: String?
    let endTime: String?
    let createTime: String?

    var id: Int { recordId }

    /// Permit status 1 == approved ("通过") in the portal's numeric mapping.
    var isApproved: Bool { status == 1 }
}

struct PortalPermitListData: Decodable, Sendable {
    let rows: [PortalPermitRow]
    let total: Int?
}

struct PortalPermitListResponse: Decodable, Sendable {
    let status: Int
    let data: PortalPermitListData?
}

// MARK: - Access: actions

/// `POST /api/exit/add_record` body.
struct PortalApplyPermitRequest: Encodable, Sendable {
    let startTime: String
    let endTime: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case note
    }
}

/// `POST /api/exit/update_door_flag` body. Note `indexcode` is all-lowercase and
/// equals `door_id` (the door's `key`). Commuter route uses `record_id == -2`.
struct PortalOpenDoorRequest: Encodable, Sendable {
    let recordId: Int
    let status: Int
    let doorId: String
    let indexcode: String

    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case status
        case doorId = "door_id"
        case indexcode
    }

    init(recordId: Int, doorKey: String, status: Int = 1) {
        self.recordId = recordId
        self.status = status
        self.doorId = doorKey
        self.indexcode = doorKey
    }
}

/// Conventional portal action envelope. Open succeeds when `status == 0` or
/// `code == 200`.
struct PortalActionResponse: Decodable, Sendable {
    let status: Int?
    let code: Int?
    let message: String?

    var isSuccess: Bool { status == 0 || code == 200 }
    var displayMessage: String { (message?.isEmpty == false ? message : nil) ?? "" }
}

// MARK: - Access domain (client-side)

/// Which route the user is opening the gate through.
enum AccessRoute: Equatable, Sendable {
    case commuter                 // day student — record_id == -2
    case permit(recordId: Int)    // approved exit permit

    var recordId: Int {
        switch self {
        case .commuter: return -2
        case .permit(let recordId): return recordId
        }
    }
}

/// Front vs Back gate; mapped onto the portal's door list by keyword.
enum GateChoice: String, CaseIterable, Identifiable, Sendable {
    case front
    case back
    var id: String { rawValue }
    var title: String { self == .front ? "Front Gate" : "Back Gate" }
    var systemImage: String { self == .front ? "building.columns" : "arrow.uturn.backward" }
}

/// Pure keyword mapping from a Front/Back choice onto the portal door list.
/// Kept side-effect free for unit testing.
enum DoorMatcher {
    static func match(_ choice: GateChoice, in doors: [PortalDoor]) -> PortalDoor? {
        guard !doors.isEmpty else { return nil }

        let needles: [String]
        switch choice {
        case .front: needles = ["front", "main", "大门", "正门", "前门"]
        case .back:  needles = ["back", "后门"]
        }

        if let match = doors.first(where: { door in
            let haystack = "\(door.key) \(door.value)".lowercased()
            return needles.contains { haystack.contains($0.lowercased()) }
        }) {
            return match
        }

        // Deterministic fallback when the portal uses opaque labels.
        switch choice {
        case .front: return doors.first
        case .back:  return doors.dropFirst().first ?? doors.first
        }
    }
}
