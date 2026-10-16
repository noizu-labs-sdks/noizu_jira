# Noizu.Jira — API Contract

**Library:** `noizu_jira` v0.1.0 · Elixir client for the Jira Cloud REST API
**Status:** Implemented against this contract. This document is the reference for what the library covers, how it behaves, and what it deliberately leaves out.
**Method:** Contract-first (api-designer). Every behavioral claim below is grounded in the official Atlassian documentation listed under Sources; nothing was written from memory.

---

## Sources (fetched 2026-10-17)

- Platform REST API v3 intro: `https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/`
- Issue search (replacement `search/jql`, deprecation of legacy `/search`): `https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/`
- Agile/Software board endpoints: `https://developer.atlassian.com/cloud/jira/software/rest/api-group-board/`
- Rate limiting: `https://developer.atlassian.com/cloud/jira/platform/rate-limiting/`
- Basic auth: `https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/`
- OAuth 2.0 3LO: `https://developer.atlassian.com/cloud/jira/platform/oauth-2-3lo-apps/`

---

## 1. Scope, base URLs, auth

The library targets **Jira Cloud only** (not Jira Server/Data Center). Two auth modes, chosen explicitly per client:

| Mode | `auth:` tuple | Base URL | Header |
|---|---|---|---|
| Basic | `{:basic, email, api_token}` | `https://<site>.atlassian.net` | `Authorization: Basic base64(email:api_token)` |
| OAuth 2.0 3LO | `{:oauth, access_token}` | `https://api.atlassian.com/ex/jira/<cloudId>` | `Authorization: Bearer <access_token>` |

Rules:

- Tokens are created at `https://id.atlassian.com/manage/api-tokens`. Jira sends no auth challenge — the header is always sent up front.
- The header is built manually (`Authorization:`), not via the HTTP client's `:auth` option, so both modes behave identically and are trivially testable.
- For `:basic`, `:site` is required; `https://` and any trailing `/` on a supplied site string are stripped and the scheme is re-applied as `https://` — non-HTTPS is never used.
- For `:oauth`, `:cloud_id` is required (obtained from `GET https://api.atlassian.com/oauth/token/accessible-resources` — token exchange itself is out of scope, see §9).
- Atlassian's own guidance: Basic auth is appropriate for scripts/tools; user-facing apps should prefer OAuth 2.0 3LO. Both are supported equally here; the choice is the caller's.

## 2. API version and document bodies

- **Platform API version: v3** (latest). All platform paths below are under `/rest/api/3/`.
- v3 requires **Atlassian Document Format (ADF)** for description, environment, comments, worklog comments, and textarea custom fields. `Noizu.Jira.ADF.doc/1` converts plain text into a minimal ADF document (paragraphs on blank lines, hard breaks on single newlines). ADF maps may be passed through as-is; binaries are wrapped automatically where the API requires ADF.
- **Agile API: 1.0**, plus the **enhanced software endpoints** (`/rest/software/1.0/`) — see §5.

## 3. Client model

- `Noizu.Jira.Client` is an immutable struct built with `Client.new/1` (`auth:`, `site:`/`cloud_id:`, `req_opts:` forwarded to Req, `retry:` overrides). It is passed explicitly to every call. **No global state, no config application env, no process registry.**
- Every function has the shape `(client, ...args, opts \\ [])` and returns `{:ok, body}` or `{:error, %Noizu.Jira.Error{}}`. Bodies are decoded JSON maps (or binaries for raw content), never cast into structs — the Jira API surface is large and unstable; maps keep the client thin.
- The only non-`{:ok, ...}`-returning surface is the `*_stream` family, which raises on mid-stream errors (a lazy `Stream` cannot return an error tuple) — documented convention, see §5.

## 4. Endpoint coverage

### Issues (`Noizu.Jira.Issues`)

| Function | Method + Path | Notes |
|---|---|---|
| `create/3` | `POST /rest/api/3/issue` | body `{fields, update?, properties?, transition?}`; query `updateHistory` |
| `get/3` | `GET /rest/api/3/issue/{issueIdOrKey}` | query `fields`, `expand`, `properties`, `failFast` |
| `edit/4` | `PUT /rest/api/3/issue/{issueIdOrKey}` | body `{fields, update?}` |
| `delete/3` | `DELETE /rest/api/3/issue/{issueIdOrKey}` | query `deleteSubtasks` |
| `bulk_create/3` | `POST /rest/api/3/issue/bulk` | body `{issueUpdates: [...]}` |

