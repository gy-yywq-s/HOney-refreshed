import { useState } from "react";
import { Modal } from "./Modal";
import { SchoolLoginForm } from "./SchoolLoginForm";
import { portalCredentials } from "../lib/portalCredentials";

interface ReconnectDialogProps {
  onClose: () => void;
  onReconnected?: () => void;
  /** reconnect: the portal session ended (or needs refreshing); save: the
   *  student wants HOney to keep their school login on this device. */
  purpose?: "reconnect" | "save";
}

/**
 * One dialog, two named purposes: title, body AND submit label say what this
 * opening does. Both purposes render the same one-line stay-connected choice
 * inside the form before the submit (checked by default when saving); the
 * storage caveat lives in the body for both.
 */
export function ReconnectDialog({
  onClose,
  onReconnected,
  purpose = "reconnect",
}: ReconnectDialogProps) {
  const [stayConnected, setStayConnected] = useState(
    purpose === "save" ? true : portalCredentials.isAuthorized(),
  );
  const title = purpose === "save" ? "Save school login" : "Reconnect school account";
  const body =
    purpose === "save"
      ? "Enter your school login once; it stays encrypted on this device, with the key that unlocks it (a browser is less protected than a phone’s secure storage), so routine portal time-outs reconnect on their own."
      : "The portal session ended. Sign in again to restore it — your HOney data stays as it is. If you keep the login on this device it stays encrypted here, with the key that unlocks it (a browser is less protected than a phone’s secure storage).";
  return (
    <Modal title={title} onClose={onClose} describedBy="school-dialog-body">
      <p className="muted" id="school-dialog-body">
        {body}
      </p>
      <SchoolLoginForm
        mode="reconnect"
        submitLabel={
          purpose === "save"
            ? stayConnected
              ? "Save login"
              : "Sign in without saving"
            : stayConnected
              ? "Reconnect and save login"
              : "Reconnect only"
        }
        beforeSubmit={
          <label className="stay-connected">
              <input
                type="checkbox"
                checked={stayConnected}
                onChange={(e) => setStayConnected(e.target.checked)}
              />
              <span>
                Stay connected on this device.
              </span>
            </label>
        }
        onSuccess={(_result, creds) => {
          if (stayConnected) void portalCredentials.authorize(creds);
          else portalCredentials.clear();
          onReconnected?.();
          onClose();
        }}
      />
    </Modal>
  );
}
