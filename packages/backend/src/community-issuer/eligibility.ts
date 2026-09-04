// Standing (spec §31.1): is this the contributor's experience to speak from?
// The only Experiences logic left in Core: it resolves a lesson or a
// standalone entity for the signed-in account (exposure, standalone modes,
// invites, frozen entities, kill switches) and produces the opaque lesson id.
// It never sees a post, a token value, an authorTag or a Community id.

import { createHmac } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import { deriveKey } from "../crypto.js";
import type { EntityDirectory } from "../school/directory.js";
import type { SettingsService } from "../experiences/settings.js";

export interface Target {
  entityKey: string;
  entityType: string;
  provenance: "verified_lesson" | "verified_retrospective" | "verified_member";
  ctx: { teacher: string | null; course: string | null; room: string | null };
  /** The raw lesson instance id for lesson targets (never leaves Core). */
  lessonInstanceId?: string;
}

export type TargetError =
  | "publications_disabled"
  | "target_required"
  | "lesson_not_yours"
  | "entity_unknown"
  | "entity_frozen"
  | "standalone_closed"
  | "not_invited"
  | "no_verified_exposure";

export class EligibilityService {
  private readonly markKey: Buffer;
  private readonly lessonScopeKey: Buffer;

  constructor(
    private readonly db: DatabaseSync,
    private readonly directory: EntityDirectory,
    private readonly settings: SettingsService,
    sealKey: Buffer,
  ) {
    this.markKey = deriveKey(sealKey, "exp-mark");
    this.lessonScopeKey = deriveKey(sealKey, "lesson-scope");
  }

  /**
   * Opaque, roster-unjoinable id for a lesson instance: the raw instance id
   * joins straight to user_lesson_exposures and would identify the author's
   * class roster, so only this HMAC ever leaves Core.
   */
  lessonToken(lessonInstanceId: string): string {
    return createHmac("sha256", this.lessonScopeKey).update(lessonInstanceId).digest("hex").slice(0, 24);
  }

  /** Invite mark for an entity (admin route uses this so keys stay consistent). */
  inviteMark(honeyId: string, entityKey: string): string {
    return createHmac("sha256", this.markKey).update(`${honeyId} invite:${entityKey}`).digest("hex");
  }

  /** Kill switches — enforced at issuance; Community enforces its own copy at check/publish. */
  gate(): TargetError | null {
    if (this.settings.killSwitch("DISABLE_NEW_PUBLICATIONS") || this.settings.killSwitch("PRIVATE_NOTES_ONLY_MODE")) return "publications_disabled";
    return null;
  }

  resolveTarget(honeyId: string, lessonId?: string, entityKey?: string): { ok: true; target: Target } | { ok: false; error: TargetError } {
    let target: Target;
    if (lessonId) {
      const lesson = this.db
        .prepare(
          `SELECT li.id, li.teacher_id, li.course_id, li.room_id FROM user_lesson_exposures e
           JOIN lesson_instances li ON li.id = e.lesson_instance_id WHERE e.honey_id = ? AND li.id = ?`,
        )
        .get(honeyId, lessonId) as { id: string; teacher_id: string | null; course_id: string | null; room_id: string | null } | undefined;
      if (!lesson) return { ok: false, error: "lesson_not_yours" };
      target = {
        entityKey: `lesson:${this.lessonToken(lesson.id)}`,
        entityType: "lesson",
        provenance: "verified_lesson",
        ctx: { teacher: lesson.teacher_id, course: lesson.course_id, room: lesson.room_id },
        lessonInstanceId: lesson.id,
      };
    } else if (entityKey) {
      const entity = this.directory.get(entityKey);
      if (!entity) return { ok: false, error: "entity_unknown" };
      if (this.settings.frozenEntity(entity.entity_key)) return { ok: false, error: "entity_frozen" };
      const mode = this.settings.standaloneMode(entity.entity_key, entity.type);
      if (mode === "closed") return { ok: false, error: "standalone_closed" };
      let provenance: Target["provenance"];
      if (mode === "invite") {
        const invited = this.db.prepare("SELECT 1 FROM invite_marks WHERE entity_key = ? AND mark_hash = ?").get(entity.entity_key, this.inviteMark(honeyId, entity.entity_key));
        if (!invited) return { ok: false, error: "not_invited" };
        provenance = "verified_member";
      } else if (mode === "verified") {
        const p = this.verifiedExposure(honeyId, entity.entity_key, entity.type);
        if (!p) return { ok: false, error: "no_verified_exposure" };
        provenance = p;
      } else {
        provenance = "verified_member";
      }
      target = { entityKey: entity.entity_key, entityType: entity.type, provenance, ctx: { teacher: null, course: null, room: null } };
    } else {
      return { ok: false, error: "target_required" };
    }
    if (this.frozenAnywhere(target.entityKey, target.ctx.teacher, target.ctx.room)) return { ok: false, error: "entity_frozen" };
    return { ok: true, target };
  }

  private frozenAnywhere(entityKey: string, teacherId: string | null, roomId: string | null): boolean {
    return [entityKey, teacherId && `teacher:${teacherId}`, roomId && `room:${roomId}`].filter((k): k is string => !!k).some((k) => this.settings.frozenEntity(k));
  }

  private verifiedExposure(honeyId: string, entityKey: string, type: string): Target["provenance"] | null {
    if (type === "teacher") {
      return this.db.prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND teacher_id = ? LIMIT 1").get(honeyId, entityKey.slice("teacher:".length)) ? "verified_retrospective" : null;
    }
    if (type === "course") {
      return this.db.prepare("SELECT 1 FROM user_lesson_exposures WHERE honey_id = ? AND course_id = ? LIMIT 1").get(honeyId, entityKey.slice("course:".length)) ? "verified_retrospective" : null;
    }
    if (type === "room") {
      const hit = this.db
        .prepare("SELECT 1 FROM user_lesson_exposures e JOIN lesson_instances li ON li.id = e.lesson_instance_id WHERE e.honey_id = ? AND li.room_id = ? LIMIT 1")
        .get(honeyId, entityKey.slice("room:".length));
      return hit ? "verified_retrospective" : null;
    }
    // Dishes: the portal cannot prove consumption — honest provenance is membership.
    return "verified_member";
  }
}
