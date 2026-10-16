# noizu_jira — Lib Layer

Detailed breakdown of `lib/noizu/jira/`. Every module passes a
`Noizu.Jira.Client.t()` explicitly; bodies are decoded JSON maps; all fallible
functions return `{:ok, body} | {:error, %Noizu.Jira.Error{}}` (contract:
`docs/API-CONTRACT.md`).

```
lib/noizu/jira/
├── jira.ex               # Namespace module: moduledoc + quickstart, no functions
├── client.ex             # Immutable client struct (auth, site/cloud_id, req_opts, retry)
├── request.ex            # Internal single-request executor (moduledoc false)
├── pagination.ex         # Internal stream machinery shared by *_stream (moduledoc false)
├── error.ex              # %Noizu.Jira.Error{} exception, Jira error-collection shape
├── adf.ex                # ADF.doc/1 plain-text → Atlassian Document Format
├── issues.ex             # Issue CRUD + bulk create
├── search.ex             # JQL search (POST /search/jql), stream, approximate count
├── transitions.ex        # Transition list + perform
├── comments.ex           # Comment CRUD, offset paging
├── worklogs.ex           # Worklog add/update/delete/list, offset paging
├── attachments.ex        # Multipart upload (X-Atlassian-Token: no-check), raw content
├── issue_links.ex        # Issue link create/get/delete + link/5 builder
├── projects.ex           # Project search/get, offset paging
├── users.ex              # myself, user get, search (raw array) + array stream
├── fields.ex             # Field list (no stream — API mid-migration)
├── issue_types.ex        # Issue type list/get
├── statuses.ex           # Status list + statuses/search + stream
└── agile/
    ├── boards.ex         # Board list/get/create/delete + /rest/software/1.0 issues (token)
    └── sprints.ex        # Sprint CRUD + sprint issues (offset)
```

## Core (non-resource) modules

- **`Noizu.Jira.Client`** — plain struct built by `new/1`; validates the `:auth`
  tuple (`{:basic, email, api_token}` | `{:oauth, access_token}`), normalizes
  `:site` (strips scheme + trailing slash, always re-applies `https://`),
  requires `:cloud_id` for oauth. Holds `:req_opts` forwarded to every
  `Req.new/1` and `:retry` overrides merged over defaults
  (`max_attempts: 3, base_sleep_ms: 250, max_sleep_ms: 30_000`).
  `base_url/1` and `authorization_header/1` are `@doc false` internals.

- **Noizu.Jira.Request** (`@moduledoc false`) — the only place HTTP happens.
  Assembles `base_url <> path <> query`, injects the auth header, builds the
  query string itself (`URI.encode_query`) because Req's `:params` emits
  `key[]=` for lists, which Jira rejects; per-parameter styles are `:csv`
  (comma-joined) and `:multi` (repeated keys). Disables Req's own retries
  (`retry: false`) and owns the 429/503 loop: `Retry-After` honored exactly,
  otherwise exponential backoff with 0.7–1.3 jitter, injectable `:sleep` fun.
  Path segments are escaped via `encode_segment/1` (`URI.encode(...,
  &URI.char_unreserved?/1)`). Decodes errors via the error module's decode
  function.

- **Noizu.Jira.Pagination** (`@moduledoc false`) — `Stream.resource` walker
  with three termination strategies: `offset_next/3` (defensive about absent
  `total`/`isLast` and legal empty pages), `token_next/2` (`nextPageToken`
  until absent/empty), `array_next/4` (stop when a page is short of
  `max_results`). Raises `%Noizu.Jira.Error{}` on page failure — streams have
  no error channel (documented convention).

- **`Noizu.Jira.Error`** — `defexception` with `status`, `messages`,
  `field_errors`, `reason` (transport failures; `status: nil`, never retried),
  and the raw `body`. `decode/2` maps the Jira error-collection payload;
  non-JSON bodies still produce a usable error.

- **`Noizu.Jira.ADF`** — `doc/1` wraps plain text (paragraphs on blank lines,
  hard breaks on single newlines); passes an existing `%{"type" => "doc"}`
  map through untouched.

## Resource modules

One module per endpoint family; each function is `(client, ...args, opts \\ [])`
and delegates to `Request.request/4`. Coverage table with methods, paths, and
query options: `docs/API-CONTRACT.md` §4. `*_stream` variants page lazily via
Noizu.Jira.Pagination.
