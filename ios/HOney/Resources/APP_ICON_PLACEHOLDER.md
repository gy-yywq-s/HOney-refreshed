# App icon — placeholder

Intentionally empty. The single 1024×1024 iOS slot is defined but no artwork is
attached, so simulator build + test succeed without an icon.

Gary will generate the final HOney app icon later via `codex exec` → imagegen (a
slightly richer mark than the minimal in-app wordmark). Drop the produced PNG into
this appiconset and add its `filename` to `Contents.json`. Do not use a serif mark.
