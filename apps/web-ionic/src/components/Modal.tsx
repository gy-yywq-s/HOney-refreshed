import type { ReactNode } from "react";
import { IonModal } from "@ionic/react";

interface ModalProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
}

/** Ionic owns focus trapping, Escape/backdrop dismissal and overlay stacking. */
export function Modal({ title, onClose, children }: ModalProps) {
  return (
    <IonModal
      className="honey-modal"
      isOpen
      onDidDismiss={onClose}
      backdropDismiss
      aria-label={title}
    >
        <div className="modal">
          <div className="modal__head">
            <h2 className="modal__title">{title}</h2>
            <button className="modal__close" onClick={onClose} aria-label="Close">
              &times;
            </button>
          </div>
          {children}
        </div>
    </IonModal>
  );
}

interface ConfirmDialogProps {
  title: string;
  body: string;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

export function ConfirmDialog({
  title,
  body,
  confirmLabel,
  danger = false,
  busy = false,
  onConfirm,
  onClose,
}: ConfirmDialogProps) {
  return (
    <Modal title={title} onClose={onClose}>
      <p className="muted">{body}</p>
      <div className="modal__actions modal__actions--row">
        <button className="btn btn--ghost" onClick={onClose} disabled={busy}>
          Cancel
        </button>
        <button
          className={danger ? "btn btn--danger" : "btn btn--primary"}
          onClick={onConfirm}
          disabled={busy}
        >
          {busy ? "Working…" : confirmLabel}
        </button>
      </div>
    </Modal>
  );
}
