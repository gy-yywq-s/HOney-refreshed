import React from "react";
import { createRoot } from "react-dom/client";
import { api } from "./api/client";
// Self-hosted variable webfont (@fontsource) — no runtime font CDN. One
// humanist sans everywhere (web-lab round 2, candidate A): the content has
// the personality; the interface doesn't perform (review v3 §5.5.1).
import "@fontsource-variable/source-sans-3";
import "./styles/tokens.css";
import "./styles/foundations.css";
import "./styles/components.css";
import "./styles/features.css";
import "./styles/admin.css";

async function bootstrap() {
  const authenticated = api.hasSession();
  if (authenticated && window.location.pathname === "/login") {
    window.history.replaceState(null, "", "/home");
  } else if (!authenticated && window.location.pathname !== "/login") {
    window.history.replaceState(null, "", "/login");
  }

  // Keep the calm public doorway out of the authenticated Ionic shell. A
  // signed-out visit now downloads React + the login flow, not the entire
  // Ionic navigation/overlay runtime. Successful login performs one clean
  // document transition into the installed-app shell.
  const Root = authenticated
    ? (await import("./App")).App
    : (await import("./PublicApp")).PublicApp;

  const el = document.getElementById("root");
  if (el) {
    createRoot(el).render(
      <React.StrictMode>
        <Root />
      </React.StrictMode>,
    );
  }
}

void bootstrap();

// PWA: one small service worker (see public/sw.js). Registered after load so
// it never competes with first paint; scope "/" keeps every route inside the
// installed app on iOS and Android.
if ("serviceWorker" in navigator && !import.meta.env.DEV) {
  window.addEventListener("load", () => {
    void navigator.serviceWorker.register("/sw.js");
  });
}
