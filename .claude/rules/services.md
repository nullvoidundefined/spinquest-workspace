---
paths:
  - "Backend/**"
  - "central-tech/**"
---

# Service repos

## Review norms

- S1. Configuration fails fast at boot; no silent default for a risky value.
- S1. A tunable is a constant when changing it needs a build anyway or a wrong value is dangerous; otherwise an env var with a default.
- S1. A bypass gets a single-purpose `DANGEROUS_*` flag, never another reading of `LOCAL_ENV` or `NODE_ENV`.
- S2. Every outbound `fetch` has a timeout signal.
- S3. Consistency with the repo's existing idiom beats a one-off improvement.

Derived from PR reviews 2026-05-11 to 2026-11-11.
