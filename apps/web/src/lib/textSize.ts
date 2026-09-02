// Text size (Gary 2026-09-02): four steps applied as one scale on the type
// ramp (tokens.css `--text-scale`), persisted and applied before first paint
// by the index.html boot script, like the surface.

import { useSyncExternalStore } from "react";

export type TextSize = "small" | "default" | "large" | "larger";
export const TEXT_SIZE_KEY = "honey.textsize";
export const TEXT_SIZES: TextSize[] = ["small", "default", "large", "larger"];
const listeners = new Set<() => void>();

export function getTextSize(): TextSize {
  try {
    const v = localStorage.getItem(TEXT_SIZE_KEY);
    return (TEXT_SIZES as string[]).includes(v ?? "") ? (v as TextSize) : "default";
  } catch {
    return "default";
  }
}

export function applyTextSize(size: TextSize = getTextSize()): void {
  if (typeof document === "undefined") return;
  if (size === "default") delete document.documentElement.dataset.textsize;
  else document.documentElement.dataset.textsize = size;
}

export function setTextSize(size: TextSize): void {
  try {
    localStorage.setItem(TEXT_SIZE_KEY, size);
  } catch {
    /* ignore */
  }
  applyTextSize(size);
  listeners.forEach((l) => l());
}

function subscribe(l: () => void): () => void {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function useTextSize(): TextSize {
  return useSyncExternalStore(subscribe, getTextSize, () => "default" as TextSize);
}
