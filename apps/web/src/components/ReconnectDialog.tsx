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
 * opening does; the stay-connected choice sits inside the form before the
 * submit for both purposes (checked by default when saving), with the same
 * caveat the login shows.
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
      ? "Enter your school login once; it stays encrypted on this device (a browser is less protected than a phone’s secure storage) so routine portal time-outs reconnect on their own."
      : "The portal session ended. Sign in again to restore it — your HOney data stays as it is.";
  return (
    <Modal title={title} onClose={onClose} describedBy="school-dialog-body">
      <p className="muted" id="school-dialog-body">
        {body}
      </p>
      <SchoolLoginForm
        mode="reconnect"
        submitLabel={purpose === "save" ? "Save login" : "Reconnect"}
        beforeSubmit={
          <label className="stay-connected">
              <input
                type="checkbox"
                checked={stayConnected}
                onChange={(e) => setStayConnected(e.target.checked)}
              />
              <span>
                {purpose === "save"
                  ? "Stay connected on this device."
                  : "Stay connected on this device — encrypted, kept only here (a browser is less protected than a phone’s secure storage)."}
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
