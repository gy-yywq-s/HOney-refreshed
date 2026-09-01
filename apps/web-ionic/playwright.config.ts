import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  outputDir: "../../output/playwright/test-results",
  reporter: [["list"], ["html", { outputFolder: "../../output/playwright/report", open: "never" }]],
  use: {
    baseURL: "http://127.0.0.1:4174",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: {
    command: "pnpm dev --host 127.0.0.1 --port 4174",
    url: "http://127.0.0.1:4174/?demo=1",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
