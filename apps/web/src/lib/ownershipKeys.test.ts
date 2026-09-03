import { describe, expect, it } from "vitest";
import { PrivateNoteStore } from "./ownershipKeys";
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
