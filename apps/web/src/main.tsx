import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
// Self-hosted variable webfont (@fontsource) — no runtime font CDN. One
// humanist sans everywhere (web-lab round 2, candidate A): the content has
// the personality; the interface doesn't perform (review v3 §5.5.1).
import "./styles/fonts.css";
import "./styles/tokens.css";
import "./styles/foundations.css";
import "./styles/components.css";
import "./styles/features.css";
import "./styles/admin.css";

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
