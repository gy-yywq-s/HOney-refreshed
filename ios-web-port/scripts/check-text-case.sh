#!/usr/bin/env bash
# No small caps, no forced uppercase (fidelity spec v2 §3.8): production
# SwiftUI sources may not transform case. Every remaining occurrence must
# carry `case-allowed:` on the same line with the reason the CONTENT itself
# is uppercase (a letter landmark, a code).
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
while IFS= read -r line; do
  if ! grep -q "case-allowed:" <<<"$line"; then
    echo "uppercase transform without an allowance: $line"
    status=1
  fi
done < <(grep -rn --include='*.swift' -E '\.textCase\(\.uppercase\)|\.smallCaps\(\)|\.uppercased\(\)|\.lowercaseSmallCaps\(\)' HOneyNative || true)
if [ "$status" -eq 0 ]; then echo "text-case gate: clean"; fi
exit "$status"
