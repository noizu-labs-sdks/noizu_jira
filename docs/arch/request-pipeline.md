# noizu_jira — Request Pipeline

The lifecycle of a single API call, from `Noizu.Jira.Issues.get(client, "PROJ-123")`
to the returned tuple. All of this lives in Noizu.Jira.Request and
`Noizu.Jira.Client` (`@doc false` internals; behavior contract:
`docs/API-CONTRACT.md` §1, §5a–§7).

## 1. Assembly

1. **Base URL** — `Client.base_url/1` returns `https://<site>` for basic auth
   (site was normalized at `Client.new/1`: scheme prefixes stripped, scheme
   always re-applied as `https://`) or `https://api.atlassian.com/ex/jira/<cloud_id>`
   for OAuth.
2. **Path** — resource modules build the path; every dynamic segment goes
   through `Request.encode_segment/1` (`URI.encode` with unreserved characters
   only), so issue keys, ids, and filenames cannot alter path structure.
3. **Query** — `Request.params/2` + `params_query/1` build the query string in
   the library, never via Req's `:params` (which would emit `key[]=` for
   lists). Two styles per the OpenAPI spec: `:csv` (comma-joined —
   `fields`, `expand`, `properties`) and `:multi` (repeated keys — `keys`,
   `status` on project search). `URI.encode_query/1` percent-encodes values,
   including commas (`%2C`) inside csv values.
4. **Headers** — `Client.authorization_header/1` supplies `Authorization:`
   up front (Basic `base64(email:token)` or `Bearer <token>`); built manually
   rather than via Req's `:auth` so both modes are identical and testable.
   Resource modules may append headers (attachments add
   `X-Atlassian-Token: no-check`).
5. **Body** — `:json` (maps; JQL search passes user JQL inside the JSON body),
   `:form_multipart` (streamed file for uploads), or `raw: true` (skip body
   decoding for attachment content).

`client.req_opts` is merged last, so host applications can inject `plug:`
(Req.Test), Finch pools, or timeouts into every request.

## 2. Execution and retry

Req's own retry machinery is disabled (`retry: false`) — this library owns
exactly one retry policy:

- **Retried:** HTTP 429 and 503 only, up to `max_attempts` (default 3, total
  tries including the first).
- **Sleep:** `Retry-After` header honored when present (seconds → ms), clamped
  to `[0, max_sleep_ms]` (negative → 0, huge → the cap, unparseable → backoff);
  otherwise exponential backoff from `base_sleep_ms` (250), doubling per
  attempt, capped at `max_sleep_ms` (30s), with 0.7–1.3 jitter.
- **Injectable:** `retry: [sleep: fun]` on the client replaces
  `Process.sleep/1` (tests use this; callers can wire telemetry).
- **Exhausted:** the final 429/503 body is decoded as a normal error.
- **Never retried:** transport failures (DNS, connect, timeout — Req
  exceptions) and any other status.

## 3. Result mapping

| Outcome | Return |
|---|---|
| 2xx | `{:ok, decoded_body}` (decoded JSON map, or raw binary when `raw: true`) |
| 429/503 after retries | `{:error, %Error{}}` from the final body |
| any other non-2xx | `{:error, Error.decode(status, body)}` |
| transport exception | `{:error, Error.from_exception(exception)}` → `status: nil`, `reason: message` |

`Error.decode/2` mirrors the Jira error-collection shape (`errorMessages` →
`messages`, `errors` → `field_errors`); non-JSON bodies (HTML error pages,
empty) still yield a usable error with the raw body kept.

## 4. Testability

No network in tests: `Client.new(req_opts: [plug: Req.Test])` routes every
request to a stub plug (`test/support/test_support.ex` builds such clients with
fake credentials). `query_test.exs` pins exact query strings, `retry_test.exs`
pins the sleep/attempts behavior via the injectable sleep.
