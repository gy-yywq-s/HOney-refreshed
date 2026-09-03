// Line glyphs for toolbar controls and affordances — 24-unit grid, drawn
// with currentColor so they take the control's own ink. Decorative only:
// every use carries its text in an aria-label or a visible label.

interface IconProps {
  size?: number;
}

function Glyph({ size = 20, children }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

export function SearchIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </Glyph>
  );
}

export function PenIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
    </Glyph>
  );
}

export function BookmarkIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="M6 3h12v18l-6-4-6 4Z" />
    </Glyph>
  );
}

export function ChevronRightIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="m9 5 7 7-7 7" />
    </Glyph>
  );
}

/** A plain chevron (no stem) — the fold/unfold glyph. */
export function ChevronDownIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="m5 9 7 7 7-7" />
    </Glyph>
  );
}

export function ChevronUpIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="m5 15 7-7 7 7" />
    </Glyph>
  );
}

export function CloseIcon(p: IconProps) {
  return (
    <Glyph {...p}>
      <path d="M6 6l12 12M18 6 6 18" />
    </Glyph>
  );
}
