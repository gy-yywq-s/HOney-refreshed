import { Modal } from "./Modal";
import { SchoolLoginForm } from "./SchoolLoginForm";

interface ReconnectDialogProps {
  onClose: () => void;
  onReconnected?: () => void;
}

/**
 * Re-runs the school login to restore the portal connection. HOney never
 * stores the password, so reconnecting always means typing it again.
 */
export function ReconnectDialog({ onClose, onReconnected }: ReconnectDialogProps) {
  return (
    <Modal title="Reconnect school account" onClose={onClose}>
      <p className="muted">
        HOney does not store your school password, so restoring the portal connection means signing
        in again. Your HOney data stays as it is.
      </p>
      <SchoolLoginForm
        mode="reconnect"
        onSuccess={() => {
          onReconnected?.();
          onClose();
        }}
      />
    </Modal>
  );
}
