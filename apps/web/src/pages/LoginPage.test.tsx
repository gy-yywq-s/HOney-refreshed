// @vitest-environment jsdom
//
// Regression pin for review 2026-09-01 finding 3: after a fresh sign-in the
// import-consent step must actually be reachable. The bug: tokens are stored
// synchronously by api.login, so any state update before setPhase("consent")
// re-renders LoginPage while phase is still "signin", and the hasSession()
// guard redirects to /home — silently skipping the §3.2 consent choice.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import type { LoginResponse } from "../api/types";

const state = { hasSession: false, consentTimetable: false };

vi.mock("../api/client", () => ({
  api: {
    hasSession: () => state.hasSession,
    login: vi.fn(async (): Promise<LoginResponse> => {
      // Mirrors the real client: tokens are stored before the caller resumes.
      state.hasSession = true;
      return {
        honeyId: "abc123",
        displayName: "Test Student",
        created: true,
        isAdmin: false,
        consent: { timetable: state.consentTimetable },
        session: {
          accessToken: "a",
          accessExpiresAt: "2999-01-01T00:00:00Z",
          refreshToken: "r",
          refreshExpiresAt: "2999-01-01T00:00:00Z",
        },
      };
    }),
    setConsent: vi.fn(async () => undefined),
    sync: vi.fn(async () => ({ status: "ok", lessons: 0, teachers: 0, courses: 0, rooms: 0 })),
  },
  describeApiError: () => "error",
}));

vi.mock("../auth/AuthContext", () => ({
  // refreshMe re-renders consumers in the real app; the mock emulates the
  // async state churn that used to trigger the premature redirect.
  useAuth: () => ({ refreshMe: vi.fn(async () => undefined) }),
}));

import { LoginPage } from "./LoginPage";

let root: Root;
let host: HTMLDivElement;

function renderApp() {
  host = document.createElement("div");
  document.body.appendChild(host);
  root = createRoot(host);
  act(() => {
    root.render(
      <MemoryRouter initialEntries={["/login"]}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/home" element={<div data-testid="home">HOME</div>} />
        </Routes>
      </MemoryRouter>,
    );
  });
}

async function signIn() {
  const form = host.querySelector("form");
  expect(form).not.toBeNull();
  const [user, pass] = Array.from(host.querySelectorAll("input"));
  if (!user || !pass) throw new Error("login inputs not rendered");
  act(() => {
    const set = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      "value",
    )!.set!;
    set.call(user, "student");
    user.dispatchEvent(new Event("input", { bubbles: true }));
    set.call(pass, "pw");
    pass.dispatchEvent(new Event("input", { bubbles: true }));
  });
  await act(async () => {
    form!.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
}

describe("LoginPage first-login consent step (audit §3.2)", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
    state.hasSession = false;
    state.consentTimetable = false;
  });

  it("shows the consent step after a fresh sign-in without consent", async () => {
    renderApp();
    await signIn();
    expect(host.textContent).toContain("One more choice.");
    expect(host.querySelector('[data-testid="home"]')).toBeNull();
  });

  it("skips straight to home when consent was already granted", async () => {
    state.consentTimetable = true;
    renderApp();
    await signIn();
    expect(host.querySelector('[data-testid="home"]')).not.toBeNull();
    expect(host.textContent).not.toContain("One more choice.");
  });
});
