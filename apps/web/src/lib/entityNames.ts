// Names for Community's id-only payloads. Community returns canonical ids and
// null names (it must not know who reads or hold Core's tables); the client
// joins names from Core's public entity directory, loaded once per session.

import type { EntityRefV2, PublicExperienceV2 } from "@honey/shared/community-v2";
import { api } from "../api/client";
import { apiCache } from "./useApi";

type Names = Map<string, string>; // "<type>:<id>" → name

let cache: Promise<Names> | null = null;

export function entityNames(): Promise<Names> {
  cache ??= (async () => {
    const [entities, directory] = await Promise.all([api.entities(), api.directory()]);
    const names: Names = new Map();
    for (const e of entities.entities) names.set(e.entity_key, e.name);
    for (const t of directory.teachers) names.set(`teacher:${t.id}`, t.name);
    for (const c of directory.courses) names.set(`course:${c.id}`, c.name);
    for (const r of directory.rooms) names.set(`room:${r.id}`, r.name);
    return names;
  })().catch((err) => {
    cache = null;
    throw err;
  });
  return cache;
}

export function resetEntityNames(): void {
  cache = null;
  apiCache.invalidate("entities");
}

function named(ref: EntityRefV2, names: Names): EntityRefV2 {
  return ref.type === "lesson" ? ref : { ...ref, name: names.get(`${ref.type}:${ref.id}`) ?? ref.name };
}

export function withNames(exp: PublicExperienceV2, names: Names): PublicExperienceV2 {
  return { ...exp, primary: named(exp.primary, names), contexts: exp.contexts.map((c) => named(c, names)) };
}

export async function nameExperiences(items: PublicExperienceV2[]): Promise<PublicExperienceV2[]> {
  const names = await entityNames();
  return items.map((i) => withNames(i, names));
}
