// The blind eligibility issuer (spec §31). HOney Core verifies standing —
// membership, exposure, standalone modes, suspension, rate bounds — and then
// blind-signs a token it can never recognise again. The scope and canonical
// context it verified are PUBLIC METADATA bound into the signature
// (RSAPBSSA), so Community checks them offline with the public key only.
//
// Keys: the private JWK lives in the keys directory (0600), generated once
// by `pnpm --filter @honey/backend issuer:keygen` (safe-prime RSA — minutes).
// The public descriptor is written beside it for the Community process.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { blindSign, canonicalize, fromBase64Url, importIssuerPrivateKey, importIssuerPublicKey, toBase64Url, type EligibilityInfo, type IssuerDescriptor } from "@honey/shared/community-v2";
import { ELIGIBILITY_SUITE } from "@honey/shared/community-v2";

export interface IssuerKeyFile {
  private: JsonWebKey;
  public: { kty: "RSA"; n: string; e: string };
  /** "test" marks the checked-in fixture key; production refuses it. */
  purpose?: string;
}

export function issuerKeyId(pub: { n: string; e: string }): string {
  return toBase64Url(createHash("sha256").update(canonicalize({ e: pub.e, kty: "RSA", n: pub.n })).digest()).slice(0, 16);
}

export class EligibilityIssuer {
  readonly descriptor: IssuerDescriptor;
  private constructor(
    private readonly privateKey: CryptoKey,
    readonly publicKey: CryptoKey,
    descriptor: IssuerDescriptor,
  ) {
    this.descriptor = descriptor;
  }

  static async fromKeyFile(file: IssuerKeyFile, opts: { production: boolean }): Promise<EligibilityIssuer> {
    if (opts.production && file.purpose === "test") {
      throw new Error("the test issuer key cannot be used in production — run issuer:keygen");
    }
    const privateKey = await importIssuerPrivateKey(file.private);
    const publicKey = await importIssuerPublicKey(file.public);
    const descriptor: IssuerDescriptor = {
      suite: ELIGIBILITY_SUITE,
      keyId: issuerKeyId(file.public),
      publicKey: { kty: "RSA", n: file.public.n, e: file.public.e, alg: "PS384" },
    };
    return new EligibilityIssuer(privateKey, publicKey, descriptor);
  }

  /** Load from `<keysDir>/issuer.jwk.json`; null when no key exists yet. */
  static async load(keysDir: string, opts: { production: boolean }): Promise<EligibilityIssuer | null> {
    const path = join(keysDir, "issuer.jwk.json");
    if (!existsSync(path)) return null;
    const file = JSON.parse(readFileSync(path, "utf8")) as IssuerKeyFile;
    const issuer = await EligibilityIssuer.fromKeyFile(file, opts);
    // The public half, for the Community process (never the private key).
    mkdirSync(keysDir, { recursive: true });
    writeFileSync(join(keysDir, "issuer.public.json"), JSON.stringify(issuer.descriptor, null, 2) + "\n");
    return issuer;
  }

  async sign(blindedMessage: string, info: EligibilityInfo): Promise<string> {
    const blinded = fromBase64Url(blindedMessage);
    if (blinded.length !== 256) throw new Error("blinded_message_invalid");
    return toBase64Url(await blindSign(this.privateKey, blinded, info));
  }
}
