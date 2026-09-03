// /dash — ops console (admin only). Kill switches, standalone-eligibility
// modes, entity import/freeze/invites, LLM config + live probe, reports,
// reaction-count threshold, cooling-off period, the Web Access switch.
// Deliberately NO author-lookup capability exists anywhere here (App A
// §22.2) — the API cannot answer it.
//
// Restyled 2026-09-03 (Gary: 按照现在新的设计再翻修) in the Settings grammar:
// overline groups of rows with the control at the right, the one switch for
// on/off things (each flip confirmed), stat tiles and forms as cards on the
// surface. Same API calls and confirmations as before.

import { useMemo, useState } from "react";
import { Skeleton } from "../lib/motion";
import { Navigate } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type {
  EntityType,
  KillSwitchName,
  StandaloneMode,
} from "../api/types";
import { CURATED_LLM_MODELS } from "@honey/shared/api";
import { useAuth } from "../auth/AuthContext";
import { ConfirmDialog } from "../components/Modal";
import { Switch } from "../components/Switch";
import { formatCoarseDate } from "../lib/format";
import { useApi } from "../lib/useApi";
import { WebAccessPanel } from "./dash/WebAccessPanel";

const KILL_SWITCH_META: { name: KillSwitchName; label: string; description: string }[] = [
  {
    name: "DISABLE_NEW_PUBLICATIONS",
    label: "Disable new publications",
    description: "Submissions are refused; browsing, reactions and private notes keep working.",
  },
  {
    name: "DISABLE_REACTIONS",
    label: "Disable reactions",
    description: "Like/Dislike stop being accepted everywhere.",
  },
  {
    name: "HIDE_PUBLIC_EXPERIENCES",
    label: "Hide public experiences",
    description: "All public feeds return empty until switched back off.",
  },
  {
    name: "PRIVATE_NOTES_ONLY_MODE",
    label: "Private-notes-only mode",
    description: "Everything stays writable as private notes, but nothing new publishes.",
  },
];

const STANDALONE_MODES: { value: StandaloneMode; label: string }[] = [
  { value: "verified", label: "Verified (needs exposure)" },
  { value: "open", label: "Open (any member)" },
  { value: "invite", label: "Invite-only" },
  { value: "closed", label: "Closed" },
];

const ENTITY_TYPES: EntityType[] = ["teacher", "room", "dish"];

type Feedback = { tone: "success" | "danger"; text: string } | null;
type Run = (key: string, fn: () => Promise<void>, successText?: string) => Promise<void>;

