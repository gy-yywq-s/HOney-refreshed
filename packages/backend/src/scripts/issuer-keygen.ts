// `pnpm --filter @honey/backend issuer:keygen` — generate the deployment's
// blind-eligibility issuer key (RSAPBSSA, 2048-bit, safe primes). The two
// safe primes come from OpenSSL (`openssl prime -generate -safe`), which
// takes seconds; only key ASSEMBLY happens here (n, d, dp, dq, qi). The key
// is imported through WebCrypto and round-tripped through the library's
// blind → sign → finalize → verify before it is written. Run it once with the
// service environment loaded (HONEY_KEYS_DIR). Refuses to overwrite.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { RSAPBSSA } from "@cloudflare/blindrsa-ts";
import { loadConfig } from "../config.js";
import { issuerKeyId, type IssuerKeyFile } from "../community-issuer/issuer.js";

const config = loadConfig();
mkdirSync(config.keysDir, { recursive: true, mode: 0o700 });
const path = join(config.keysDir, "issuer.jwk.json");
if (existsSync(path)) {
  console.error(`${path} already exists — move it away first if you really mean to rotate the issuer key.`);
  process.exit(2);
}

function safePrime(bits: number): bigint {
  return BigInt(execFileSync("openssl", ["prime", "-generate", "-safe", "-bits", String(bits)], { encoding: "utf8" }).trim());
}

function modInverse(a: bigint, m: bigint): bigint {
  let [oldR, r] = [a % m, m];
  let [oldS, s] = [1n, 0n];
  while (r !== 0n) {
    const q = oldR / r;
    [oldR, r] = [r, oldR - q * r];
    [oldS, s] = [s, oldS - q * s];
  }
  if (oldR !== 1n) throw new Error("not invertible");
  return ((oldS % m) + m) % m;
}

function b64u(n: bigint, len?: number): string {
  let hex = n.toString(16);
  if (hex.length % 2) hex = "0" + hex;
  let buf = Buffer.from(hex, "hex");
  if (len && buf.length < len) buf = Buffer.concat([Buffer.alloc(len - buf.length), buf]);
  return buf.toString("base64url");
}

const started = Date.now();
let p = safePrime(1024);
let q = safePrime(1024);
while (p === q) q = safePrime(1024);
if (p < q) [p, q] = [q, p];
const e = 65537n;
const n = p * q;
const d = modInverse(e, (p - 1n) * (q - 1n));
const priv: JsonWebKey = {
  kty: "RSA", alg: "PS384", ext: true, key_ops: ["sign"],
  n: b64u(n, 256), e: b64u(e), d: b64u(d, 256), p: b64u(p, 128), q: b64u(q, 128),
  dp: b64u(d % (p - 1n), 128), dq: b64u(d % (q - 1n), 128), qi: b64u(modInverse(q, p), 128),
};
const file: IssuerKeyFile = { private: priv, public: { kty: "RSA", n: priv.n!, e: priv.e! }, purpose: "deployment" };

// Self-check through the library before anything is written.
const subtle = globalThis.crypto.subtle;
const privateKey = await subtle.importKey("jwk", priv, { name: "RSA-PSS", hash: "SHA-384" }, true, ["sign"]);
const publicKey = await subtle.importKey("jwk", { ...file.public, alg: "PS384", ext: true }, { name: "RSA-PSS", hash: "SHA-384" }, true, ["verify"]);
const suite = RSAPBSSA.SHA384.PSS.Randomized();
const info = new TextEncoder().encode("self-check");
const msg = suite.prepare(new TextEncoder().encode("nonce"));
const { blindedMsg, inv } = await suite.blind(publicKey, msg, info);
const sig = await suite.finalize(publicKey, msg, info, await suite.blindSign(privateKey, blindedMsg, info), inv);
if (!(await suite.verify(publicKey, sig, msg, info)) || (await suite.verify(publicKey, sig, msg, new TextEncoder().encode("other")))) {
  throw new Error("issuer key self-check failed");
}
writeFileSync(path, JSON.stringify(file), { mode: 0o600 });
console.log(`wrote ${path} (key id ${issuerKeyId(file.public)}) in ${Math.round((Date.now() - started) / 1000)}s`);
