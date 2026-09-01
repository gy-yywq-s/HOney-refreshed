// Appearance controls — surface swatch grid + ui-font segmented control.
// Used twice: in the topbar's appearance dialog and mirrored as a section on
// the Settings page. Choices apply instantly (with a crossfade) and persist.

import { useState } from "react";
import {
  SURFACE_OPTIONS,
  UI_FONT_OPTIONS,
  getSurface,
  getUiFont,
  setSurface,
  setUiFont,
} from "../lib/theme";
import type { Surface, UiFont } from "../lib/theme";
import { Modal } from "./Modal";

export function ThemeControls() {
  const [surface, setSurfaceState] = useState<Surface>(() => getSurface());
  const [uiFont, setUiFontState] = useState<UiFont>(() => getUiFont());

  function chooseSurface(next: Surface) {
    setSurface(next);
    setSurfaceState(next);
  }

  function chooseUiFont(next: UiFont) {
    setUiFont(next);
    setUiFontState(next);
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
      <section className="theme-dialog__section">
        <h3>Font</h3>
        <div className="segmented" role="group" aria-label="Font">
          {UI_FONT_OPTIONS.map((option) => (
            <button
              key={option.value}
              type="button"
              aria-pressed={uiFont === option.value}
              title={option.hint}
              onClick={() => chooseUiFont(option.value)}
            >
              {option.label}
            </button>
          ))}
        </div>
      </section>
      <p className="caption" style={{ marginBottom: 0 }}>
        Saved on this device and applied before the page paints.
      </p>
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
