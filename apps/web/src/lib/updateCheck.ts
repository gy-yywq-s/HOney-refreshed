// Keep every open instance on the latest build (dev stage, rule 4g: live
// always runs the latest green commit). The app compares its own build id
// with /version.json whenever it comes back into view, and reloads itself
// when they differ — at once when nothing is being typed, otherwise as soon
// as the editing control blurs. Without this, an installed PWA and a Safari
// tab could each keep an older bundle alive for hours.

const CHECK_EVERY_MS = 5 * 60 * 1000;

let pending = false;
let started = false;

function typing(): boolean {
  const el = document.activeElement;
  return !!el && (el.tagName === "TEXTAREA" || el.tagName === "INPUT" || (el as HTMLElement).isContentEditable);
}

function reloadNow(): void {
  void navigator.serviceWorker?.getRegistration().then((r) => r?.update()).catch(() => {});
  window.location.reload();
}

async function check(): Promise<void> {
  if (pending) return;
  try {
    const res = await fetch(`/version.json?_=${Date.now()}`, { cache: "no-store" });
    if (!res.ok) return;
    const { build } = (await res.json()) as { build?: string };
    if (!build || build === __BUILD__) return;
    if (typing()) {
      pending = true;
      document.addEventListener("focusout", () => setTimeout(() => !typing() && reloadNow(), 300), { once: true });
      return;
    }
    reloadNow();
  } catch {
    /* offline or blocked: try again on the next resume */
  }
}

export function startUpdateCheck(): void {
  if (started || typeof window === "undefined") return;
  started = true;
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") void check();
  });
  window.addEventListener("focus", () => void check());
  window.setInterval(() => {
    if (document.visibilityState === "visible") void check();
  }, CHECK_EVERY_MS);
}
