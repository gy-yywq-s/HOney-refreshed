// /dash — ops console (admin only). Kill switches, standalone-eligibility
// modes, entity import/freeze/invites, LLM config + live probe, reports,
// reaction-count threshold. Deliberately NO author-lookup capability exists
// anywhere here (App A §22.2) — the API cannot answer it.

import { useMemo, useState } from "react";
import { Skeleton } from "../lib/motion";
import { Navigate } from "react-router-dom";
import { api, ApiError } from "../api/client";
import type {
  EntityType,
  KillSwitchName,
  StandaloneMode,
} from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { ConfirmDialog } from "../components/Modal";
import { formatCoarseDate } from "../lib/format";
import { useApi } from "../lib/useApi";

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

  async function run(key: string, fn: () => Promise<void>, successText?: string) {
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
  }

  const counts = overview.data?.counts;

  return (
    <div className="stack admin">
      <h1 className="page-title">Dash</h1>
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      {overview.error && <div role="alert" className="banner banner--danger">{overview.error}</div>}

      <section aria-label="Overview">
        <h2 className="overline">Overview</h2>
        <div className="stat-grid">
          <StatTile label="Users" value={counts?.users} />
          <StatTile label="Published" value={counts?.published} />
          <StatTile label="Open reports" value={counts?.openReports} />
          <StatTile label="Entities" value={counts?.entities} />
        </div>
        {overview.data && (
          <p className="caption" style={{ marginTop: "var(--space-sm)" }}>
            Policy v{overview.data.policyVersion} · LLM{" "}
            {overview.data.llm.configured ? `configured (${overview.data.llm.model})` : "not configured"}
          </p>
        )}
      </section>

      <section className="card" aria-label="Kill switches">
        <h2 className="section-title">Kill switches</h2>
        {KILL_SWITCH_META.map((meta) => {
          const on = overview.data?.killSwitches[meta.name] ?? false;
          return (
            <div className="setting-row" key={meta.name}>
              <div className="setting-row__main">
                <span>{meta.label}</span>
                <span className="caption">{meta.description}</span>
              </div>
              <button
                className={on ? "btn btn--danger btn--small" : "btn btn--ghost btn--small"}
                disabled={overview.loading || busy === meta.name}
                onClick={() => setPendingSwitch({ name: meta.name, on: !on })}
              >
                {on ? "ON — switch off" : "Off — switch on"}
              </button>
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

      <EntityImport onDone={() => overview.reload()} />
      <EntityAdmin run={run} busy={busy} />
      <LlmPanel
        model={overview.data?.llm.model ?? ""}
        configured={overview.data?.llm.configured ?? false}
        onSaved={() => overview.reload()}
      />
      <ReportsPanel />

      <ReactionThreshold
        onApply={(n) =>
          void run("minCount", async () => {
            await api.adminSetReactionMinCount(n);
          }, `Reaction counts now hidden below ${n}.`)
        }
        busy={busy === "minCount"}
      />

      {pendingSwitch && (
        <ConfirmDialog
          title={pendingSwitch.on ? "Turn this kill switch ON?" : "Turn this kill switch off?"}
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
    <section className="card" aria-label="Standalone review modes">
      <h2 className="section-title">Standalone review modes</h2>
      <p className="caption">
        Who may review teachers / places / dishes directly (lesson reviews are always an
        unconditional right). The server does not echo current values — applying sets them.
      </p>
      {ENTITY_TYPES.map((type) => (
        <div className="setting-row" key={type}>
          <div className="setting-row__main">
            <span style={{ textTransform: "capitalize" }}>{type === "room" ? "Places" : type === "dish" ? "Dishes" : "Teachers"}</span>
          </div>
          <div className="card-actions" style={{ marginTop: 0 }}>
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
          </div>
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
    <section className="card" aria-label="Entity import">
      <h2 className="section-title">Entity import</h2>
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
    </section>
  );
}

function EntityAdmin({
  run,
  busy,
}: {
  run: (key: string, fn: () => Promise<void>, successText?: string) => Promise<void>;
  busy: string | null;
}) {
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
    <section className="card" aria-label="Entities">
      <h2 className="section-title">Entities</h2>
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
        <ul className="entity-list" style={{ marginTop: "var(--space-md)" }}>
          {shown.map((e) => (
            <li className="entity-admin-row" key={e.entity_key}>
              <div className="setting-row__main">
                <span>{e.name}</span>
                <span className="caption">
                  {e.entity_key} · {e.source}
                </span>
              </div>
              <div className="entity-admin-row__actions">
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
                  className="btn btn--ghost btn--small"
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
              </div>
            </li>
          ))}
          {shown.length === 0 && <li className="caption">No matching active entities.</li>}
        </ul>
      )}
      <div className="setting-row">
        <div className="setting-row__main">
          <span>Invite a student to review an entity</span>
          <span className="caption">For invite-mode entities; by school studentId.</span>
        </div>
        <div className="card-actions" style={{ marginTop: 0 }}>
          <input
            className="input"
            placeholder="entity key (e.g. dish:a_1b2c…)"
            aria-label="Entity key to invite to"
            value={inviteKey}
            onChange={(e) => setInviteKey(e.target.value)}
          />
          <input
            className="input"
            placeholder="studentId"
            aria-label="Student id to invite"
            value={inviteStudent}
            onChange={(e) => setInviteStudent(e.target.value)}
            style={{ maxWidth: 120 }}
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
        </div>
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
    <section className="card" aria-label="Moderation LLM">
      <h2 className="section-title">Moderation LLM</h2>
      <p className="caption">
        {configured ? "A key is configured (sealed at rest — never shown again)." : "No key configured: moderation fails closed and nothing publishes."}
      </p>
      <div className="field">
        <label className="field__label" htmlFor="llm-model">
          Model
        </label>
        <input
          id="llm-model"
          className="input"
          value={modelInput ?? model}
          onChange={(e) => setModelInput(e.target.value)}
        />
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
    </section>
  );
}

function ReportsPanel() {
  const reports = useApi(() => api.adminReports(), []);
  return (
    <section className="card" aria-label="Reports">
      <h2 className="section-title">Reports</h2>
      {reports.loading ? (
        <Skeleton lines={3} />
      ) : reports.error ? (
        <div role="alert" className="banner banner--danger">{reports.error}</div>
      ) : (reports.data?.reports.length ?? 0) === 0 ? (
        <p className="empty">No reports.</p>
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
    <section className="card" aria-label="Reaction count threshold">
      <h2 className="section-title">Reaction count threshold</h2>
      <div className="setting-row">
        <div className="setting-row__main">
          <span>Hide counts below</span>
          <span className="caption">
            Small-cohort protection: posts with fewer total reactions show buttons but no numbers.
          </span>
        </div>
        <div className="card-actions" style={{ marginTop: 0 }}>
          <input
            className="input"
            type="number"
            min={0}
            step={1}
            aria-label="Minimum reaction count"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            style={{ maxWidth: 100 }}
          />
          <button className="btn btn--ghost btn--small" disabled={!valid || busy} onClick={() => onApply(n)}>
            Apply
          </button>
        </div>
      </div>
    </section>
  );
}
