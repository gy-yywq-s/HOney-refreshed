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