### Search (`Noizu.Jira.Search`)

| Function | Method + Path | Notes |
|---|---|---|
| `search/3` | `POST /rest/api/3/search/jql` | body `{jql, maxResults?, nextPageToken?, fields?, fieldsByKeys?, properties?, validateQuery?}`; response `{issues, isLast, nextPageToken?}` |
| `stream/3` | (pages `search/3`) | token-style stream over `issues` |
| `count/2` | `POST /rest/api/3/search/approximate-count` | body `{jql}` → `{count}` |

The legacy `GET/POST /rest/api/3/search` is **deprecated and being removed** — it is intentionally not exposed.

### Transitions (`Noizu.Jira.Transitions`)

| Function | Method + Path |
|---|---|
| `list/3` | `GET /rest/api/3/issue/{issueIdOrKey}/transitions` |
| `perform/4` | `POST /rest/api/3/issue/{issueIdOrKey}/transitions` — body `{transition: {id}, fields?, update?}` |

### Comments (`Noizu.Jira.Comments`) — offset pagination

| Function | Method + Path |
|---|---|
| `list/3` | `GET /rest/api/3/issue/{issueIdOrKey}/comment` |
| `stream/3` | (pages `list/3`, key `comments`) |
| `add/4` | `POST /rest/api/3/issue/{issueIdOrKey}/comment` — text wrapped in ADF |
| `get/4` | `GET .../comment/{id}` |
| `update/5` | `PUT .../comment/{id}` — text wrapped in ADF |
| `delete/3` | `DELETE .../comment/{id}` |

### Worklogs (`Noizu.Jira.Worklogs`) — offset pagination

| Function | Method + Path | Notes |
|---|---|---|
| `list/3` | `GET /rest/api/3/issue/{issueIdOrKey}/worklog` | |
| `stream/3` | (pages `list/3`, key `worklogs`) | |
| `add/3` | `POST .../worklog` | body `{timeSpent?/timeSpentSeconds?, started?, comment(ADF)?}`; query `adjustEstimate`, `newEstimate`, `reduceBy`, `notifyUsers` |
| `update/4` | `PUT .../worklog/{id}` | same options |
| `delete/4` | `DELETE .../worklog/{id}` | same estimate options |

### Attachments (`Noizu.Jira.Attachments`)

| Function | Method + Path | Notes |
|---|---|---|
| `add/4` | `POST /rest/api/3/issue/{issueIdOrKey}/attachments` | `multipart/form-data` (streamed from disk); requires `X-Atlassian-Token: no-check`; `filename:` opt overrides the part filename |
| `get/3` | `GET /rest/api/3/attachment/{id}` | metadata |
| `content/3` | `GET /rest/api/3/attachment/content/{id}` | returns raw binary (`decode_body: false`) |
| `delete/3` | `DELETE /rest/api/3/attachment/{id}` | |

### Issue links (`Noizu.Jira.IssueLinks`)

| Function | Method + Path |
|---|---|
| `create/3` | `POST /rest/api/3/issueLink` (full payload) |
| `link/5` | convenience builder over `create/3` (type name + inward/outward keys, optional ADF comment) |
| `get/3` | `GET /rest/api/3/issueLink/{linkId}` |
| `delete/3` | `DELETE /rest/api/3/issueLink/{linkId}` |

### Projects (`Noizu.Jira.Projects`) — offset pagination

| Function | Method + Path |
|---|---|
| `search/2` | `GET /rest/api/3/project/search` |
| `stream/2` | (pages `search/2`, key `values`) |
| `get/3` | `GET /rest/api/3/project/{keyOrId}` |

### Users (`Noizu.Jira.Users`) — array responses

| Function | Method + Path | Notes |
|---|---|---|
| `me/1` | `GET /rest/api/3/myself` | |
| `get/2` | `GET /rest/api/3/user` | `account_id:` (or legacy `key:`/`username:`) |
| `search/3` | `GET /rest/api/3/user/search` | returns a **raw array** — not the envelope |
| `stream/3` | (pages `search/3`) | array-style stream (stops when a page is short/empty) |

### Fields / issue types / statuses

