// HOney ⇄ OASIS school portal integration contract (Band 4 boundary).
// Re-authored from the connector-analysis blueprint. The portal uses a raw
// `Authorization: <token>` header (no Bearer), server-authoritative `exp`,
// and has NO refresh endpoint — recovery is a full re-login.
/** Commuter (day-student) direct-open sentinel used as record_id. */
export const COMMUTER_RECORD_ID = -2;
/** Portal-specific week index; intentionally NOT the ISO week number. */
export function portalWeekIndex(date) {
    const monday = new Date(date);
    monday.setHours(0, 0, 0, 0);
    const day = monday.getDay();
    monday.setDate(monday.getDate() + (day === 0 ? -6 : 1 - day));
    const epochLocal = new Date(1970, 0, 1);
    return Math.floor(Math.floor((monday.getTime() - epochLocal.getTime()) / 86_400_000) / 7);
}
/** The portal signals an expired session as HTTP 401 with status 400001 or message "Unauthorized". */
export function isUnauthorized(httpStatus, body) {
    if (httpStatus !== 401 || !body || typeof body !== "object")
        return false;
    const value = body;
    return value.status === 400001 || value.message === "Unauthorized";
}
//# sourceMappingURL=contract.js.map