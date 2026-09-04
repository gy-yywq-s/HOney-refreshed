// A choice, in HOney's own sheet (Gary 2026-09-04: iOS's native picker drifts
// the screen — build the menu instead of using it). The trigger says what is
// chosen; the sheet lists EVERY option, with the chosen one marked. No native
// <select>, so no viewport games, and the options can carry a note.

import { useState } from "react";
import { ChevronDownIcon } from "./icons";
import { Modal } from "./Modal";

export interface PickerOption<T extends string> {
  value: T;
  label: string;
  note?: string;
}

export function Picker<T extends string>({
  label,
  value,
  options,
  onChange,
  disabled = false,
}: {
  /** The sheet's title — what is being chosen. */
  label: string;
  value: T;
  options: readonly PickerOption<T>[];
  onChange: (value: T) => void;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const current = options.find((o) => o.value === value);

  return (
    <>
      <button
        type="button"
        className="choice"
        aria-haspopup="dialog"
        aria-label={`${label}: ${current?.label ?? value}`}
        disabled={disabled}
        onClick={() => setOpen(true)}
      >
        <span className="choice__value">{current?.label ?? value}</span>
        <ChevronDownIcon size={16} />
      </button>
      {open && (
        <Modal title={label} onClose={() => setOpen(false)}>
          <div className="choice-options">
            {options.map((o) => (
              <button
                key={o.value}
                type="button"
                className={o.value === value ? "choice-option choice-option--on" : "choice-option"}
                aria-pressed={o.value === value}
                onClick={() => {
                  onChange(o.value);
                  setOpen(false);
                }}
              >
                <span className="choice-option__main">
                  <span className="choice-option__label">{o.label}</span>
                  {o.note && <span className="caption">{o.note}</span>}
                </span>
                {o.value === value && <span className="choice-option__tick" aria-hidden="true">✓</span>}
              </button>
            ))}
          </div>
        </Modal>
      )}
    </>
  );
}