| Module | Function | Method + Path | Notes |
|---|---|---|---|
| `Noizu.Jira.Fields` | `list/1` | `GET /rest/api/3/field` | raw decoded body; Atlassian is mid-migration between a flat array and a paginated map, so no stream is offered |
| `Noizu.Jira.IssueTypes` | `list/1` | `GET /rest/api/3/issuetype` | raw array |
| `Noizu.Jira.IssueTypes` | `get/3` | `GET /rest/api/3/issuetype/{id}` | |
| `Noizu.Jira.Statuses` | `list/1` | `GET /rest/api/3/status` | legacy flat array, kept as-is |
| `Noizu.Jira.Statuses` | `search/2` | `GET /rest/api/3/statuses/search` | offset page `{values, ...}` |
| `Noizu.Jira.Statuses` | `stream/2` | (pages `search/2`) | |

### Agile — boards (`Noizu.Jira.Agile.Boards`)

| Function | Method + Path | Pagination |
|---|---|---|
| `list/2` | `GET /rest/agile/1.0/board` | offset (`values`) |
| `stream/2` | (pages `list/2`) | offset |
| `get/2` | `GET /rest/agile/1.0/board/{boardId}` | — |
| `create/2` | `POST /rest/agile/1.0/board` | — |
| `delete/2` | `DELETE /rest/agile/1.0/board/{boardId}` | — |
| `issues/3` | `GET /rest/software/1.0/board/{boardId}/issue` | **token** (`nextPageToken`) — enhanced endpoint |
| `issues_stream/3` | (pages `issues/3`) | token |

The offset endpoint `/rest/agile/1.0/board/{boardId}/issue` is deprecated by Atlassian and is intentionally not used; the enhanced `/rest/software/1.0/...` replacement is.

### Agile — sprints (`Noizu.Jira.Agile.Sprints`)

| Function | Method + Path | Pagination |
|---|---|---|
| `get/2` | `GET /rest/agile/1.0/sprint/{sprintId}` | — |
| `create/2` | `POST /rest/agile/1.0/sprint` | — |
| `update/3` | `PUT /rest/agile/1.0/sprint/{sprintId}` | — |
| `delete/2` | `DELETE /rest/agile/1.0/sprint/{sprintId}` | — |
| `issues/3` | `GET /rest/agile/1.0/sprint/{sprintId}/issue` | offset (`issues`) |
| `issues_stream/3` | (pages `issues/3`) | offset |

## 5. Pagination

Two response models are in service simultaneously; the library handles both behind one interface:

**Offset model** — `{startAt, maxResults, total, isLast, values: [...]}` (also `comments`, `worklogs`, `issues` as the items key).

**Token model** — request `nextPageToken` param, response `{items..., isLast, nextPageToken?}` (JQL search; enhanced board issues).

Per-request paging functions return the raw page map: `{:ok, page}`. `*_stream/…` functions return a lazy `Enumerable.t()` that transparently walks pages. Paging termination is defensive because **Atlassian documents that `total` and `isLast` are not returned for every operation and that an empty page is a valid, non-final page**:

1. empty item list → stop;
2. `isLast == true` → stop;
3. `total` present and `startAt + items ≥ total` → stop;
4. otherwise keep paging (next offset = `startAt + length(items)`); a trailing empty page ends the stream.

Token streams follow `nextPageToken` until it is absent/empty. Array responses (`user/search`) stream until a page is shorter than `maxResults` or empty.

**Errors in streams raise.** `Enum.to_list(Projects.stream(client))` raises `%Noizu.Jira.Error{}` mid-iteration if a page fetch fails. Callers who need error tuples must page manually with the per-call functions. This is a deliberate contract: `Stream` composition has no error channel, and rescuing in the stream would hide failures from `Enum.reduce`.

## 5a. Query parameter encoding

Queries are encoded by the library's internal request layer, never delegated to the HTTP client's
generic `params` handling, which would emit `key[]=` for list values — a shape the Jira API rejects.
Each parameter follows its documented OpenAPI style/explode:

- **Comma-separated (form, explode=false)** — `fields`, `expand`, `properties` on issue reads and
  every other list-shaped option documented as "accepts a comma-separated list":
  `?fields=summary,status&expand=changelog&properties=a,b`.
- **Repeated keys (form, explode=true)** — `keys` and `status` on `GET /rest/api/3/project/search`
  (`keys=PA&keys=PB`), per the endpoint's "provide an ampersand-separated list" wording.

Values are accepted as lists or scalars; commas are percent-encoded (`%2C`) on the wire.
Tests pin the exact query strings (`test/noizu/jira/query_test.exs`).

## 6. Error model

Jira error payloads use the *error collection* shape: `{errorMessages: [string], errors: {field: message}, status}`. Mapping:

