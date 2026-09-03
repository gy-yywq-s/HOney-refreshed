// 12-word recovery phrase (spec §37): a random 128-bit secret encoded with a
// fixed 2048-word list and a 4-bit checksum — the BIP-39 English encoding,
// via @scure/bip39. The words are recovery material, never a user password;
// the secret only wraps R (wrappers.ts).

import { entropyToMnemonic, mnemonicToEntropy, validateMnemonic } from "@scure/bip39";
import { wordlist } from "@scure/bip39/wordlists/english.js";
import { randomBytes } from "./bytes.js";

export const RECOVERY_WORDS = 12;

export function newRecoverySecret(): Uint8Array {
  return randomBytes(16);
}

export function secretToWords(secret: Uint8Array): string[] {
  if (secret.length !== 16) throw new Error("recovery secret must be 16 bytes");
  return entropyToMnemonic(secret, wordlist).split(" ");
}

/** Normalizes whitespace and case; null when the words or the checksum are wrong. */
export function wordsToSecret(input: string | string[]): Uint8Array | null {
  const words = (Array.isArray(input) ? input.join(" ") : input).toLowerCase().trim().split(/\s+/).filter(Boolean);
  if (words.length !== RECOVERY_WORDS) return null;
  const phrase = words.join(" ");
  if (!validateMnemonic(phrase, wordlist)) return null;
  return mnemonicToEntropy(phrase, wordlist);
}

export function isRecoveryWord(word: string): boolean {
  return wordlist.includes(word.toLowerCase().trim());
}

export const RECOVERY_WORDLIST: readonly string[] = wordlist;
