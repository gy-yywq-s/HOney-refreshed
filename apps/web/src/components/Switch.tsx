// The one switch (review v1.1 §17.5): a role="switch" button, styled in
// features.css (.switch). Shared by Settings and Dash.

export function Switch({ on, label, disabled, onChange }: { on: boolean; label: string; disabled?: boolean; onChange: (next: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      className="switch"
      disabled={disabled}
      onClick={() => onChange(!on)}
    >
      <span className="switch__knob" />
    </button>
  );
}
