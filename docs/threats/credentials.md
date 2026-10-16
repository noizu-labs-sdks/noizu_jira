# noizu_jira — Credentials in Transit and at Rest

How API credentials flow through the library, and where they can leak.
Grounding: `lib/noizu/jira/client.ex`, `lib/noizu/jira/request.ex`,
contract §1 and §6 (`docs/API-CONTRACT.md`).

## The asset

Two credential kinds, chosen explicitly per client:

- **Basic:** `{:basic, email, api_token}` — Atlassian API token, sent as
  `Authorization: Basic base64(email:api_token)` (an obfuscated, not
  encrypted, form — TLS is the actual protection).
- **OAuth 2.0 3LO:** `{:oauth, access_token}` — bearer token, sent as
  `Authorization: Bearer <token>`. Token issuance/refresh is out of the
  library's scope (contract §9); the host must refresh before expiry.

Both live as plain values in the `Noizu.Jira.Client` struct for the
struct's whole lifetime. The library never persists, caches, or transmits
them anywhere except the outbound `Authorization` header over enforced
HTTPS.

## Controls in place

- **HTTPS enforced:** `normalize_site/1` strips any supplied scheme and
  `base_url/1` always re-applies `https://`; no code path can produce an
  `http://` request. TLS certificate verification is Req/Finch/Mint default
  (standard CA verification) unless the host explicitly weakens it via
  `req_opts`.
- **No challenge/response divergence:** the header is built manually and
  sent up front, identically for both modes — no credential re-sending on
  redirects beyond Req's own behavior (Req does not replay Authorization
  cross-host on redirects by default).
- **Library does not log:** no `Logger` calls anywhere in `lib/`; requests,
  responses, and headers are never written to logs by the library itself.

## Findings

- **T-001 (High, Information disclosure, Open):** the `Client` struct has no
  `Inspect` implementation. `inspect(client)` — the default in IEx, crash
  reports, `Logger.debug("... #{inspect(client)}")`, and observer tools —
  prints `auth: {:basic, "you@example.com", "SUPERSECRET"}` verbatim
  (verified). Any host that logs the struct leaks its Jira credential.
  *Recommended mitigation:* implement `inspect/2` redacting the auth tuple
  (e.g. `{:basic, "…", "**redacted**"}`).
- **T-002 (Medium, Information disclosure, Open):** `validate_auth!/1`
  raises `ArgumentError, "Noizu.Jira.Client invalid :auth #{inspect(other)}"`
  for a malformed tuple. If the *shape* is wrong but real credential values
  are inside (e.g. `{:basic, email, 123}`, or a mistyped mode carrying the
  token), the raised message — which typically lands in logs — contains
  them. *Recommended mitigation:* redact or elide `inspect/1` of the
  offending value.
- **Host-side residual risk (accepted):** hosts pass credentials via
  `System.fetch_env!` or their secret manager; storage, rotation, and
  bearer-token refresh are host responsibilities by design (contract §9).

## Related

- Credential redirect via a hostile `:site` value → T-003
  (`threats/url-construction.md`).
