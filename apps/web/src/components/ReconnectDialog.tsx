import { useState } from "react";
import { Modal } from "./Modal";
import { SchoolLoginForm } from "./SchoolLoginForm";
import { portalCredentials } from "../lib/portalCredentials";

interface ReconnectDialogProps {
  onClose: () => void;
  onReconnected?: () => void;
}

/**
 * Fallback when a silent reconnect isn't possible — the credentials were
 * rejected, or this device never opted into staying connected. Re-runs the
 * school login and offers to keep it for next time.
 */
export function ReconnectDialog({ onClose, onReconnected }: ReconnectDialogProps) {
  const [stayConnected, setStayConnected] = useState(portalCredentials.isAuthorized());
  return (
    <Modal title="Reconnect school account" onClose={onClose}>
      <p className="muted">
        The portal session ended. Sign in again to restore it — your HOney data stays as it is.
      </p>
      <label className="stay-connected">
        <input
          type="checkbox"
          checked={stayConnected}
          onChange={(e) => setStayConnected(e.target.checked)}
        />
        <span>
          Stay connected on this device, so routine time-outs reconnect on their own. Your login is
          encrypted and kept only here.
        </span>
      </label>
      <SchoolLoginForm
        mode="reconnect"
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
