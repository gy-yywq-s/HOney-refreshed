import { useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { ConfirmDialog } from "../components/Modal";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { timeAgo } from "../lib/format";
import { ownershipKeys } from "../lib/ownershipKeys";

type PendingConfirm = "disconnect" | "delete-data" | "delete-account" | null;

export function SettingsPage() {
  const { me, refreshMe, signOut } = useAuth();
  const navigate = useNavigate();
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(
    null,
  );
  const [confirm, setConfirm] = useState<PendingConfirm>(null);
  const [showReconnect, setShowReconnect] = useState(false);

  if (!me) return null;

  async function run(key: string, fn: () => Promise<void>, successText?: string) {
    setBusyKey(key);
    setFeedback(null);
    try {
      await fn();
      if (successText) setFeedback({ tone: "success", text: successText });
    } catch (err) {
      setFeedback({ tone: "danger", text: describeApiError(err) });
    } finally {
      setBusyKey(null);
    }
  }

  const connection = me.connection;

  return (
    <div>
      <h1 className="page-title">Settings</h1>
      {feedback && (
        <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>
      )}

      <section className="card settings-section" aria-label="Account">
        <h2 className="section-title">Account</h2>
        <div className="setting-row">
          <div className="setting-row__main">
            <span>{me.displayName}</span>
            <span className="caption">HOney ID: {me.honeyId}</span>
          </div>
          <button className="btn btn--ghost" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
        {me.isAdmin && (
          <div className="setting-row">
            <div className="setting-row__main">
              <span>Dash</span>
              <span className="caption">The operational console for admins.</span>
            </div>
            <Link className="btn btn--ghost" to="/dash">
              Open Dash
            </Link>
          </div>
        )}
        <div className="setting-row">
          <div className="setting-row__main">
            <span>Delete account</span>
            <span className="caption">
              Removes your HOney account and everything imported with it. Published experiences
              stay — they carry no author ID and are controlled only by the keys on your devices.
            </span>
          </div>
          <button className="btn btn--danger" onClick={() => setConfirm("delete-account")}>
            Delete…
          </button>
        </div>
      </section>

      <section className="card settings-section" aria-label="School connection">
        <h2 className="section-title">School connection</h2>
        <div className="setting-row">
          <div className="setting-row__main">
            <span>{connection.connected ? "Connected" : "Not connected"}</span>
            <span className="caption">
              {connection.connected && !connection.portalTokenValid
                ? "Portal session expired — reconnect to sync again."
                : connection.lastSyncedAt
                  ? `Last synced ${timeAgo(connection.lastSyncedAt)}`
                  : "Never synced"}
            </span>
          </div>
          <div className="card-actions" style={{ marginTop: 0 }}>
            <button className="btn btn--ghost" onClick={() => setShowReconnect(true)}>
              Reconnect
            </button>
            {connection.connected && (
              <button
                className="btn btn--ghost"
                onClick={() => setConfirm("disconnect")}
                disabled={busyKey === "disconnect"}
              >
                Disconnect
              </button>
            )}
          </div>
        </div>
      </section>

      <section className="card settings-section" aria-label="Imported data">
        <h2 className="section-title">Imported data</h2>
        <div className="setting-row">
          <div className="setting-row__main">
            <span>Import my timetable</span>
            <span className="caption">
              {me.consent.timetable
                ? me.consent.grantedAt
                  ? `Consent granted ${timeAgo(me.consent.grantedAt)}`
                  : "Consent granted"
                : "Import is switched off"}
            </span>
          </div>
          <label className="checkbox" style={{ margin: 0 }}>
            <input
              type="checkbox"
              checked={me.consent.timetable}
              disabled={busyKey === "consent"}
              onChange={() =>
                void run(
                  "consent",
                  async () => {
                    await api.setConsent(!me.consent.timetable);
                    await refreshMe();
                  },
                  me.consent.timetable ? "Timetable import switched off." : "Timetable import on.",
                )
              }
            />
            <span className="caption">{me.consent.timetable ? "On" : "Off"}</span>
          </label>
        </div>
        <div className="setting-row">
          <div className="setting-row__main">
            <span>Delete imported data</span>
            <span className="caption">
              Removes all timetable and history data imported from the school portal.
            </span>
          </div>
          <button className="btn btn--danger" onClick={() => setConfirm("delete-data")}>
            Delete…
          </button>
        </div>
      </section>

      <section className="card settings-section" aria-label="Experiences and privacy">
        <h2 className="section-title">How privacy works</h2>
        <p className="muted">
          The plain version: HOney checks you actually have the relevant experience, published posts
          are not attached to your school account, and your device holds the control needed to
          remove your own post. The detail, honestly:
        </p>
        <ul className="privacy-list muted">
          <li>
            <strong>Published posts are stored without an author ID.</strong> The publish request
            carries no account identity, so the stored post has nothing that says who wrote it —
            there is no author lookup, for anyone, including admins.
          </li>
          <li>
            <strong>Your control is a device-held key.</strong> Each publish returns a one-time
            ownership key stored only in this browser; the server keeps only a hash. Presenting the
            key is the only way to find or revoke your post.
          </li>
          <li>
            <strong>Public dates are coarse.</strong> Posts show a calendar day only; exact
            timestamps are never published.
          </li>
          <li>
            <strong>Private notes stay on this device.</strong> They are scrambled at rest, so a
            casual look at browser storage won't read them — but the key sits on this device too.
            That protects against casual dumps, not against scripts running on this site or someone
            with full access to this browser. Treat them as private-on-this-device.
          </li>
        </ul>
        <KeyManagement onFeedback={setFeedback} />
      </section>

      {confirm === "disconnect" && (
        <ConfirmDialog
          title="Disconnect school account?"
          body="HOney will stop syncing until you reconnect. Imported data is kept."
          confirmLabel="Disconnect"
          busy={busyKey === "disconnect"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run(
              "disconnect",
              async () => {
                await api.disconnectSchool();
                await refreshMe();
                setConfirm(null);
              },
              "School account disconnected.",
            )
          }
        />
      )}
      {confirm === "delete-data" && (
        <ConfirmDialog
          title="Delete imported data?"
          body="All imported timetable and history data will be removed from HOney. You can import again later."
          confirmLabel="Delete imported data"
          danger
          busy={busyKey === "delete-data"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run(
              "delete-data",
              async () => {
                await api.deleteImportedData();
                await refreshMe();
                setConfirm(null);
              },
              "Imported data deleted.",
            )
          }
        />
      )}
      {confirm === "delete-account" && (
        <ConfirmDialog
          title="Delete your HOney account?"
          body="This permanently removes your account and imported data. This cannot be undone."
          confirmLabel="Delete account"
          danger
          busy={busyKey === "delete-account"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run("delete-account", async () => {
              await api.deleteAccount();
              navigate("/login", { replace: true });
            })
          }
        />
      )}
      {showReconnect && (
        <ReconnectDialog
          onClose={() => setShowReconnect(false)}
          onReconnected={() => void refreshMe()}
        />
      )}
    </div>
  );
}

function KeyManagement({
  onFeedback,
}: {
  onFeedback: (f: { tone: "success" | "danger"; text: string } | null) => void;
}) {
  const [count, setCount] = useState(() => ownershipKeys.count());
  const fileRef = useRef<HTMLInputElement>(null);

  function exportKeys() {
    const blob = new Blob([ownershipKeys.exportJson()], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "HOney-ownership-keys.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  async function importKeys(file: File) {
    try {
      const added = ownershipKeys.importJson(await file.text());
      setCount(ownershipKeys.count());
      onFeedback({
        tone: "success",
        text: added > 0 ? `Imported ${added} new ownership key${added > 1 ? "s" : ""}.` : "No new keys — everything in that file is already here.",
      });
    } catch {
      onFeedback({ tone: "danger", text: "That file is not a HOney ownership-key export." });
    }
  }

  return (
    <div className="setting-row">
      <div className="setting-row__main">
        <span>Ownership keys on this device</span>
        <span className="caption">
          {count === 0
            ? "None yet — keys appear here when you publish an experience."
            : `${count} key${count > 1 ? "s" : ""}. Export a backup before clearing site data or switching browsers.`}
        </span>
      </div>
      <div className="card-actions" style={{ marginTop: 0 }}>
        <button className="btn btn--ghost" onClick={exportKeys} disabled={count === 0}>
          Export
        </button>
        <button className="btn btn--ghost" onClick={() => fileRef.current?.click()}>
          Import…
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="application/json,.json"
          style={{ display: "none" }}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void importKeys(file);
            e.target.value = "";
          }}
        />
      </div>
    </div>
  );
}
