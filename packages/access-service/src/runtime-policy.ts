// The Web Access switch (spec §24): the Access Service is the source of
// truth; prepare and commit read it directly, so a Dash write binds the next
// physical dispatch immediately. Development default: OFF.

import type { DatabaseSync } from "node:sqlite";

export class RuntimePolicy {
  constructor(private readonly db: DatabaseSync) {}

  enabled(): boolean {
    const row = this.db.prepare("SELECT value FROM access_settings WHERE key = 'WEB_ACCESS_ENABLED'").get() as { value: string } | undefined;
    return row?.value === "true";
  }

  setEnabled(on: boolean): void {
    this.db
      .prepare("INSERT INTO access_settings (key, value, updated_at) VALUES ('WEB_ACCESS_ENABLED', ?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at")
      .run(on ? "true" : "false", Date.now());
  }
}
