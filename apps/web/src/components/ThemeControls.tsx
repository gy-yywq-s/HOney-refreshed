// Appearance controls — the background surfaces (Gary's own four) and,
// separately, the accent scheme (Gary 2026-09-02: more accent choices, on
// their own axis; each one a scheme — accent, tint, ink on it, night lift —
// never a single colour). Used in the rail's appearance dialog and mirrored
// on Settings; applies instantly with a crossfade and persists.

import { useState } from "react";
import { ACCENT_OPTIONS, SURFACE_OPTIONS, getAccent, getSurface, setAccent, setSurface } from "../lib/theme";
import type { Accent, Surface } from "../lib/theme";
import { Modal } from "./Modal";

export function ThemeControls() {
  const [surface, setSurfaceState] = useState<Surface>(() => getSurface());
  const [accent, setAccentState] = useState<Accent>(() => getAccent());

  function chooseSurface(next: Surface) {
    setSurface(next);
    setSurfaceState(next);
  }
  function chooseAccent(next: Accent) {
    setAccent(next);
    setAccentState(next);
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
              className="option"
              aria-pressed={surface === option.value}
              onClick={() => chooseSurface(option.value)}
            >
              <i className={`swatch swatch--${option.value}`} aria-hidden="true" />
              <strong>{option.label}</strong>
            </button>
          ))}
        </div>
      </section>
      <section className="theme-dialog__section">
        <h3>Accent</h3>
        <div className="option-grid three" role="group" aria-label="Accent scheme">
          {ACCENT_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              className="option"
              aria-pressed={accent === option.value}
              onClick={() => chooseAccent(option.value)}
            >
              <i
                className="swatch swatch--accent"
                style={{ background: surface === "night" ? option.night : option.swatch }}
                aria-hidden="true"
              />
              <strong>{option.label}</strong>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

export function ThemeDialog({ onClose }: { onClose: () => void }) {
  return (
    <Modal title="Appearance" onClose={onClose}>
      <ThemeControls />
    </Modal>
  );
}
