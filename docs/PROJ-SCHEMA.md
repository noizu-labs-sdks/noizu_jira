# noizu_jira — Schema

`noizu_jira` is a stateless client library with **no relational store, no
KV store, no config files, and no data files**: there is nothing to model as
an ERD, so per the schema-doc scope rules the ERD sections are replaced by
the structured-data shapes the library actually owns. The persistence column
of the scope table is empty by design.

Data that exists here falls into four kinds:

| Kind | Where documented |
|------|------------------|
| Config data | the `Noizu.Jira.Client` struct (below) |
| Data interface schemas | request/response/error shapes → `API-CONTRACT.md` (§4 inventory, §5 encoding, §6 error model) + summary below |
| Produced data format | ADF documents (below) |
| Fixtures/test data | `test/support/test_support.ex` stub helpers (below) |

→ *Code locations: [PROJ-LAYOUT.md](PROJ-LAYOUT.md) · behavioral contract: [API-CONTRACT.md](API-CONTRACT.md)*

## Data-shape flow

```mermaid
graph LR
    H[Host options keyword] -->|new/1 validates + normalizes| C[%Client{} struct]
    C -->|auth header + base URL| REQ[Request envelope]
    B[Body maps / ADF doc] --> REQ
    REQ -->|GET/POST/PUT/DELETE| J[(Jira Cloud API)]
    J -->|2xx JSON| OK{decoded map}
    J -->|non-2xx| ERR[%Error{} struct]
    J -->|transport failure| ERR2[%Error{} status: nil]
```

## `Noizu.Jira.Client` — configuration struct

The only configuration surface. Built once by `new/1` (raises `KeyError`
without `:auth`, `ArgumentError` on a mode/option mismatch), immutable and
passed explicitly to every call. Source: `lib/noizu/jira/client.ex`.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `auth` | `{:basic, email, api_token}` \| `{:oauth, access_token}` | Yes | — | Auth mode; validated at build |
| `site` | `String.t() \| nil` | basic (unless `base_url`) | `nil` | Bare subdomain or `<sub>.atlassian.net`; scheme stripped, `https://` re-applied; userinfo/ports/paths/foreign hosts rejected (T-003) |
| `cloud_id` | `String.t() \| nil` | oauth | `nil` | Atlassian cloud id; used in the OAuth base URL |
| `base_url` | `String.t() \| nil` | No | `nil` | Explicit escape hatch; absolute https URL (http only for localhost/127.0.0.1); no userinfo/path/query/fragment |
| `req_opts` | `keyword()` | No | `[]` | Forwarded to every `Req.new/1` (e.g. `plug:` for `Req.Test`) |
| `retry` | `keyword()` | No | see below | Overrides merged over defaults |

**Retry defaults** (merged over by caller overrides):

| Key | Default | Meaning |
|-----|---------|---------|
| `:max_attempts` | `3` | Total tries, not retries |
| `:base_sleep_ms` | `250` | Exponential backoff base (0.7–1.3 jitter) |
| `:max_sleep_ms` | `30_000` | Cap; also the clamp for `Retry-After` (T-005) |
| `:sleep` | `Process.sleep/1` | Injectable sleep fun (ms) |

## `Noizu.Jira.Error` — error struct

Returned by every fallible call; raised by `*_stream` variants on mid-stream
page failure. Mirrors Jira's error-collection payload. Source:
`lib/noizu/jira/error.ex`.

| Field | Type | Populated when |
|-------|------|----------------|
| `status` | `pos_integer() \| nil` | HTTP failure; `nil` for transport failures |
| `messages` | `[String.t()]` | Body decodes as an error collection (`errorMessages`) |
| `field_errors` | `%{String.t() => term()}` | Body decodes as an error collection (`errors` map) |
| `reason` | `String.t() \| nil` | Transport failure (DNS, connect, timeout) — never retried |
| `body` | `term()` | Always on HTTP failure (raw decoded body; host redacts before logging — T-009) |

## ADF document shape

`Noizu.Jira.ADF.doc/1` produces (or passes through) the Atlassian Document
Format map the v3 API requires for descriptions, comments, worklog comments,
and textarea fields:

```elixir
%{
  "type" => "doc",
  "version" => 1,
  "content" => [
    %{"type" => "paragraph",
      "content" => [%{"type" => "text", "text" => "..."}]}
  ]
}
```

Plain text: one paragraph per blank-line-separated block; single newlines
become `hardBreak` nodes. A map with `"type" => "doc"` passes through
untouched. Source: `lib/noizu/jira/adf.ex`.

## Interface schemas (summary)

The full request/response contract is `docs/API-CONTRACT.md` — the
authoritative inventory (§4: methods + paths + query options per module),
query encoding (§5a: `:csv` comma-joined and `:multi` repeated-key styles;
in-house `URI.encode_query` because Req emits `key[]=`), the error model
(§6), and the retry policy (§7). Path segments are percent-encoded via
`encode_segment/1`. Bodies are decoded JSON maps — the library defines no
response structs.

## Test data

No fixture files. Tests stub HTTP via `Req.Test` plugs built by
`test/support/test_support.ex`, using **fake credentials only**; a compile-time
`chunk_stream/2` branch (Elixir <1.16 vs >=1.16 `File.stream!/3` argument
order) feeds the >64 KiB multi-chunk upload test. Real-cluster calls are
prohibited by convention.

## Conventions

No database tables exist, so timestamp conventions (`updated_at` etc.) and
ERD/index documentation are not applicable. If the library ever gains a
persistence layer or config files, this file gains the corresponding ERD /
structure sections.
