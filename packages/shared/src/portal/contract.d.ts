export type UnixSeconds = number;
export interface AuthSession {
    token: string;
    expiresAt: Date;
    studentId: string;
}
export interface StoredCredentials {
    username: string;
    password: string;
}
export interface PortalIdentity {
    studentId: string;
    name: string;
    schoolAccountIdentifier: string;
    type: number;
    campusId?: number;
    dayStudent?: boolean;
    tokenExpiresAt: Date;
}
export interface WeeklyLessonWire {
    lesson_id: number;
    start_time: UnixSeconds;
    end_time: UnixSeconds;
    teacher: string;
    subject_name: string;
    room_name: string;
    topic_name: string;
    students: string | string[];
    class_id: number;
    class_name: string;
    conflict: number;
    conflict_with: unknown[];
}
export interface LessonTableWire {
    room_name: string;
    room_id: number;
    lesson_id: number;
    subject_id: number;
    subject_name: string;
    start_time: UnixSeconds;
    topic_id: number;
    end_time: UnixSeconds;
    teacher: string;
    week_num: number;
    conflict: number;
    conflict_with: unknown[];
}
export interface Lesson {
    id: string;
    classId?: string;
    subjectId?: string;
    topicId?: string;
    roomId?: string;
    subjectName: string;
    className?: string;
    topicName?: string;
    teacherDisplayName?: string;
    roomDisplayName?: string;
    startsAt: Date;
    endsAt: Date;
    conflict: boolean;
    conflictWith: string[];
}
export type PermitStatus = 0 | 1 | 2 | 3;
export interface ExitPermitWire {
    record_id: number;
    staff_id: number;
    staff_name: string;
    status: PermitStatus;
    status_name: string;
    note: string;
    flag: number;
    start_time: string;
    end_time: string;
    create_time: string;
    update_time: string;
}
export interface DoorOptionWire {
    key: string;
    value: string;
}
/** Commuter (day-student) direct-open sentinel used as record_id. */
export declare const COMMUTER_RECORD_ID: -2;
export interface OpenDoorRequest {
    permitRecordId: number;
    doorKey: string;
}
export type ConnectorError = {
    kind: "networkUnavailable";
    retryable: true;
} | {
    kind: "timeout";
    retryable: true;
    outcomeUnknown?: boolean;
} | {
    kind: "serverUnavailable";
    retryable: true;
    httpStatus?: number;
} | {
    kind: "sessionExpired";
    retryable: true;
} | {
    kind: "credentialsRejected";
    retryable: false;
} | {
    kind: "userActionRequired";
    reason: "captcha" | "mfa" | "passwordChanged" | "unknown";
} | {
    kind: "schemaIncompatible";
    endpoint: string;
};
export interface PortalConnector {
    login(credentials: StoredCredentials): Promise<AuthSession>;
    validate(session: AuthSession): Promise<PortalIdentity>;
    reauthenticate(credentials: StoredCredentials): Promise<AuthSession>;
    /** refresh() is intentionally unsupported: the portal has no refresh flow. */
    getLessons(from: Date, to: Date): Promise<Lesson[]>;
    getPermits(): Promise<ExitPermitWire[]>;
    getDoors(): Promise<DoorOptionWire[]>;
    openDoor(request: OpenDoorRequest): Promise<void>;
    logout(): Promise<void>;
}
/** Portal-specific week index; intentionally NOT the ISO week number. */
export declare function portalWeekIndex(date: Date): number;
/** The portal signals an expired session as HTTP 401 with status 400001 or message "Unauthorized". */
export declare function isUnauthorized(httpStatus: number, body: unknown): boolean;
