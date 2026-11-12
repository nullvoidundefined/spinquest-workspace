---
paths:
  - "Backend/**"
  - "central-tech/**"
source: PR reviews 2026-05-11 to 2026-11-11
---

# Service repos

## Review norms

- Configuration fails fast at boot; no silent default for a risky value.
- A tunable is a constant when changing it needs a build anyway or a wrong value is dangerous; otherwise an env var with a default.
- A bypass gets a single-purpose `DANGEROUS_*` flag, never another reading of `LOCAL_ENV` or `NODE_ENV`.
- Every outbound `fetch` has a timeout signal.
- Consistency with the repo's existing idiom beats a one-off improvement.
