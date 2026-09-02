// Theme (appearance) state — the four selectable surfaces (Gary's own
// choice, kept), persisted in localStorage and applied as a data-attribute
// on <html>. The inline script in index.html applies the saved value BEFORE
// first paint. The ui-font axis is gone (web-lab round 2: one humanist sans
// voice — the type is no longer a playground).

export type Surface = "stone" | "white" | "mist" | "night";

export const SURFACE_KEY = "honey.theme.surface";

export const DEFAULT_SURFACE: Surface = "stone";

export const SURFACE_OPTIONS: { value: Surface; label: string }[] = [
  { value: "stone", label: "Stone" },
  { value: "white", label: "White" },
  { value: "mist", label: "Mist" },
  { value: "night", label: "Night" },
];

/** theme-color per surface — keep in sync with the boot script in index.html. */
const THEME_COLORS: Record<Surface, string> = {
  stone: "#f4f6f7",
  white: "#ffffff",
  mist: "#eef2f2",
  night: "#14171a",
};

export function normalizeSurface(value: string | null | undefined): Surface {
  return value === "stone" || value === "white" || value === "mist" || value === "night"
    ? value
    : DEFAULT_SURFACE;
}

function read(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Private mode etc. — the choice just won't persist.
  }
}

export function getSurface(): Surface {
  if (typeof document !== "undefined" && document.documentElement.dataset.surface) {
    return normalizeSurface(document.documentElement.dataset.surface);
  }
  return normalizeSurface(read(SURFACE_KEY));
}

let fadeTimer: ReturnType<typeof setTimeout> | null = null;

/** Runs a theme mutation inside a ~400ms whole-surface crossfade. */
function withCrossfade(mutate: () => void): void {
  const root = document.documentElement;
  const reduced =
    typeof matchMedia !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced) {
    mutate();
    return;
  }
  root.classList.add("theme-anim");
  mutate();
  if (fadeTimer) clearTimeout(fadeTimer);
  fadeTimer = setTimeout(() => {
    root.classList.remove("theme-anim");
    fadeTimer = null;
  }, 450);
}

export function setSurface(surface: Surface): void {
  withCrossfade(() => {
    document.documentElement.dataset.surface = surface;
  });
  write(SURFACE_KEY, surface);
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", THEME_COLORS[surface]);
}

/* ── Accent schemes (Settings → Accent, Gary 2026-09-02) ────────────────
   A second axis, separate from the background. Each value is a SCHEME —
   accent, tint, on-accent ink, night lift — defined in tokens.css; the
   default (Harbour) is the base tokens, so it carries no attribute. */

export type Accent = "harbour" | "cobalt" | "moss" | "clay" | "plum" | "iris" | "amber";

export const ACCENT_KEY = "honey.theme.accent";
export const DEFAULT_ACCENT: Accent = "harbour";

/** Swatch colours: the light accent of each scheme (see tokens.css). */
export const ACCENT_OPTIONS: { value: Accent; label: string; swatch: string; night: string }[] = [
  { value: "harbour", label: "Harbour", swatch: "#33667c", night: "#8fc2d4" },
  { value: "cobalt", label: "Cobalt", swatch: "#3b5d9c", night: "#9db9ed" },
  { value: "moss", label: "Moss", swatch: "#43694b", night: "#9fc4a5" },
  { value: "clay", label: "Clay", swatch: "#7e5340", night: "#daae9a" },
  { value: "plum", label: "Plum", swatch: "#745170", night: "#cfaccb" },
  { value: "iris", label: "Iris", swatch: "#5e5981", night: "#b8b3dd" },
  { value: "amber", label: "Amber", swatch: "#725b32", night: "#cdb58e" },
];

export function normalizeAccent(value: string | null | undefined): Accent {
  return ACCENT_OPTIONS.some((o) => o.value === value) ? (value as Accent) : DEFAULT_ACCENT;
}

export function getAccent(): Accent {
  if (typeof document !== "undefined" && document.documentElement.dataset.accent) {
    return normalizeAccent(document.documentElement.dataset.accent);
  }
  return normalizeAccent(read(ACCENT_KEY));
}

export function setAccent(accent: Accent): void {
  withCrossfade(() => {
    if (accent === DEFAULT_ACCENT) delete document.documentElement.dataset.accent;
    else document.documentElement.dataset.accent = accent;
  });
  write(ACCENT_KEY, accent);
}
