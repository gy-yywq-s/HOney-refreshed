import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
// Self-hosted variable webfonts (@fontsource) — no runtime font CDN.
import "@fontsource-variable/space-grotesk";
import "@fontsource-variable/fraunces/opsz.css";
import "@fontsource-variable/fraunces/opsz-italic.css";
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