```
%Noizu.Jira.Error{
  status: 400,                        # HTTP status
  messages: ["..."],                  # from errorMessages
  field_errors: %{"summary" => "..."}, # from errors
  reason: nil | "...",                # transport failure message
  body: raw_body                      # full original body (or binary)
}
```

- Any non-2xx, non-retryable response → `{:error, error}`. Non-JSON bodies (HTML error pages, empty bodies) still produce a usable `Error` with the raw body kept.
- Transport failures (DNS, connect, timeout — `Req` exceptions) → `{:error, %Error{status: nil, reason: message}}`. Transport errors are **never** retried by the library.

## 7. Rate limits and retry policy

Jira Cloud enforces hourly point quotas, burst limits, and per-issue write limits; violations return **HTTP 429 (sometimes 503) with `Retry-After` (seconds)**, plus informational `X-RateLimit-*` headers. The library's policy:

- Retries **429 and 503** responses, bounded by `retry: [max_attempts: 3]` (total tries including the first).
- Sleep: `Retry-After` seconds honored **exactly when present** (it is documented as a minimum); otherwise exponential backoff from `base_sleep_ms: 250`, doubling per attempt, capped at `max_sleep_ms: 30_000`, with 0.7–1.3 jitter.
- Attempts exhausted → the final 429/503 is returned as a normal `{:error, %Error{}}`.
- The HTTP client's own retry machinery is disabled (`retry: false` on Req) so exactly one policy owns retries.
- `retry: [sleep: fun]` is injectable (used by tests; usable for telemetry or `Process.sleep` alternatives).

The `X-RateLimit-*` response headers are surfaced to callers only insofar as they care to inspect raw responses — the library does not act on them.

## 8. Multipart uploads

Attachment upload is `multipart/form-data` streamed from disk (constant memory), with the mandatory CSRF-exemption header `X-Atlassian-Token: no-check`. Default part filename is the source path's basename; `filename:` overrides it.

## 9. Intentionally NOT covered

- **OAuth token issuance/refresh** (`authorize` URL, code exchange, refresh tokens) — auth lifecycle is app-specific; the client takes an access token.
- **The deprecated legacy search** (`GET/POST /rest/api/3/search`) — being removed by Atlassian.
- **Deprecated offset board-issues endpoint** (`/rest/agile/1.0/board/{boardId}/issue`) — replaced by the enhanced endpoint.
- **Server/Data Center APIs**, webhooks administration, permissions schemes, screens, notification schemes, dashboards, filters CRUD, avatars, application roles, workflows, announcements banners, service desk (JSM), insights, Team-managed specifics beyond what generic issue ops touch.
- **Schemas/structs for responses** — bodies stay maps by design.
- **Bulk edit/delete of issue properties**, changelogs, watchers, votes, remote links, issue property sets, lab/restricted endpoints.
- **Rate-limit token-bucket pass-through** of `X-RateLimit-*` into caller state.

## 10. Decision log

| Decision | Choice | Rationale |
|---|---|---|
| API version | Platform v3 + Agile 1.0 (+ enhanced software endpoints) | Latest platform version; ADF support required for comments/descriptions |
| Auth | Explicit tuple per client; header built manually | Deterministic, testable, no global state; matches the two documented modes exactly |
| Search | `POST /search/jql` only | Legacy `/search` is deprecated and being removed (fetched doc) |
| Board issues | `/rest/software/1.0/board/{id}/issue` (token) | Offset agile equivalent is deprecated (fetched doc) |
| Response shape | Decoded maps, no structs | Thin client over a large, evolving API; additive-only evolution |
| Pagination | `{:ok, page}` per call + `*_stream` lazy helpers; both models; defensive termination | Docs state `total`/`isLast` are absent on some operations; empty pages are legal |
| Stream errors | Raise `%Noizu.Jira.Error{}` | Streams have no error channel; hiding failures would corrupt fold results |
| Errors | `%Noizu.Jira.Error{}` exception struct with `messages` + `field_errors` | Mirrors the documented error-collection shape one-to-one |
| Retries | Library-owned, 429/503 only, `Retry-After` exact, bounded attempts, injectable sleep | Follows Atlassian's published retry guidance; single policy owner |
| HTTP client | Req, `retry: false`, manual headers | Deterministic behavior; avoids double-retry; trivially stubbed via `Req.Test` |
| ADF | Tiny `ADF.doc/1` text converter + pass-through maps | Full ADF AST is out of scope; common case (plain text) covered |
| Fields endpoint | No stream | Atlassian is mid-migration between array and paginated-map shapes |
