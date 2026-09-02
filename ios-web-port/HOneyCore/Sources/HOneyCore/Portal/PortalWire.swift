// Wire types for the direct-to-school portal (Access only). Mirrors
// packages/shared/src/portal/contract.ts and the connector's per-endpoint
// success rules. The portal's envelope is inconsistent, so every endpoint
// decodes its own shape:
//   most:       { status: 0, message, data }
//   door list:  { status: 1, message: [{key,value}], data: {} }  ← doors in `message`
//   login:      { status: 0, ..., token } or { data: { token } }; bad creds → HTTP 401
//   expiry:     HTTP 401 with status 400001 or message "Unauthorized"

import Foundation

public struct PortalCredentials: Codable, Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct PortalSession: Codable, Sendable, Equatable {
    public var token: String
    public var expiresAt: Date
    public var studentId: String
    public init(token: String, expiresAt: Date, studentId: String) {
        self.token = token
        self.expiresAt = expiresAt
        self.studentId = studentId
    }
}

public struct PortalIdentity: Sendable, Equatable {
    public var studentId: String
    public var name: String
    public var isDayStudent: Bool?
    public var tokenExpiresAt: Date
}

/// A loosely-typed envelope: every field optional, `message` may be a string
/// OR an array (door list), `data` may be an object or `{}`.
struct PortalEnvelope: Decodable {
    let status: Int?
    let code: Int?
    let messageText: String?
    let messageArray: [PortalDoor]?
    let token: String?
    let data: AnyJSON?

    private enum CodingKeys: String, CodingKey { case status, code, message, token, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try? c.decode(Int.self, forKey: .status)
        code = try? c.decode(Int.self, forKey: .code)
        messageText = try? c.decode(String.self, forKey: .message)
        messageArray = try? c.decode([PortalDoor].self, forKey: .message)
        token = try? c.decode(String.self, forKey: .token)
        data = try? c.decode(AnyJSON.self, forKey: .data)
    }
}

/// Minimal JSON tree for the envelope's `data` field.
indirect enum AnyJSON: Decodable {
    case object([String: AnyJSON])
    case array([AnyJSON])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([AnyJSON].self) { self = .array(a); return }
        if let o = try? c.decode([String: AnyJSON].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON")
    }

    subscript(key: String) -> AnyJSON? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        default: return nil
        }
    }

    var arrayValue: [AnyJSON]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }
}

public struct PortalDoor: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let key: String
    public let value: String
    public var id: String { key }
    public var displayName: String { value.isEmpty ? key : value }
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// One row of GET /api/exit/get_student_list — kept as the portal sends it.
public struct ExitPermitWire: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let recordId: Int
    public let staffId: Int?
    public let staffName: String?
    public let status: Int
    public let statusName: String?
    public let note: String?
    /// The door flag: 0 until a gate has been opened with this permit —
    /// whether from this app or from the official site.
    public let flag: Int?
    public let startTime: String?
    public let endTime: String?
    public let createTime: String?
    public let updateTime: String?

    public var id: Int { recordId }

    private enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case staffId = "staff_id"
        case staffName = "staff_name"
        case status
        case statusName = "status_name"
        case note, flag
        case startTime = "start_time"
        case endTime = "end_time"
        case createTime = "create_time"
        case updateTime = "update_time"
    }

    public init(recordId: Int, staffId: Int? = nil, staffName: String? = nil, status: Int, statusName: String? = nil, note: String? = nil, flag: Int? = nil, startTime: String?, endTime: String?, createTime: String? = nil, updateTime: String? = nil) {
        self.recordId = recordId
        self.staffId = staffId
        self.staffName = staffName
        self.status = status
        self.statusName = statusName
        self.note = note
        self.flag = flag
        self.startTime = startTime
        self.endTime = endTime
        self.createTime = createTime
        self.updateTime = updateTime
    }
}

/// Commuter (day-student) direct-open sentinel used as record_id.
public let commuterRecordId = -2

public struct OpenDoorRequest: Encodable, Sendable, Equatable {
    public let recordId: Int
    public let status: Int
    public let doorId: String
    public let indexcode: String

    private enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case status
        case doorId = "door_id"
        case indexcode
    }

    /// door_id and indexcode carry the same door key.
    public init(recordId: Int, doorKey: String) {
        self.recordId = recordId
        self.status = 1
        self.doorId = doorKey
        self.indexcode = doorKey
    }
}

public struct AddPermitRequest: Encodable, Sendable, Equatable {
    public let startTime: String
    public let endTime: String
    public let note: String

    private enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case note
    }

    public init(startTime: String, endTime: String, note: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
    }
}

/// What a portal mutation answered (open / apply / delete).
public struct PortalActionResult: Sendable, Equatable {
    public let message: String
    public init(message: String) { self.message = message }
}

public enum PortalUserActionReason: String, Sendable, Equatable, Codable {
    case captcha, mfa, passwordChanged, unknown
}

public enum PortalError: Error, Sendable, Equatable {
    case networkUnavailable
    /// A mutation timed out: it may have been applied — never auto-retry.
    case timeout(outcomeUnknown: Bool)
    case serverUnavailable(httpStatus: Int?)
    case sessionExpired
    case credentialsRejected
    case userActionRequired(PortalUserActionReason)
    /// Well-formed envelope, but the portal refused the operation.
    case operationRejected(endpoint: String, status: Int?, message: String?)
    case schemaIncompatible(endpoint: String)
    /// No saved school login on this device: silent recovery is impossible.
    case noCredentials
}
