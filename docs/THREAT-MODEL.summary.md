# noizu_jira — Threat Model Summary

- **System:** stateless Jira Cloud client library; no ports, no persistence,
  no logging, no eval. Crown jewels: the Jira credential in the client struct
  and the data that credential can reach.
- **Boundaries:** host app (trusted, supplies config/JQL/paths) ↔ library ↔
  Atlassian over TLS (semi-trusted: controls bodies and `Retry-After`); Hex
  registry for supply chain.
- **Register:** 12 findings — 1 High, 4 Medium, 6 Low, plus 2 mitigated
  controls. Open: 2 · Partial: 2 · Mitigated: 6 · Accepted: 2.
- **Top risks (open):** T-006 multipart filename unsanitized (documented);
  T-007 attachment download is memory-unbounded (documented). Partial:
  T-004 `:cloud_id` UUID check owed; T-010 Hex supply chain (lockfile pins
  + CI `mix hex.audit`).
- **Recently mitigated (2026-10-17 hardening pass):** T-001 inspect
  redaction; T-002 shape-only auth errors; T-003 `:site` grammar + https
  `:base_url` escape hatch; T-005 `Retry-After` clamped to
  `[0, max_sleep_ms]` — each with a regression test named for the finding.
- **Verified controls:** https enforced (no downgrade), TLS verified,
  path/query percent-encoding, bounded single-owner retries, transport
  errors never retried, responses decoded as data only.
- **Accepted:** JQL logic injection (bounded by token scope, no API
  parameterization exists); error-body retention (host redacts before
  logging).
- Details: `threats/{credentials,url-construction,input-surfaces,network-retry,supply-chain}.md`.