export function DashPage() {
  const { me } = useAuth();
  const overview = useApi(() => api.adminOverview(), []);
  const [feedback, setFeedback] = useState<Feedback>(null);
  const [pendingSwitch, setPendingSwitch] = useState<{ name: KillSwitchName; on: boolean } | null>(
    null,
  );
  const [busy, setBusy] = useState<string | null>(null);

  if (!me) return null;
  if (!me.isAdmin) return <Navigate to="/home" replace />;

  const run: Run = async (key, fn, successText) => {
    setBusy(key);
    setFeedback(null);
    try {
      await fn();
      if (successText) setFeedback({ tone: "success", text: successText });
    } catch (err) {
      setFeedback({
        tone: "danger",
        text: err instanceof ApiError ? `Failed (${err.code}).` : "Failed. Please try again.",
      });
    } finally {
      setBusy(null);
    }
  };

  const counts = overview.data?.counts;

  return (
    <div className="stack settings admin">
      <h1 className="page-title">Dash</h1>
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      {overview.error && <div role="alert" className="banner banner--danger">{overview.error}</div>}
      {overview.data && !overview.data.communityReachable && (
        <div role="alert" className="banner banner--danger">The Community process is unreachable: post counts, reports and moderation settings below are unavailable.</div>
      )}
      {overview.data && !overview.data.issuerReady && (
        <div className="banner banner--warning">No blind-eligibility issuer key is loaded: students cannot share until `issuer:keygen` has run on the server.</div>
      )}

      <section aria-label="Overview">
        <div className="stat-grid">
          <StatTile label="Users" value={counts?.users} />
          <StatTile label="Published" value={counts?.published} />
          <StatTile label="Open reports" value={counts?.openReports} />
          <StatTile label="Entities" value={counts?.entities} />
        </div>
      </section>

      {/* What the system is running: labelled rows, value at the right (Gary
          2026-09-03: version and runtime facts are a group, not a stray line). */}
      <section className="rowlist" aria-label="System">
        <h2 className="overline">System</h2>
        <SystemRow label="Policy version" value={overview.data ? `v${overview.data.policyVersion}` : "…"} />
        <SystemRow label="Moderation model" value={overview.data ? (overview.data.llm.configured ? overview.data.llm.model : "Not configured — nothing publishes") : "…"} />
        <SystemRow label="Blind-eligibility issuer" value={overview.data ? (overview.data.issuerReady ? "Key loaded" : "No key — students cannot share") : "…"} />
        <SystemRow label="Community process" value={overview.data ? (overview.data.communityReachable ? "Reachable" : "Unreachable") : "…"} />
      </section>

      <WebAccessPanel />

      <section className="rowlist" aria-label="Kill switches">
        <h2 className="overline">Kill switches</h2>
        {KILL_SWITCH_META.map((meta) => {
          const on = overview.data?.killSwitches[meta.name] ?? false;
          return (
            <div className="row" key={meta.name}>
              <span className="row__main">
                <span className="row__title">{meta.label}</span>
                <span className="row__sub">{meta.description}</span>
              </span>
              <Switch
                on={on}
                label={meta.label}
                disabled={overview.loading || busy === meta.name}
                onChange={(next) => setPendingSwitch({ name: meta.name, on: next })}
              />
            </div>
          );
        })}
      </section>

      <StandaloneModes
        onApply={(scope, mode) =>
          void run(`mode:${scope}`, async () => {
            await api.adminSetStandaloneMode(scope, mode);
          }, `Standalone mode for ${scope} set to ${mode}.`)
        }
        busy={busy}
      />

      <ReactionThreshold
        onApply={(n) =>
          void run("minCount", async () => {
            await api.adminSetReactionMinCount(n);
          }, `Reaction counts now hidden below ${n}.`)
        }
        busy={busy === "minCount"}
      />

      <CooldownPeriod
        current={overview.data?.cooldownHours ?? 24}
        onApply={(h) =>
          void run("cooldown", async () => {
            await api.adminSetCooldownHours(h);
            overview.reload();
          }, `Cooling-off period is now ${describeHours(h)}.`)
        }
        busy={busy === "cooldown"}
      />

      <EntityAdmin run={run} busy={busy} />
      <EntityImport onDone={() => overview.reload()} />
      <LlmPanel
        model={overview.data?.llm.model ?? ""}
        configured={overview.data?.llm.configured ?? false}
        onSaved={() => overview.reload()}
      />
      <ReportsPanel />

      {pendingSwitch && (
        <ConfirmDialog
          title={pendingSwitch.on ? "Turn this kill switch on?" : "Turn this kill switch off?"}
          body={`${KILL_SWITCH_META.find((m) => m.name === pendingSwitch.name)!.label}: this applies to everyone immediately.`}
          confirmLabel={pendingSwitch.on ? "Switch on" : "Switch off"}
          danger={pendingSwitch.on}
          busy={busy === pendingSwitch.name}
          onClose={() => setPendingSwitch(null)}
          onConfirm={() =>
            void run(pendingSwitch.name, async () => {
              await api.adminSetKillSwitch(pendingSwitch.name, pendingSwitch.on);
              setPendingSwitch(null);
              overview.reload();
            }, "Kill switch updated.")
          }
        />
      )}
    </div>
  );
}

function SystemRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="row">
      <span className="row__main">
        <span className="row__title">{label}</span>
      </span>
      <span className="row__value">{value}</span>
    </div>
  );
}

function StatTile({ label, value }: { label: string; value: number | undefined }) {
  return (
    <div className="stat-tile">
      <span className="stat-tile__value">{value ?? "—"}</span>
      <span className="caption">{label}</span>
    </div>
  );
}

