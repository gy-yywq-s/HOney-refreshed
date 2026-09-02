// Appearance controls — the four background surfaces (Gary's own choice).
// The ui-font axis is gone (one humanist sans — web-lab round 2). Used in the
// rail's appearance dialog and mirrored on Settings; applies instantly with
// a crossfade and persists.

import { useState } from "react";
import { SURFACE_OPTIONS, getSurface, setSurface } from "../lib/theme";
import type { Surface } from "../lib/theme";
import { Modal } from "./Modal";

export function ThemeControls() {
  const [surface, setSurfaceState] = useState<Surface>(() => getSurface());

  function chooseSurface(next: Surface) {
    setSurface(next);
    setSurfaceState(next);
  }

  return (
    <div>
      <section className="theme-dialog__section">
        <h3>Background</h3>
        <div className="option-grid four" role="group" aria-label="Background surface">
          {SURFACE_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              aria-pressed={surface === option.value}
              onClick={() => chooseSurface(option.value)}
            >
              <i className={`swatch swatch--${option.value}`} aria-hidden="true" />
              <strong>{option.label}</strong>
            </button>
          ))}
        </div>
      </section>
      <p className="caption" style={{ marginBottom: 0 }} id="appearance-dialog-body">
        Saved on this device and applied before the page paints.
      </p>
    </div>
  );
}

export function ThemeDialog({ onClose }: { onClose: () => void }) {
  return (
    <Modal title="Appearance" onClose={onClose} describedBy="appearance-dialog-body">
      <ThemeControls />
    </Modal>
  );
}
