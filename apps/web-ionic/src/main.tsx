import React from "react";
import { createRoot } from "react-dom/client";
import { setupIonicReact } from "@ionic/react";
import { App } from "./App";
// Self-hosted variable webfont (@fontsource) — no runtime font CDN. One
// humanist sans everywhere (web-lab round 2, candidate A): the content has
// the personality; the interface doesn't perform (review v3 §5.5.1).
import "@fontsource-variable/source-sans-3";
import "@ionic/react/css/core.css";
import "@ionic/react/css/normalize.css";
import "@ionic/react/css/structure.css";
import "@ionic/react/css/typography.css";
import "./styles/tokens.css";
import "./styles/foundations.css";
import "./styles/components.css";
import "./styles/features.css";
import "./styles/admin.css";
import "./styles/ionic.css";

// Ionic owns navigation, route/overlay lifecycle, safe areas, and every
// screen's scroll container. HOney's leaf presentation stays custom.
setupIonicReact({ mode: "md", swipeBackEnabled: true });

const el = document.getElementById("root");
if (el) {
  createRoot(el).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  );
}

// PWA: one small service worker (see public/sw.js). Registered after load so
// it never competes with first paint; scope "/" keeps every route inside the
// installed app on iOS and Android.
if ("serviceWorker" in navigator && !import.meta.env.DEV) {
  window.addEventListener("load", () => {
    void navigator.serviceWorker.register("/sw.js");
  });
}
