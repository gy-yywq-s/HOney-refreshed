import { expect, test, type Page } from "@playwright/test";

async function openFixture(page: Page, path = "/") {
  await page.goto(`${path}${path.includes("?") ? "&" : "?"}demo=1`);
  await expect(page.getByText("Fixture data · not live")).toBeVisible();
}

test("boots, fits regular-height Home, and navigates to Experiences", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openFixture(page);
  await expect(page.getByRole("heading", { name: /Hi, Gary/ })).toBeVisible();

  const dimensions = await page.evaluate(() => ({
    rootWidth: document.documentElement.scrollWidth,
    rootHeight: document.documentElement.scrollHeight,
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
  }));
  expect(dimensions.rootWidth).toBeLessThanOrEqual(dimensions.viewportWidth);
  expect(dimensions.rootHeight).toBeLessThanOrEqual(dimensions.viewportHeight);

  await page.getByRole("tab", { name: "Experiences" }).click();
  await expect(page.getByRole("heading", { name: "Experiences" })).toBeVisible();
});

test("Experiences owns its framed scroll and restores it across Explore", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openFixture(page, "/experiences");
  await expect(page.locator('[data-scroll-owner="experiences-feed"]')).toBeVisible();

  const rootDoesNotScroll = await page.evaluate(() =>
    document.documentElement.scrollHeight <= window.innerHeight &&
    document.documentElement.scrollWidth <= window.innerWidth,
  );
  expect(rootDoesNotScroll).toBe(true);

  const content = page.locator("ion-content.feed-scroll");
  await content.evaluate(async (node: HTMLIonContentElement) => {
    const scroller = await node.getScrollElement();
    scroller.scrollTop = 420;
  });
  const before = await content.evaluate(async (node: HTMLIonContentElement) => (await node.getScrollElement()).scrollTop);

  await page.getByRole("link", { name: "Explore" }).click();
  await expect(page.getByRole("heading", { name: "Find something at school" })).toBeVisible();
  await page.goBack();
  await expect(page.getByRole("heading", { name: "Experiences" })).toBeVisible();
  const after = await page.locator("ion-content.feed-scroll").evaluate(async (node: HTMLIonContentElement) => (await node.getScrollElement()).scrollTop);
  expect(Math.abs(after - before)).toBeLessThan(80);
});

test("Explore search narrows directory entities", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openFixture(page, "/experiences/explore");
  await page.getByPlaceholder("Find teachers, courses, places, or food").fill("Ms Lin");
  await expect(page.getByText("Ms Lin", { exact: true })).toBeVisible();
  await expect(page.getByText("Mr Chen", { exact: true })).toHaveCount(0);
});

test("Compose accepts a context and shows ordered moderation", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openFixture(page, "/experiences/compose");
  await page.getByText("Ms Lin", { exact: true }).click();
  await page.getByText("Fixture moderation scenarios").click();
  await page.getByRole("button", { name: "Revision" }).click();
  await page.getByRole("button", { name: "Share anonymously" }).click();
  await expect(page.getByRole("heading", { name: "This version needs a change before it can be shared." })).toBeVisible();
  await expect(page.getByRole("button", { name: "Return to your words" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Keep private" })).toBeVisible();
});

test("Timetable to lesson to lesson-bound Compose is a real route transition", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await openFixture(page, "/timetable");
  await page.getByText("Further Mathematics", { exact: true }).first().click();
  await expect(page.getByRole("heading", { name: "Further Mathematics" })).toBeVisible();
  await page.getByRole("link", { name: "Share what this was like" }).click();
  await expect(page.getByRole("heading", { name: "What was it like for you?" })).toBeVisible();
  await expect(page.getByText(/Further Mathematics · Ms Lin/)).toBeVisible();
});

test("login submits password-manager autofill even when IonInput state did not update", async ({ page }) => {
  await page.route("**/api/auth/login", async (route) => {
    await route.fulfill({
      status: 401,
      contentType: "application/json",
      body: JSON.stringify({ error: "school_credentials_rejected" }),
    });
  });
  await page.goto("/login");

  // Model password-manager autofill: native values change without input or
  // ionInput events, leaving React's controlled state untouched.
  await page.locator("#school-username input").evaluate((input: HTMLInputElement) => { input.value = "autofilled-user"; });
  await page.locator("#school-password input").evaluate((input: HTMLInputElement) => { input.value = "autofilled-password"; });
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page.getByRole("alert")).toContainText("rejected that username or password");
});

test("declining timetable import enters the account instead of looping to consent", async ({ page }) => {
  await page.goto("/consent?demo=1");
  await page.getByRole("button", { name: "Not now" }).click();

  await expect(page).toHaveURL(/\/home/);
  await expect(page.getByRole("heading", { name: /Hi, Gary/ })).toBeVisible();
});

test("successful sign-in transitions into the app shell without a reload", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const session = {
    accessToken: "test-access",
    accessExpiresAt: "2099-01-01T00:00:00.000Z",
    refreshToken: "test-refresh",
    refreshExpiresAt: "2099-02-01T00:00:00.000Z",
  };
  await page.route("**/api/auth/login", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ honeyId: "h-test", displayName: "Route Test", created: false, isAdmin: false, consent: { timetable: true }, session }),
  }));
  await page.route("**/api/me", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({ honeyId: "h-test", displayName: "Route Test", isAdmin: false, consent: { timetable: true, grantedAt: null }, connection: { connected: true, lastSyncedAt: null, portalTokenValid: true } }),
  }));
  await page.route("**/api/next-lesson", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ nextLesson: null, lastSyncedAt: null }) }));
  await page.route("**/api/experiences/feed**", (route) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ items: [], nextCursor: null }) }));

  await page.goto("/login");
  await page.locator("#school-username input").fill("route-test");
  await page.locator("#school-password input").fill("route-test");
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page).toHaveURL(/\/home/);
  await expect(page.getByRole("heading", { name: "Hi, Route Test" })).toBeVisible();
  await expect(page.locator(".login-form")).toHaveCount(0);
});
