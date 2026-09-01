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
