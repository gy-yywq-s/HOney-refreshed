// Theme (appearance) state — selectable surface + ui-font, persisted in
// localStorage and applied as data-attributes on <html>. The inline script in
// index.html applies the saved values BEFORE first paint; this module is the
// runtime side: reading, switching (with a whole-surface crossfade) and the
// theme-color meta.

export type Surface = "stone" | "white" | "mist" | "night";
export type UiFont = "grotesk" | "neutral" | "editorial";

export const SURFACE_KEY = "honey.theme.surface";
export const UI_FONT_KEY = "honey.theme.uiFont";

export const DEFAULT_SURFACE: Surface = "stone";
export const DEFAULT_UI_FONT: UiFont = "grotesk";

export const SURFACE_OPTIONS: { value: Surface; label: string }[] = [
  { value: "stone", label: "Stone" },
  { value: "white", label: "White" },
  { value: "mist", label: "Mist" },
  { value: "night", label: "Night" },
];

export const UI_FONT_OPTIONS: { value: UiFont; label: string; hint: string }[] = [
  { value: "grotesk", label: "Grotesk", hint: "Space Grotesk" },
  { value: "neutral", label: "Neutral", hint: "System" },
  { value: "editorial", label: "Editorial", hint: "Fraunces heads" },
];

/** theme-color per surface — keep in sync with the boot script in index.html. */
const THEME_COLORS: Record<Surface, string> = {
  stone: "#edf0f1",
  white: "#ffffff",
  mist: "#e7eeec",
  night: "#14171a",
};

export function normalizeSurface(value: string | null | undefined): Surface {
  return value === "stone" || value === "white" || value === "mist" || value === "night"
    ? value
    : DEFAULT_SURFACE;
}

export function normalizeUiFont(value: string | null | undefined): UiFont {
  return value === "grotesk" || value === "neutral" || value === "editorial"
    ? value
    : DEFAULT_UI_FONT;
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

export function getUiFont(): UiFont {
  if (typeof document !== "undefined" && document.documentElement.dataset.uiFont) {
    return normalizeUiFont(document.documentElement.dataset.uiFont);
  }
  return normalizeUiFont(read(UI_FONT_KEY));
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

export function setUiFont(font: UiFont): void {
  withCrossfade(() => {
    document.documentElement.dataset.uiFont = font;
  });
  write(UI_FONT_KEY, font);
}
