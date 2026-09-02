import { Modal } from "./Modal";
import { SchoolLoginForm } from "./SchoolLoginForm";
import { portalCredentials } from "../lib/portalCredentials";

interface ReconnectDialogProps {
  onClose: () => void;
  onReconnected?: () => void;
  /** reconnect: the portal session ended (or needs refreshing); save: the
   *  student turned "Stay connected" back on in Settings. */
  purpose?: "reconnect" | "save";
}

/**
 * One dialog, two named purposes: title, body AND submit label say what this
 * opening does. There is no stay-connected choice inside it (Gary
 * 2026-09-02): the login is kept on this device unless the student turned
 * that off in Settings › School connection, and saving is what "save" means.
 */
export function ReconnectDialog({ onClose, onReconnected, purpose = "reconnect" }: ReconnectDialogProps) {
  const keep = purpose === "save" ? true : portalCredentials.wanted();
  const title = purpose === "save" ? "Save school login" : "Reconnect school account";
  const body =
    purpose === "save"
      ? "Enter your school login once; it stays encrypted on this device, with the key that unlocks it (a browser is less protected than a phone’s secure storage), so routine portal time-outs reconnect on their own."
      : keep
        ? "The portal session ended. Sign in again to restore it — your HOney data stays as it is, and the login is kept on this device (turn that off in Settings › School connection)."
        : "The portal session ended. Sign in again to restore it — your HOney data stays as it is. Nothing is kept on this device.";
  return (
    <Modal title={title} onClose={onClose} describedBy="school-dialog-body">
      <p className="muted" id="school-dialog-body">
        {body}
      </p>
      <SchoolLoginForm
        mode="reconnect"
        submitLabel={purpose === "save" ? "Save login" : "Reconnect"}
        onSuccess={(_result, creds) => {
          if (keep) {
            portalCredentials.setWanted(true);
            void portalCredentials.authorize(creds);
          } else {
            portalCredentials.clear();
          }
          onReconnected?.();
          onClose();
        }}
      />
    </Modal>
  );
}
