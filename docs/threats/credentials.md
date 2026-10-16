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
  `http://` request (the explicit `:base_url` escape hatch allows `http`
  only for `localhost`/`127.0.0.1` test endpoints). TLS certificate
  verification is Req/Finch/Mint default (standard CA verification) unless
  the host explicitly weakens it via `req_opts`.
- **Redacting `inspect/1` (T-001, mitigated):** a custom `Inspect`
  implementation on the client struct shows at most the basic-auth email and
  a 4-character token prefix; `api_token` / `access_token` never render —
  not in IEx, crash reports, `Logger.debug("#{inspect(client)}")`, or
  observer tools. Tests: `credential redaction (T-001)` in
  `test/noizu/jira/client_test.exs`.
- **Shape-only auth errors (T-002, mitigated):** `validate_auth!/1` describes
  the offending value's shape ("3-element tuple") instead of interpolating
  `inspect/1`, so real credentials riding inside a malformed tuple never
  reach the raised message. Tests: `auth error redaction (T-002)`.
- **No challenge/response divergence:** the header is built manually and
  sent up front, identically for both modes — no credential re-sending on
  redirects beyond Req's own behavior (Req does not replay Authorization
  cross-host on redirects by default).
- **Library does not log:** no `Logger` calls anywhere in `lib/`; requests,
  responses, and headers are never written to logs by the library itself.

## Findings

- **T-001 (High, Information disclosure, Mitigated):** the `Client` struct
  had no `Inspect` implementation, so `inspect(client)` printed the auth
  tuple verbatim (verified). *Mitigation:* `defimpl Inspect` redacts the
  token (email + 4-character prefix at most); regression tests assert
  neither secret appears in `inspect/1` output in either auth mode.
- **T-002 (Medium, Information disclosure, Mitigated):** `validate_auth!/1`
  interpolated `inspect(other)` into the raised `ArgumentError`, so a
  mistyped mode carrying a real token (e.g. `{:oaut, token}`) leaked it into
  logs (verified). *Mitigation:* the message names the expected shapes and
  reports only the offending value's shape; tests assert the secret is
  absent from the message.
- **Host-side residual risk (accepted):** hosts pass credentials via
  `System.fetch_env!` or their secret manager; storage, rotation, and
  bearer-token refresh are host responsibilities by design (contract §9).

## Related

- Credential redirect via a hostile `:site` value → T-003
  (`threats/url-construction.md`).
