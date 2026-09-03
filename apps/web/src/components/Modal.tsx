import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import type { ReactNode } from "react";

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

const CLOSE_MS = 320; // matches the sheet's transition; the fallback if transitionend never fires
const DISMISS_PX = 110; // damped drag that commits a dismiss
const DISMISS_VELOCITY = 0.6; // px/ms — a flick commits too
const EXPAND_PX = 56; // a pull up on the handle that takes a reading sheet to full height

interface ModalProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
  /** id of the element that describes the dialog (its first sentence). */
  describedBy?: string | undefined;
  /** false while something physical is in flight: no ×, no backdrop/Escape/drag dismiss. */
  dismissible?: boolean;
  /**
   * A reading sheet with two heights (Gary 2026-09-03: sheet 往上拉即可放大):
   * it opens part-height, a pull UP takes it full-height, a pull down brings
   * it back, and a pull down from part-height dismisses as usual.
   */
  expandable?: boolean;
}

function reducedMotion(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * The dialog / bottom sheet. On phones it presents like a native sheet
 * (Gary 2026-09-02, the Ionic reference): it slides up on the iOS curve,
 * slides DOWN before it leaves (never a jump cut), and follows the finger —
 * drag it down past the threshold or flick it to dismiss, otherwise it
 * springs back. Escape, the × and the backdrop close through the same
 * exit. Focus starts on the dialog and returns to the opener; the app
 * behind is inert.
 */
export function Modal({ title, onClose, children, describedBy, dismissible = true, expandable = false }: ModalProps) {
  const shellRef = useRef<HTMLDivElement>(null);
  const overlayRef = useRef<HTMLDivElement>(null);
  const [closing, setClosing] = useState(false);
  // "medium" is the opening height of a reading sheet; a pull up makes it
  // "large". Non-expandable sheets keep their single height.
  const [detent, setDetent] = useState<"medium" | "large">(expandable ? "medium" : "large");
  const detentRef = useRef(detent);
  detentRef.current = detent;
  const expandableRef = useRef(expandable);
  expandableRef.current = expandable;
  // Read through a ref: an inline onClose (new identity each render) must
  // not re-run the focus/inert effect — its cleanup moves focus.
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;
  const dismissibleRef = useRef(dismissible);
  dismissibleRef.current = dismissible;
  const closingRef = useRef(false);

  // One exit for every closer: animate out, then let the owner unmount.
  const requestClose = useCallback(() => {
    if (closingRef.current || !dismissibleRef.current) return;
    closingRef.current = true;
    if (reducedMotion()) {
      onCloseRef.current();
      return;
    }
    setClosing(true);
    const shell = shellRef.current;
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      onCloseRef.current();
    };
    shell?.addEventListener("transitionend", finish, { once: true });
    window.setTimeout(finish, CLOSE_MS + 40);
  }, []);

  // Escape closes; Tab cycles inside the dialog; focus starts on the dialog
  // and returns to the opener on close (design audit 2026-09-01, fix 6).
  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    const shell = shellRef.current;
    // Focus AFTER the sheet has arrived, and never let focus scroll: iOS
    // Safari otherwise scrolls the viewport to a sheet that is still
    // translated off-screen, so the whole page jumps up and settles back
    // with the sheet left short of the bottom edge (Gary's device round).
    const focusTimer = window.setTimeout(() => shell?.focus({ preventScroll: true }), reducedMotion() ? 0 : 380);
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        requestClose();
        return;
      }
      if (e.key !== "Tab" || !shell) return;
      const items = Array.from(shell.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (items.length === 0) return;
      const first = items[0]!;
      const last = items[items.length - 1]!;
      const active = document.activeElement;
      if (e.shiftKey && (active === first || active === shell)) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    // The app behind the dialog is inert (r8): no tab, click or AT access.
    const root = document.getElementById("root");
    root?.setAttribute("inert", "");
    // …and it does not scroll under the sheet: a rubber-banding region behind
    // a fixed overlay is what leaves the screen drifted on iOS (Gary
    // 2026-09-03). The scroll position is kept — only the scrolling stops.
    document.body.classList.add("has-sheet");
    if (window.scrollY !== 0 || window.scrollX !== 0) window.scrollTo(0, 0);
    return () => {
      document.body.classList.remove("has-sheet");
      window.clearTimeout(focusTimer);
      document.removeEventListener("keydown", onKey);
      root?.removeAttribute("inert");
      opener?.focus?.({ preventScroll: true });
    };
  }, [requestClose]);

  // The sheet follows the finger (phones): a drag from anywhere on the sheet
  // while its own content is at the top; the backdrop thins with it.
  useEffect(() => {
    const shell = shellRef.current;
    const overlay = overlayRef.current;
    if (!shell || !overlay) return;
    const sheet = () => window.matchMedia("(max-width: 640px)").matches;
    let startY = 0;
    let startT = 0;
    let lastY = 0;
    let lastT = 0;
    let dragging = false;
    let dy = 0;
    // On a reading sheet the two gestures must not fight: the TEXT scrolls
    // normally, and the sheet's own height is changed from its handle/header
    // alone (Gary 2026-09-03: 拉上去的时候很怪 — dragging the text flipped the
    // sheet between its heights and threw the reading position away).
    const fromHandle = (target: EventTarget | null) =>
      target instanceof Element && target.closest(".modal__grab, .modal__head") !== null;
    const onStart = (e: TouchEvent) => {
      if (!sheet() || closingRef.current) return;
      if (!dismissibleRef.current && !expandableRef.current) return;
      if (expandableRef.current) {
        if (!fromHandle(e.target)) return;
      } else if (shell.scrollTop > 0) {
        return;
      }
      const t = e.touches[0]!;
      startY = lastY = t.clientY;
      startT = lastT = Date.now();
      dy = 0;
      dragging = true;
    };
    const onMove = (e: TouchEvent) => {
      if (!dragging) return;
      const t = e.touches[0]!;
      dy = t.clientY - startY;
      lastY = t.clientY;
      lastT = Date.now();
      // Upward on a part-height reading sheet: the gesture grows the sheet on
      // release, so nothing is dragged here — the content keeps its scroll.
      if (dy < 0) {
        if (!(expandableRef.current && detentRef.current === "medium")) dy = 0;
        return;
      }
      if (!expandableRef.current && shell.scrollTop > 0) return;
      if (e.cancelable) e.preventDefault(); // the sheet moves, not its content
      shell.dataset.dragging = "";
      shell.style.transform = `translateY(${dy}px)`;
      overlay.style.opacity = String(Math.max(0.2, 1 - dy / 480));
    };
    const onEnd = () => {
      if (!dragging) return;
      dragging = false;
      delete shell.dataset.dragging;
      const dt = Math.max(1, Date.now() - lastT + (lastT - startT) * 0);
      const velocity = (lastY - startY) / Math.max(1, lastT - startT);
      shell.style.transform = "";
      overlay.style.opacity = "";
      if (expandableRef.current && dy <= -EXPAND_PX && detentRef.current === "medium") {
        setDetent("large");
        void dt;
        return;
      }
      if (dy >= DISMISS_PX || velocity > DISMISS_VELOCITY) {
        // From full height a pull down settles back to the reading height;
        // from the reading height it dismisses.
        if (expandableRef.current && detentRef.current === "large") setDetent("medium");
        else requestClose();
      }
      void dt;
    };
    shell.addEventListener("touchstart", onStart, { passive: true });
    shell.addEventListener("touchmove", onMove, { passive: false });
    shell.addEventListener("touchend", onEnd, { passive: true });
    shell.addEventListener("touchcancel", onEnd, { passive: true });
    return () => {
      shell.removeEventListener("touchstart", onStart);
      shell.removeEventListener("touchmove", onMove);
      shell.removeEventListener("touchend", onEnd);
      shell.removeEventListener("touchcancel", onEnd);
    };
  }, [requestClose]);

  return createPortal(
    <div
      ref={overlayRef}
      className={closing ? "modal-overlay modal-overlay--closing" : "modal-overlay"}
      onClick={requestClose}
    >
      <div
        className={[
          "modal",
          closing ? "modal--closing" : "",
          expandable ? `modal--sheet modal--sheet-${detent}` : "",
        ]
          .filter(Boolean)
          .join(" ")}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        aria-describedby={describedBy}
        ref={shellRef}
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Handle + title are one block: on a reading sheet it stays at the
            top while the text scrolls UNDER it, so it must be opaque across
            the whole width (Gary 2026-09-03). */}
        <div className="modal__sticky">
          {expandable ? (
            <button
              type="button"
              className="modal__grab modal__grab--control"
              aria-label={detent === "medium" ? "Expand" : "Collapse"}
              onClick={() => setDetent((d) => (d === "medium" ? "large" : "medium"))}
            />
          ) : (
            <span className="modal__grab" aria-hidden="true" />
          )}
          <div className="modal__head">
            <h2 className="modal__title">{title}</h2>
            {dismissible && (
              <button className="modal__close" onClick={requestClose} aria-label="Close">
                &times;
              </button>
            )}
          </div>
        </div>
        {children}
      </div>
    </div>,
    document.body,
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
    <Modal title={title} onClose={onClose} describedBy="confirm-dialog-body">
      <p className="muted" id="confirm-dialog-body">
        {body}
      </p>
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
