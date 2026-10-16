# noizu_jira — Threat Model Summary

- **System:** stateless Jira Cloud client library; no ports, no persistence,
  no logging, no eval. Crown jewels: the Jira credential in the client struct
  and the data that credential can reach.
- **Boundaries:** host app (trusted, supplies config/JQL/paths) ↔ library ↔
  Atlassian over TLS (semi-trusted: controls bodies and `Retry-After`); Hex
  registry for supply chain.
- **Register:** 12 findings — 1 High, 4 Medium, 6 Low, plus 2 mitigated
  controls. Open: 6 · Partial: 2 · Mitigated: 2 · Accepted: 2.
- **Top risks (open):** T-001 client struct inspect prints credentials
  (verified); T-002 ArgumentError inspect leaks malformed auth tuples;
  T-003 unvalidated `:site` host redirects credentials (userinfo trick);
  T-010 Hex supply chain with lockfile-only defense (no CI yet).
- **Verified controls:** https enforced (no downgrade), TLS verified,
  path/query percent-encoding, bounded single-owner retries, transport
  errors never retried, responses decoded as data only.
- **Accepted:** JQL logic injection (bounded by token scope, no API
  parameterization exists); error-body retention (host redacts before
  logging).
- Details: `threats/{credentials,url-construction,input-surfaces,network-retry,supply-chain}.md`.
