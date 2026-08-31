import { describe, expect, it } from "vitest";
import { OwnershipKeyStore, PrivateNoteStore } from "./ownershipKeys";
import type { StorageLike } from "./ownershipKeys";

function memoryStorage(): StorageLike & { dump(): string } {
  const map = new Map<string, string>();
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
    dump: () => [...map.values()].join("\n"),
  };
}

describe("OwnershipKeyStore", () => {
  it("round-trips add/list/remove through versioned JSON", () => {
    const storage = memoryStorage();
    const store = new OwnershipKeyStore(storage);

    expect(store.list()).toEqual([]);
    store.add({ key: "ok-1", experienceId: "e-1" });
    store.add({ key: "ok-2", experienceId: "e-2" });

    const listed = store.list();
    expect(listed.map((k) => k.key)).toEqual(["ok-1", "ok-2"]);
    expect(listed[0]).toMatchObject({ experienceId: "e-1", kind: "public" });
    expect(typeof listed[0]!.createdAt).toBe("number");

    // A fresh store instance over the same storage sees the same keys.
    expect(new OwnershipKeyStore(storage).count()).toBe(2);

    store.remove("ok-1");
    expect(store.list().map((k) => k.key)).toEqual(["ok-2"]);
  });

  it("export/import merges without duplicating keys and rejects junk", () => {
    const a = new OwnershipKeyStore(memoryStorage());
    a.add({ key: "ok-1", experienceId: "e-1" });
    a.add({ key: "ok-2", experienceId: "e-2" });

    const b = new OwnershipKeyStore(memoryStorage());
    b.add({ key: "ok-2", experienceId: "e-2" });

    expect(b.importJson(a.exportJson())).toBe(1); // only ok-1 is new
    expect(b.count()).toBe(2);
    expect(() => b.importJson('{"hello":"world"}')).toThrow();
    expect(b.count()).toBe(2);
  });
});

describe("PrivateNoteStore", () => {
  it("round-trips notes and never stores the body in plaintext", async () => {
    const storage = memoryStorage();
    const store = new PrivateNoteStore(storage);
    const body = "the-canteen-noodles-were-surprisingly-good-today";

    const saved = await store.save({
      body,
      rating: 4,
      target: { label: "Noodles", entityKey: "dish:a_123", entityType: "dish" },
    });
    expect(saved.id).toBeTruthy();

    const listed = await store.list();
    expect(listed).toHaveLength(1);
    expect(listed[0]).toMatchObject({ body, rating: 4 });

    // Encrypted at rest: the plaintext body never appears in storage.
    expect(storage.dump()).not.toContain(body);
    expect(storage.dump()).not.toContain("Noodles");

    // Update in place, then delete.
    await store.save({ id: saved.id, body: "edited", target: saved.target });
    const updated = await store.get(saved.id);
    expect(updated?.body).toBe("edited");
    expect(updated?.createdAt).toBe(saved.createdAt);
    await store.remove(saved.id);
    expect(await store.list()).toEqual([]);
  });
});
