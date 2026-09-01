// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from "vitest";
import { PortalCredentialStore, type StorageLike } from "./portalCredentials";

function memStore(): StorageLike {
  const m = new Map<string, string>();
  return {
    getItem: (k) => m.get(k) ?? null,
    setItem: (k, v) => void m.set(k, v),
    removeItem: (k) => void m.delete(k),
  };
}

describe("PortalCredentialStore", () => {
  let store: PortalCredentialStore;
  let backing: StorageLike;

  beforeEach(() => {
    backing = memStore();
    store = new PortalCredentialStore(backing, globalThis.crypto);
  });

  it("is off until authorized", async () => {
    expect(store.isAuthorized()).toBe(false);
    expect(await store.load()).toBeNull();
  });

  it("round-trips credentials and reports authorized", async () => {
    await store.authorize({ username: "s0088", password: "hunter2" });
    expect(store.isAuthorized()).toBe(true);
    expect(await store.load()).toEqual({ username: "s0088", password: "hunter2" });
  });

  it("never stores the password in plaintext", async () => {
    await store.authorize({ username: "s0088", password: "hunter2" });
    const dump = JSON.stringify([
      backing.getItem("honey.portal.cred"),
      backing.getItem("honey.portal.credKey"),
    ]);
    expect(dump).not.toContain("hunter2");
  });

  it("clear() forgets everything", async () => {
    await store.authorize({ username: "s0088", password: "hunter2" });
    store.clear();
    expect(store.isAuthorized()).toBe(false);
    expect(await store.load()).toBeNull();
  });
});
