import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon-h.png", "icon-180.png", "icon-192.png", "icon-512.png"],
      manifest: {
        name: "HOney",
        short_name: "HOney",
        description: "Your school day, with context from students who share it.",
        theme_color: "#ffffff",
        background_color: "#ffffff",
        display: "standalone",
        start_url: "/",
        scope: "/",
        icons: [
          { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any maskable" },
          { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" }
        ]
      },
      workbox: {
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/api\//],
        globPatterns: ["**/*.{js,css,html,png,svg,ico,webmanifest}"],
        runtimeCaching: []
      },
      devOptions: { enabled: false }
    })
  ],
  server: {
    host: "127.0.0.1",
    proxy: {
      "/api": "http://127.0.0.1:8871"
    }
  }
});
