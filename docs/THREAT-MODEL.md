# noizu_jira — Threat Model

## Overview

`noizu_jira` is a **client library**, not a service: it has no listening
ports, no stored data, and no background processes. Its crown jewels are the
**Jira credentials** (API token / OAuth bearer token) held in the caller's
`Noizu.Jira.Client` struct, and the **Jira data** those credentials can
reach. Everything else follows from two boundaries:

1. **Host application ↔ library** — the host is fully trusted; it supplies
   credentials, config values (`site`, `cloud_id`), JQL, JSON bodies, and
   file paths. The library treats these as trusted-but-unvalidated input:
   mistakes or hostile values *within the host's own configuration* are in
   scope for this model (a multi-tenant app passing user-chosen config is
   the realistic threat).
2. **Library ↔ Atlassian Cloud (TLS)** — Atlassian is a semi-trusted
   external service: it controls response bodies and headers (`Retry-After`)
   and can return hostile payloads (giant attachments, error bodies, mangled
   paging envelopes). A network attacker is confined to breaking TLS
   (certificates are verified; scheme is always `https`), i.e. availability
   attacks only.

Supply chain: the Hex registry and the dependency tree (`threats/supply-chain.md`).

## Attack Surface

```mermaid
graph LR
    H[Host application] -->|config: site, cloud_id, auth tuple| C[Noizu.Jira.Client]
    H -->|JQL · JSON bodies · file paths| R[Resource modules]
    C --> R
    R -->|GET/POST/PUT/DELETE + Authorization header| J[(Jira Cloud REST API)]
    J -->|"responses · Retry-After · error bodies"| R
    R -->|"{:ok, map} / {:error, %Error{}} / raise (streams)"| H
    HEX[Hex registry] -.->|req, jason @ mix.lock pins| C
    R -->|File.stream! caller-supplied path| FS[(Local file · read-only, upload only)]
```

- **Egress:** exactly one destination per client — `https://<site>` (basic)
  or `https://api.atlassian.com/ex/jira/<cloudId>` (OAuth). One filesystem
  read path: streamed attachment upload.
- **Ingress of untrusted data:** response bodies, response headers
  (`Retry-After` only is acted on), error payloads.
- **No logging, no persistence, no eval:** the library writes nothing, logs
  nothing, and never evaluates response content as code.

## Vulnerability Register

| ID | Severity | STRIDE | Component | Status |
|----|----------|--------|-----------|--------|
| T-001 | High | Information disclosure | `inspect/1` of `Client` prints credentials (verified) | **Mitigated** (redacting `Inspect` impl — tests `credential redaction (T-001)`) |
| T-002 | Medium | Information disclosure | `ArgumentError` interpolates `inspect/1` of malformed auth tuple | **Mitigated** (shape-only message — tests `auth error redaction (T-002)`) |
| T-003 | Medium | Information disclosure / Spoofing | `:site` accepts any host (`@` userinfo trick included) → credentials forwarded to attacker host | **Mitigated** (site grammar + `:base_url` escape hatch — tests `site validation (T-003)`) |
| T-004 | Low | Tampering | `:cloud_id` unvalidated in URL string (host fixed, path/query confusion only) | Partial |
| T-005 | Low | Denial of service | `Retry-After` unclamped: negative crashes caller, huge hangs it (verified) | **Mitigated** (clamped to `[0, max_sleep_ms]` — tests `(T-005)` in `retry_test.exs`) |
| T-006 | Low | Tampering | Multipart filename unsanitized in `Content-Disposition` | Open (documented) |
| T-007 | Low | Denial of service | `Attachments.content/3` loads whole attachment into memory | Open (documented) |
| T-008 | Low | Information disclosure | JQL logic injection (bounded by token's own permissions; API has no parameterization) | Accepted |
| T-009 | Low | Information disclosure | `%Error{}` retains full response body (host must redact before logging) | Accepted |
| T-010 | Medium | Supply chain | Hex dependency compromise; lockfile pins + CI `mix hex.audit` | Partial |
| T-011 | High | Spoofing / Information disclosure | TLS interception, downgrade, credential replay | **Mitigated** (https enforced, TLS verified, no cross-host replay) |
| T-012 | Medium | Tampering | Path traversal via ids/keys in URL paths | **Mitigated** (`encode_segment/1`) |

→ *Details: [threats/credentials.md](threats/credentials.md) · [threats/url-construction.md](threats/url-construction.md) · [threats/input-surfaces.md](threats/input-surfaces.md) · [threats/network-retry.md](threats/network-retry.md) · [threats/supply-chain.md](threats/supply-chain.md)*

## Mitigation Coverage

**6 mitigated · 2 partial · 2 open · 2 accepted.**

Already in place (controls, mapped to IDs):

- HTTPS always; scheme re-applied, never caller-chosen (T-003 downgrade leg,
  T-011).
- Standard TLS verification via Req/Finch/Mint; no cross-host Authorization
  replay (T-011).
- Path segments percent-encoded through `encode_segment/1` (T-012); query
  strings built in-house and percent-encoded (parameter-splitting control).
- Single bounded retry owner; transport errors never retried (T-005
  amplification leg).
- `Retry-After` clamped to `[0, max_sleep_ms]` — negatives cannot crash
  `Process.sleep/1`, huge values cannot hang the caller (T-005).
- Redacting `Inspect` implementation on the client struct: api_token /
  access_token never render, at most the email and a 4-character prefix
  (T-001); auth-validation errors describe the value's shape instead of
  interpolating it (T-002).
- `:site` grammar enforced — bare subdomain or `<sub>.atlassian.net` host;
  userinfo (`@`), ports, paths, queries, and foreign hosts rejected — with
  one explicit https-only `:base_url` escape hatch (localhost/127.0.0.1 may
  use http) for proxies and tests (T-003).
- CI (GitHub Actions, push/PR on develop/stage/main): format check,
  `compile --warnings-as-errors`, tests, and `mix hex.audit` on an
  Elixir 1.15/OTP 25 + 1.18/OTP 27 + 1.20/OTP 29 matrix (T-010 audit leg;
  the 1.20 lane also guards the `File.stream!/3` compat shim).
- No logging, no persistence, no eval of server data; responses stay plain
  maps (T-009 severity, general).
- Lockfile-pinned minimal dependency tree (T-010).

Remaining: T-006 and T-007 want documentation; T-004 wants a cheap
UUID-format check on `cloud_id`.

## Residual Risk

- **Host-side credential handling** — storage, rotation, OAuth refresh, and
  *not logging other credential-bearing values* are host responsibilities by
  design (contract §9). The library-side leak surfaces are closed:
  `inspect/1` of the client struct is redacted (T-001) and auth-validation
  errors never carry values (T-002).
- **JQL expressiveness** (T-008) accepted: no parameterized alternative
  exists; blast radius equals the credential's permission scope.
- **Hostile Atlassian responses** — bounded by Jason-decode-only handling
  and bounded retries; the memory-unbounded attachment download (T-007) is
  documented behavior.
- **Registry compromise** (T-010) — standard Hex posture; checksum pins
  limit it to the registry trust root itself.

## Method Note

Findings verified against the code, not assumed: T-001/T-005 behaviors were
reproduced on the VM; every claim about controls traces to
`lib/noizu/jira/{client,request,pagination,error,attachments,search}.ex`.
Register established 2026-10-17 during the security-hardening pass
(T-001/T-002/T-003/T-005 fixed with regression tests; CI added); last
re-verified 2026-10-27 against the tree at `774a7ad` (org move + upload
compat shim did not change the register — T-010's CI audit leg gained an
Elixir 1.20/OTP 29 lane).
