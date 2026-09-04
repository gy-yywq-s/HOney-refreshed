// RFC 8785 JSON Canonicalization Scheme (JCS): the bytes every signature in
// the v2 protocol is computed over, on Web and iOS alike. Object members are
// sorted by UTF-16 code units, no whitespace, strings and numbers serialized
// exactly as ES JSON.stringify does (which is what RFC 8785 specifies).
// `undefined` members are omitted; non-finite numbers are rejected.

import { utf8 } from "./bytes.js";

export type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };

export function canonicalize(value: JsonValue | undefined): string {
  if (value === undefined) throw new Error("undefined is not a JSON value");
  if (value === null || typeof value === "boolean" || typeof value === "string") return JSON.stringify(value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("non-finite number");
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map((v) => canonicalize(v)).join(",")}]`;
  const keys = Object.keys(value)
    .filter((k) => value[k] !== undefined)
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalize(value[k])}`).join(",")}}`;
}

export function canonicalBytes(value: JsonValue): Uint8Array {
  return utf8(canonicalize(value));
}