function StandaloneModes({
  onApply,
  busy,
}: {
  onApply: (scope: string, mode: StandaloneMode) => void;
  busy: string | null;
}) {
  const [modes, setModes] = useState<Record<string, StandaloneMode>>({
    teacher: "verified",
    room: "verified",
    dish: "verified",
  });
  return (
    <section className="rowlist" aria-label="Standalone review modes">
      <h2 className="overline">Standalone review modes</h2>
      <p className="caption">
        Who may review teachers / places / dishes directly (lesson reviews are always an
        unconditional right). The server does not echo current values — applying sets them.
      </p>
      {ENTITY_TYPES.map((type) => (
        <div className="row" key={type}>
          <span className="row__main">
            <span className="row__title">{type === "room" ? "Places" : type === "dish" ? "Dishes" : "Teachers"}</span>
          </span>
          <span className="row__actions">
            <select
              className="input"
              aria-label={`Standalone mode for ${type}`}
              value={modes[type]}
              onChange={(e) => setModes((m) => ({ ...m, [type]: e.target.value as StandaloneMode }))}
            >
              {STANDALONE_MODES.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
            <button
              className="btn btn--ghost btn--small"
              disabled={busy === `mode:type.${type}`}
              onClick={() => onApply(`type.${type}`, modes[type]!)}
            >
              Apply
            </button>
          </span>
        </div>
      ))}
    </section>
  );
}

function EntityImport({ onDone }: { onDone: () => void }) {
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  const parsed = useMemo(() => {
    const items: { type: EntityType; name: string }[] = [];
    let bad = 0;
    for (const line of text.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      const comma = trimmed.indexOf(",");
      const type = comma === -1 ? "" : trimmed.slice(0, comma).trim().toLowerCase();
      const name = comma === -1 ? "" : trimmed.slice(comma + 1).trim();
      if ((ENTITY_TYPES as string[]).includes(type) && name) {
        items.push({ type: type as EntityType, name });
      } else {
        bad++;
      }
    }
    return { items, bad };
  }, [text]);

  async function importNow() {
    setBusy(true);
    setResult(null);
    try {
      const r = await api.adminImportEntities(parsed.items);
      setResult(
        `Added ${r.added}, merged with existing ${r.merged}` +
          (r.skippedInvalid ? `, skipped invalid ${r.skippedInvalid}` : "") +
          (parsed.bad ? ` (${parsed.bad} unparseable line${parsed.bad > 1 ? "s" : ""} not sent)` : "") +
          ".",
      );
      setText("");
      onDone();
    } catch {
      setResult("Import failed. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="rowlist" aria-label="Entity import">
      <h2 className="overline">Entity import</h2>
      <div className="card">
        <p className="caption">
          One per line, as <code>type,name</code> — e.g. <code>dish,Braised beef noodles</code> or{" "}
          <code>room,Library</code>. The result is a union with organic entities, deduped by name.
        </p>
        <textarea
          className="input"
          rows={5}
          aria-label="Entities to import"
          placeholder={"dish,Braised beef noodles\nroom,Library\nteacher,Ms Example"}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <div className="card-actions">
          <button
            className="btn btn--primary"
            disabled={busy || parsed.items.length === 0}
            onClick={() => void importNow()}
          >
            {busy ? "Importing…" : `Import ${parsed.items.length || ""} ${parsed.items.length === 1 ? "entity" : "entities"}`}
          </button>
          {parsed.bad > 0 && <span className="caption">{parsed.bad} line(s) will be skipped.</span>}
        </div>
        {result && <p className="caption">{result}</p>}
      </div>
    </section>
  );
}

function EntityAdmin({ run, busy }: { run: Run; busy: string | null }) {
  const [q, setQ] = useState("");
  const entities = useApi(() => api.entities(), []);
  const [inviteKey, setInviteKey] = useState("");
  const [inviteStudent, setInviteStudent] = useState("");

  const shown = useMemo(() => {
    const all = entities.data?.entities ?? [];
    const needle = q.trim().toLowerCase();
    return (needle ? all.filter((e) => e.name.toLowerCase().includes(needle) || e.entity_key.includes(needle)) : all).slice(0, 30);
  }, [entities.data, q]);

  return (
    <section className="rowlist" aria-label="Entities">
      <h2 className="overline">Entities</h2>
      <input
        className="input"
        type="search"
        placeholder="Filter by name or key…"
        aria-label="Filter entities"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      {entities.loading ? (
        <Skeleton lines={3} />
      ) : (
        <>
          {shown.map((e) => (
            <div className="row" key={e.entity_key}>
              <span className="row__main">
                <span className="row__title">{e.name}</span>
                <span className="row__sub">
                  {e.source === "admin" ? "Added in Dash" : "From the timetable"} · {e.entity_key}
                </span>
              </span>
              <span className="row__actions">
                {/* Freeze state isn't exposed by the API; both directions offered. */}
                <button
                  className="btn btn--ghost btn--small"
                  disabled={busy === `freeze:${e.entity_key}`}
                  onClick={() =>
                    void run(`freeze:${e.entity_key}`, async () => {
                      await api.adminFreezeEntity(e.entity_key, true);
                    }, `${e.name} frozen.`)
                  }
                >
                  Freeze
                </button>
                <button
                  className="btn btn--ghost btn--small"
                  disabled={busy === `unfreeze:${e.entity_key}`}
                  onClick={() =>
                    void run(`unfreeze:${e.entity_key}`, async () => {
                      await api.adminFreezeEntity(e.entity_key, false);
                    }, `${e.name} unfrozen.`)
                  }
                >
                  Unfreeze
                </button>
                <button
                  className="btn btn--danger-outline btn--small"
                  disabled={busy === `active:${e.entity_key}`}
                  onClick={() =>
                    void run(`active:${e.entity_key}`, async () => {
                      await api.adminSetEntityActive(e.entity_key, false);
                      entities.reload();
                    }, `${e.name} deactivated.`)
                  }
                >
                  Deactivate
                </button>
              </span>
            </div>
          ))}
          {shown.length === 0 && <p className="caption">No matching active entities.</p>}
        </>
      )}
      <div className="row row--stack">
        <span className="row__main">
          <span className="row__title">Invite a student to review an entity</span>
          <span className="row__sub">For invite-mode entities; by school studentId.</span>
        </span>
        <span className="row__actions">
          <input
            className="input input--key"
            placeholder="entity key (e.g. dish:a_1b2c…)"
            aria-label="Entity key to invite to"
            value={inviteKey}
            onChange={(e) => setInviteKey(e.target.value)}
          />
          <input
            className="input input--id"
            placeholder="studentId"
            aria-label="Student id to invite"
            value={inviteStudent}
            onChange={(e) => setInviteStudent(e.target.value)}
          />
          <button
            className="btn btn--ghost btn--small"
            disabled={!inviteKey.trim() || !inviteStudent.trim() || busy === "invite"}
            onClick={() =>
              void run("invite", async () => {
                try {
                  await api.adminInvite(inviteKey.trim(), inviteStudent.trim());
                } catch (err) {
                  if (err instanceof ApiError && err.code === "student_not_found") {
                    throw new ApiError(404, "student_not_found");
                  }
                  throw err;
                }
                setInviteKey("");
                setInviteStudent("");
              }, "Invited.")
            }
          >
            Invite
          </button>
        </span>
      </div>
    </section>
  );
}

function LlmPanel({
  model,
  configured,
  onSaved,
}: {
  model: string;
  configured: boolean;
  onSaved: () => void;
}) {
  const [modelInput, setModelInput] = useState<string | null>(null);
  const [apiKey, setApiKey] = useState("");
  const [busy, setBusy] = useState<"save" | "test" | null>(null);
  const [note, setNote] = useState<string | null>(null);

  async function save() {
    setBusy("save");
    setNote(null);
    try {
      const input: { apiKey?: string; model?: string } = {};
      if (apiKey.trim()) input.apiKey = apiKey.trim();
      if (modelInput !== null && modelInput.trim() && modelInput !== model) input.model = modelInput.trim();
      if (!input.apiKey && !input.model) {
        setNote("Nothing to save.");
        return;
      }
      await api.adminSetLlm(input);
      setApiKey(""); // write-only: the key is never redisplayed
      setNote("Saved.");
      onSaved();
    } catch {
      setNote("Save failed.");
    } finally {
      setBusy(null);
    }
  }

  async function test() {
    setBusy("test");
    setNote(null);
    try {
      const r = await api.adminTestLlm();
      setNote(
        r.ok
          ? `OK — ${r.latencyMs ?? "?"} ms via ${r.model ?? "unknown model"}.`
          : "Probe failed — the pipeline would fail closed right now.",
      );
    } catch {
      setNote("Probe request failed.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="rowlist" aria-label="Moderation model">
      <h2 className="overline">Moderation model</h2>
      <div className="card">
        <p className="caption">
          {configured ? "A key is configured (sealed at rest — never shown again)." : "No key configured: moderation fails closed and nothing publishes."}
        </p>
        <div className="field">
          <label className="field__label" htmlFor="llm-model">
            Model
          </label>
          {/* A wheel of the benched models (a native picker on phones); the
              configured model stays selectable even if it is not on the list. */}
          <select id="llm-model" className="input" value={modelInput ?? model} onChange={(e) => setModelInput(e.target.value)}>
            {model && !CURATED_LLM_MODELS.some((m) => m.id === model) && (
              <option value={model}>{model} — configured</option>
            )}
            {CURATED_LLM_MODELS.map((m) => (
              <option key={m.id} value={m.id}>
                {m.label} — {m.note}
              </option>
            ))}
          </select>
          <span className="caption">{CURATED_LLM_MODELS.find((m) => m.id === (modelInput ?? model))?.id ?? (modelInput ?? model)}</span>
        </div>
        <div className="field">
          <label className="field__label" htmlFor="llm-key">
            OpenRouter API key (write-only)
          </label>
          <input
            id="llm-key"
            className="input"
            type="password"
            autoComplete="off"
            placeholder={configured ? "•••••••• (set — enter a new key to replace)" : "sk-or-…"}
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
          />
        </div>
        <div className="card-actions">
          <button className="btn btn--primary" disabled={busy !== null} onClick={() => void save()}>
            {busy === "save" ? "Saving…" : "Save"}
          </button>
          <button className="btn btn--ghost" disabled={busy !== null} onClick={() => void test()}>
            {busy === "test" ? "Testing…" : "Test"}
          </button>
          {note && <span className="caption">{note}</span>}
        </div>
      </div>
    </section>
  );
}

function ReportsPanel() {
  const reports = useApi(() => api.adminReports(), []);
  return (
    <section className="rowlist" aria-label="Reports">
      <h2 className="overline">Reports</h2>
      {reports.loading ? (
        <Skeleton lines={3} />
      ) : reports.error ? (
        <div role="alert" className="banner banner--danger">{reports.error}</div>
      ) : (reports.data?.reports.length ?? 0) === 0 ? (
        <p className="caption">No reports.</p>
      ) : (
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Date</th>
                <th>Category</th>
                <th>Outcome</th>
                <th>Post</th>
              </tr>
            </thead>
            <tbody>
              {reports.data!.reports.map((r) => (
                <tr key={r.id}>
                  <td>{formatCoarseDate(r.created_at)}</td>
                  <td>{r.category.replaceAll("_", " ")}</td>
                  <td>{(r.outcome ?? "pending").replaceAll("_", " ")}</td>
                  <td className="caption">{r.experience_id.slice(0, 8)}…</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function ReactionThreshold({
  onApply,
  busy,
}: {
  onApply: (n: number) => void;
  busy: boolean;
}) {
  const [value, setValue] = useState("");
  const n = Number(value);
  const valid = value.trim() !== "" && Number.isInteger(n) && n >= 0;
  return (
    <section className="rowlist" aria-label="Reaction count threshold">
      <h2 className="overline">Reaction counts</h2>
      <div className="row">
        <span className="row__main">
          <span className="row__title">Hide counts below</span>
          <span className="row__sub">
            Small-cohort protection: posts with fewer total reactions show buttons but no numbers.
          </span>
        </span>
        <span className="row__actions">
          <input
            className="input"
            type="number"
            min={0}
            step={1}
            aria-label="Minimum reaction count"
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
          <button className="btn btn--ghost btn--small" disabled={!valid || busy} onClick={() => onApply(n)}>
            Apply
          </button>
        </span>
      </div>
    </section>
  );
}

const COOLDOWN_PRESETS = [1, 2, 3, 6, 12, 24, 48, 72, 168];
function describeHours(h: number): string {
  if (h % 24 === 0) return h === 24 ? "1 day" : `${h / 24} days`;
  return h === 1 ? "1 hour" : `${h} hours`;
}

/** The cooling-off period: a wheel of whole-hour presets (a native picker on phones). */
function CooldownPeriod({
  current,
  onApply,
  busy,
}: {
  current: number;
  onApply: (h: number) => void;
  busy: boolean;
}) {
  const [value, setValue] = useState<number | null>(null);
  const chosen = value ?? current;
  const options = COOLDOWN_PRESETS.includes(current) ? COOLDOWN_PRESETS : [...COOLDOWN_PRESETS, current].sort((a, b) => a - b);
  return (
    <section className="rowlist" aria-label="Cooling-off period">
      <h2 className="overline">Cooling-off period</h2>
      <div className="row">
        <span className="row__main">
          <span className="row__title">Currently {describeHours(current)}</span>
          <span className="row__sub">
            A high-arousal draft is kept private for this long before it can be checked again. The
            student sees the remaining time on the note.
          </span>
        </span>
        <span className="row__actions">
          <select
            className="input"
            aria-label="Cooling-off period"
            value={chosen}
            onChange={(e) => setValue(Number(e.target.value))}
          >
            {options.map((h) => (
              <option key={h} value={h}>
                {describeHours(h)}
              </option>
            ))}
          </select>
          <button className="btn btn--primary btn--small" disabled={busy || chosen === current} onClick={() => onApply(chosen)}>
            {busy ? "Saving…" : "Apply"}
          </button>
        </span>
      </div>
    </section>
  );
}
